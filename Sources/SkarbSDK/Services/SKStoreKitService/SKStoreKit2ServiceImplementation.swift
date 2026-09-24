//
//  SKStoreKit2ServiceImplementation.swift
//  SkarbSDK
//

import Foundation
import StoreKit
import UIKit

/// StoreKit 2 implementation of `SKStoreKitService`. The backend contract is additive: commands
/// are built by the same `SKPurchaseCommandFactory` the StoreKit 1 path uses, plus the
/// Apple-signed transaction - the only thing that can prove a consumable.
///
/// Purchases are observed through two channels, both feeding `reportPurchased`:
/// `Transaction.updates` (with what `purchase()` returns) for this SDK's own purchases, and
/// `sweepPurchaseHistory` for everybody else's - measured 24.09.2026, that is the only channel
/// that sees a purchase another SDK made. The StoreKit 1 payment queue is observed too, but
/// reports nothing: see `paymentQueue(_:updatedTransactions:)`.
@available(iOS 15.0, *)
final class SKStoreKit2ServiceImplementation: NSObject, SKStoreKitService {

//  MARK: Public

  weak var delegate: SKStoreKitDelegate?
  weak var observer: SKStoreKitObserver?

//  MARK: Private
  private let isObservable: Bool

  /// `NSLock` rather than a serial queue: touched from async contexts, where `queue.sync` would
  /// park a cooperative-pool thread.
  private let cacheLock = NSLock()
  private var cachedAllProducts: [SKProductInfo] = []
  /// Raw StoreKit 2 products, needed to start a purchase.
  private var cachedStoreProducts: [String: Product] = [:]

  private var updatesTask: Task<Void, Never>?
  private var unfinishedTask: Task<Void, Never>?
  private var sweepTask: Task<Void, Never>?

  /// One transaction arrives through several channels, and without this it reaches the backend
  /// once per channel. Keyed by the id as a STRING, the one form both StoreKit versions agree on.
  private var reportedTransactionIds: Set<String> = []

  /// Completions of `purchasePackage` calls not answered yet, keyed by product id. `purchase()`
  /// is not a reliable way to learn that a purchase went through - measured on sandbox, it both
  /// hung forever and answered `.userCancelled` for a purchase that completed - so whichever path
  /// sees the transaction first answers the parked completion.
  private var pendingPurchases: [String: (Result<Bool, Error>) -> Void] = [:]

  /// `SKCommandStore` is GCD-serial-queue based, and calling it straight from a `Task` parks a
  /// cooperative-pool thread on `queue.sync`.
  private let commandQueue = DispatchQueue(label: "com.skarbSDK.skStoreKit2.commands")

  var allProducts: [SKProductInfo]? {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    return cachedAllProducts
  }

  init(isObservable: Bool) {
    self.isObservable = isObservable
    super.init()
    // Two purposes: `shouldAddStorePayment` for App Store promoted purchases (StoreKit 2 needs
    // iOS 16.4 for `PurchaseIntent`), and observing purchases another SDK in the same app made,
    // which no StoreKit 2 channel does reliably. See `paymentQueue(_:updatedTransactions:)`.
    SKPaymentQueue.default().add(self)
    startTransactionUpdatesListener()
    drainUnfinishedTransactions()
    startHistorySweep()
    SKLogger.logInfo("SKStoreKitService: running on StoreKit 2. isObservable = \(isObservable) (SDK \(isObservable ? "will NOT" : "will") finish transactions)")
  }

  deinit {
    updatesTask?.cancel()
    unfinishedTask?.cancel()
    sweepTask?.cancel()
    NotificationCenter.default.removeObserver(self)
    SKPaymentQueue.default().remove(self)
  }

//  MARK: Public

  func requestProductInfoAndSendPurchase(command: SKCommand) {
    var editedCommand = command
    let decoder = JSONDecoder()

    guard let fetchProducts = try? decoder.decode(Array<SKFetchProduct>.self, from: command.data) else {
      SKLogger.logError("SKSyncServiceImplementation requestProductInfoAndSendPurchase: called with fetchProducts but command.data is not SKFetchProduct. Command.data == \(String(describing: String(data: command.data, encoding: .utf8)))", features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
      editedCommand.changeStatus(to: .canceled)
      SKServiceRegistry.commandStore.saveCommand(editedCommand)
      return
    }

    requestProductsInfo(productIds: fetchProducts.map({ $0.productId })) { [weak self] result in
      switch result {
        case .success(let products):
          if !products.isEmpty {
            editedCommand.changeStatus(to: .done)
          } else {
            editedCommand.updateRetryCountAndFireDate()
            editedCommand.changeStatus(to: .pending)
          }
          SKServiceRegistry.commandStore.saveCommand(editedCommand)
          Task { [weak self] in
            guard let self = self else { return }
            await self.buildCommands { factory in
              factory.createPriceCommand(fetchProducts: fetchProducts,
                                         products: products,
                                         command: editedCommand)
            }
          }
        case .failure(let error):
          SKLogger.logInfo("Getting error during fetching products. Error = \(error.localizedDescription)")
      }
    }
  }

  func restorePurchases(completion: @escaping (Result<Bool, Error>) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    SKLogger.logInfo("calling restorePurchases with AppStore.sync()")
    // Deliberately no walk over `Transaction.all`: restored purchases reach the backend
    // through the refreshed app receipt, exactly as on StoreKit 1.
    Task { [weak self] in
      do {
        try await AppStore.sync()
        SKLogger.logInfo("AppStore.sync() finished successfully")
        await self?.deliver(completion, .success(true))
      } catch {
        SKLogger.logInfo("AppStore.sync() failed with error \(error.localizedDescription)")
        await self?.deliver(completion, .failure(error))
      }
    }
  }

  func purchasePackage(_ package: SKOfferPackage, completion: @escaping (Result<Bool, Error>) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    SKLogger.logInfo("calling purchaseProduct with productId = \(package.productId) via StoreKit 2")
    observer?.skarbPurchaseStateDidChange(.purchasing, productId: package.productId)

    // Parked before the purchase starts: `Transaction.updates` can deliver the transaction
    // before `product.purchase()` returns, and on a hung `purchase()` it is the only path that
    // ever will.
    parkPendingPurchase(package.productId, completion)

    Task { [weak self] in
      guard let self = self else { return }
      do {
        let product = try await self.storeProduct(for: package.productId)
        let result = try await product.purchase()

        switch result {
          case .success(let verification):
            switch verification {
              case .verified(let transaction):
                SKLogger.logInfo("purchase succeeded: transaction \(transaction.id), product \(transaction.productID)")
                if self.markReported(String(transaction.id)) {
                  await self.reportPurchased(SKPurchaseEvent(transaction: transaction,
                                                             jws: verification.jwsRepresentation))
                  // Only whoever reported the transaction notifies, or a purchase delivered
                  // through several channels would announce `.purchased` more than once.
                  self.notifyObserver(.purchased, productId: package.productId)
                } else {
                  SKLogger.logInfo("transaction \(transaction.id) was already reported by another channel, not reporting again")
                }
                await self.settle(transaction)
                await self.resolvePendingPurchase(package.productId, .success(true))

              case .unverified(let transaction, let error):
                // Signature did not validate: not reported as a purchase.
                SKLogger.logError("purchase returned an UNVERIFIED transaction \(transaction.id) for \(transaction.productID). Not reported to the backend. Error = \(error.localizedDescription)",
                                  features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                             SKLoggerFeatureType.internalValue.name: transaction.productID])
                self.notifyObserver(.failed(error), productId: package.productId)
                await self.resolvePendingPurchase(package.productId, .failure(error))
            }

          case .userCancelled:
            // NOT necessarily the user: StoreKit also returns `.userCancelled` for a sheet that
            // dismissed itself. Reported immediately all the same - waiting for
            // `Transaction.updates` to contradict it only made real cancellations feel broken.
            guard self.hasPendingPurchase(package.productId) else {
              SKLogger.logInfo("purchase for \(package.productId) came back as userCancelled, but Transaction.updates had already reported it - the cancellation was not real")
              return
            }
            SKLogger.logInfo("purchase for \(package.productId) came back as userCancelled")
            // Bridged into SKErrorDomain so `error as? SKError` keeps working in hosts that
            // already special-case cancellation.
            let error = NSError(domain: SKErrorDomain,
                                code: SKError.Code.paymentCancelled.rawValue,
                                userInfo: [NSLocalizedDescriptionKey: "Purchase was cancelled"])
            self.notifyObserver(.failed(error), productId: package.productId)
            await self.resolvePendingPurchase(package.productId, .failure(error))

          case .pending:
            // Ask-to-Buy / SCA. The completion MUST be called or the paywall spinner hangs.
            SKLogger.logInfo("purchase for \(package.productId) is PENDING external approval (Ask-to-Buy / SCA). It will arrive through Transaction.updates once approved.")
            self.notifyObserver(.deferred, productId: package.productId)
            await self.resolvePendingPurchase(package.productId,
                                              .failure(SKResponseError(errorCode: SKResponseError.purchasePendingApprovalCode,
                                                                       message: "Purchase is pending approval")))

          @unknown default:
            SKLogger.logError("purchase returned an unknown Product.PurchaseResult for \(package.productId)",
                              features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                         SKLoggerFeatureType.internalValue.name: package.productId])
            await self.resolvePendingPurchase(package.productId,
                                              .failure(SKResponseError(errorCode: 0,
                                                                       message: "Unknown purchase result")))
        }
      } catch {
        SKLogger.logInfo("purchase for \(package.productId) failed with error \(error.localizedDescription)")
        self.notifyObserver(.failed(error), productId: package.productId)
        await self.resolvePendingPurchase(package.productId, .failure(error))
      }
    }
  }

  /// Might be called on any thread. Callback wil be on the main thread
  func requestProductsInfo(productIds: [String],
                           completion: @escaping (Result<[SKProductInfo], Error>) -> Void) {
    SKLogger.logInfo("SKStoreKitService: requesting products \(productIds) via StoreKit 2")
    Task { [weak self] in
      guard let self = self else { return }
      do {
        let products = try await Product.products(for: Set(productIds))
        let missing = Set(productIds).subtracting(products.map { $0.id })
        if !missing.isEmpty {
          SKLogger.logInfo("SKStoreKitService: StoreKit 2 returned no product for \(missing)")
        }
        self.cache(products)
        // Only what this response brought: logging the whole cache drowned the interesting lines.
        let receivedIds = Set(products.map { $0.id })
        for product in (self.allProducts ?? []).filter({ receivedIds.contains($0.productId) }) {
          SKLogger.logInfo("SKStoreKitService: cached \(product.productId) - price \(product.price) \(product.currencyCode ?? "?"), region \(product.regionCode ?? "?"), period \(product.subscriptionPeriod.map { "\($0.unit.rawValue)/\($0.count)" } ?? "none"), intro \(String(describing: product.introductoryOffer?.paymentMode))")
        }
        // Matches StoreKit 1: the whole cache is returned, not only this response.
        await self.deliverProducts(completion, .success(self.allProducts ?? []))
      } catch {
        SKLogger.logInfo("SKStoreKitService: Product.products(for:) failed with error \(error.localizedDescription)")
        await self.deliverProducts(completion, .failure(error))
      }
    }
  }

  func fetchProduct(by productId: String) -> SKProductInfo? {
    return allProducts?.filter({ $0.productId == productId }).first
  }

  /// What the device can prove wins over what the caller passed: the id and date come from Apple
  /// rather than from a foreign SDK's bookkeeping. The caller's values are the fallback for a
  /// purchase that is not in the device history.
  func reportPurchase(productId: String, transactionId: String?, transactionDate: Date?) {
    SKLogger.logInfo("SKStoreKitService: reportPurchase(\(productId), transactionId: \(transactionId ?? "nil")) on StoreKit 2")
    Task { [weak self] in
      guard let self = self else { return }
      let matched = await self.matchedTransaction(productId: productId, transactionId: transactionId)

      guard let resolvedId = matched.map({ String($0.transaction.id) }) ?? transactionId else {
        SKLogger.logError("SkarbSDK.reportPurchase(\(productId)): no transactionId was passed and no transaction for this product is in the device history, so there is nothing the backend can be told. Pass the transaction id from the SDK that made the purchase.",
                          features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                     SKLoggerFeatureType.internalValue.name: productId])
        return
      }

      guard self.markReported(resolvedId) else {
        SKLogger.logInfo("SKStoreKitService: reportPurchase - transaction \(resolvedId) for \(productId) was already reported in this session, ignoring")
        return
      }
      if await self.isAlreadyReportedToBackend(resolvedId) {
        SKLogger.logInfo("SKStoreKitService: reportPurchase - transaction \(resolvedId) for \(productId) is already queued for the backend, ignoring")
        return
      }

      if matched == nil {
        SKLogger.logInfo("SKStoreKitService: reportPurchase - \(productId) is not in the device transaction history, reporting without a signed transaction")
      }
      await self.reportPurchased(SKPurchaseEvent(productId: productId,
                                                 transactionId: resolvedId,
                                                 transactionDate: matched?.transaction.purchaseDate ?? transactionDate,
                                                 jws: matched?.jws))
    }
  }

  var canMakePayments: Bool {
    return AppStore.canMakePayments
  }
}

// MARK: - StoreKit 1 queue

@available(iOS 15.0, *)
extension SKStoreKit2ServiceImplementation: SKPaymentTransactionObserver {

  /// Kept for `shouldAddStorePayment` and for finishing leftovers - it reports no purchases.
  ///
  /// It was expected to be the channel for purchases another SDK makes, the way it is on
  /// StoreKit 1. It is not. Measured on a sandbox device 23-24.09.2026 across seven runs: of 469
  /// `.purchased` states the queue delivered, every one was history from an earlier install, and
  /// none was the purchase just made - not even when the transaction was deliberately left
  /// unfinished for five seconds first. `sweepPurchaseHistory` had it 141 ms after `finish()`.
  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    for transaction in transactions {
      let productId = transaction.payment.productIdentifier
      // Every state, before any filtering. Whether the queue says anything at all about a
      // purchase another SDK made is the question this channel exists to answer, and silence
      // from `.purchased` alone cannot tell "the queue never heard of it" from "the queue heard
      // of it but never completed it".
      SKLogger.logInfo("SKStoreKitService: queue delivered \(Self.describe(transaction.transactionState)) for \(productId), transactionId \(transaction.transactionIdentifier ?? "nil"), ourPurchase = \(hasPendingPurchase(productId))")
      switch transaction.transactionState {
        case .purchased:
          // Deliberately not reported. Measured on a sandbox device 23.09.2026 across two runs:
          // for a StoreKit 2 purchase another SDK made and finished, the queue stayed silent,
          // and everything it DID deliver was history from earlier installs that the backend
          // already has. `sweepPurchaseHistory` is what catches a foreign purchase now.
          break

        case .purchasing:
          guard !hasPendingPurchase(productId) else { break }
          notifyObserver(.purchasing, productId: productId)

        case .deferred:
          guard !hasPendingPurchase(productId) else { break }
          notifyObserver(.deferred, productId: productId)

        case .failed:
          if !hasPendingPurchase(productId) {
            // Same fallback as the StoreKit 1 path: the queue does not promise an error object.
            let error = transaction.error ?? SKResponseError(errorCode: 0, message: "Purchasing failed")
            notifyObserver(.failed(error), productId: productId)
          }
          finishQueueLeftover(transaction, queue: queue)

        case .restored:
          finishQueueLeftover(transaction, queue: queue)

        @unknown default:
          break
      }
    }
  }

  static func describe(_ state: SKPaymentTransactionState) -> String {
    switch state {
      case .purchasing: return ".purchasing"
      case .purchased: return ".purchased"
      case .failed: return ".failed"
      case .restored: return ".restored"
      case .deferred: return ".deferred"
      @unknown default: return "unknown(\(state.rawValue))"
    }
  }

  /// A state the queue delivers and nobody finishes stays there and is redelivered on every
  /// launch, forever. `isObservable` means somebody else owns finishing.
  private func finishQueueLeftover(_ transaction: SKPaymentTransaction, queue: SKPaymentQueue) {
    guard !isObservable else { return }
    SKLogger.logInfo("SKStoreKitService: finishing StoreKit 1 queue leftover for \(transaction.payment.productIdentifier), state \(transaction.transactionState.rawValue)")
    queue.finishTransaction(transaction)
  }

  func paymentQueue(_ queue: SKPaymentQueue,
                    shouldAddStorePayment payment: SKPayment,
                    for product: SKProduct) -> Bool {
    if let delegate = delegate {
      return delegate.storeKit(shouldAddStorePayment: payment, for: product)
    }
    return observer?.skarbShouldAddStorePayment(productId: product.productIdentifier) ?? false
  }
}

// MARK: - Private

@available(iOS 15.0, *)
private extension SKStoreKit2ServiceImplementation {

  // MARK: Transaction observation

  /// Started in `init`, before any `await`, so no update can be missed.
  func startTransactionUpdatesListener() {
    updatesTask = Task(priority: .background) { [weak self] in
      for await verification in StoreKit.Transaction.updates {
        guard let self = self else { return }
        await self.handle(verification, source: "Transaction.updates")
      }
    }
  }

  /// Purchases made outside SkarbSDK - by Adapty, RevenueCat or the host's own StoreKit code.
  ///
  /// Measured on a sandbox device 23.09.2026, twice: for a StoreKit 2 purchase another SDK made
  /// and finished immediately, BOTH `Transaction.updates` and the StoreKit 1 payment queue said
  /// nothing at all, while `Transaction.all` carried the transaction 141 ms after `finish()`.
  /// This is the only channel that sees such a purchase without the host reporting it.
  ///
  /// `Transaction.all` is a FINITE sequence - a snapshot, not a subscription - so it has to be
  /// read again on every occasion worth reading: launch, and the app coming back to the front.
  /// A purchase therefore reaches the backend at the next such moment, not at the instant it
  /// happens. `SkarbSDK.reportPurchase` is what a host uses when that delay is not acceptable.
  func startHistorySweep() {
    sweepTask = Task(priority: .background) { [weak self] in
      await self?.sweepPurchaseHistory(reason: "launch")
    }
    NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                           object: nil,
                                           queue: nil) { [weak self] _ in
      Task(priority: .background) { [weak self] in
        await self?.sweepPurchaseHistory(reason: "foreground")
      }
    }
  }

  /// Only what happened after this install travels. Anything older belongs to a previous install,
  /// carries no attribution for this one, and the backend already has it from the receipt and
  /// from App Store Server Notifications. Without the cutoff the first sweep of a device with
  /// history costs one `setReceipt` per transaction - measured on the same device: 38 commands
  /// and 1.1 MB in 16 seconds.
  ///
  /// Renewals are NOT filtered by `originalID != id`, which looks like the obvious rule and is
  /// wrong: a resubscribe after a lapse and a subscription upgrade both keep the old lineage, so
  /// a freshly bought subscription arrives with an `originalID` that is not its own id. Measured
  /// on one device, that rule would have dropped 8 of 16 real purchases. `Transaction.reason`
  /// below is what separates them; the install cutoff and the durable dedup keep the volume down.
  func sweepPurchaseHistory(reason: String) async {
    let cutoff = Self.appInstallDate
    var seen = 0
    var reported = 0
    // Tallied over EVERYTHING in history, not only what gets reported. Whether
    // `Transaction.reason` can be trusted to separate a renewal from a resubscribe is the one
    // question that decides if renewals may be dropped, and it is answered by the history a
    // device already carries - no purchase needed.
    var reasons: [String: Int] = [:]
    var initialPurchases: [String] = []
    for await verification in StoreKit.Transaction.all {
      guard case .verified(let transaction) = verification else { continue }
      seen += 1
      if #available(iOS 17.0, *) {
        reasons[transaction.reason.rawValue, default: 0] += 1
        if transaction.reason == .purchase {
          initialPurchases.append("\(transaction.id)/\(transaction.productID)/orig \(transaction.originalID)")
        }
        // Dropped only when the renewal is EXPLICIT. `Transaction.Reason` is a struct, not an
        // enum, so Apple can add values without breaking the build - and an unrecognised one
        // has to travel rather than vanish, because losing a real purchase costs more than
        // sending a redundant renewal. On iOS 16 and below there is no `reason` at all and the
        // install cutoff below is the only thing keeping the volume down.
        //
        // Renewals are dropped because the backend receives them from App Store Server
        // Notifications anyway. Measured on one device: 56 of 72 transactions.
        if transaction.reason == .renewal { continue }
      }
      guard transaction.revocationDate == nil else { continue }
      guard transaction.purchaseDate >= cutoff else { continue }

      let transactionId = String(transaction.id)
      guard markReported(transactionId) else { continue }
      if await isAlreadyReportedToBackend(transactionId) { continue }

      SKLogger.logInfo("SKStoreKitService: history sweep (\(reason)) found unreported transaction \(transactionId) for \(transaction.productID), purchased \(transaction.purchaseDate), original \(transaction.originalID)\(Self.describeReason(transaction))")
      await reportPurchased(SKPurchaseEvent(transaction: transaction,
                                            jws: verification.jwsRepresentation))
      reported += 1
    }
    SKLogger.logInfo("SKStoreKitService: history sweep (\(reason)) done - \(seen) transaction(s) in history, cutoff \(cutoff), \(reported) reported")
    if !reasons.isEmpty {
      SKLogger.logInfo("SKStoreKitService: history sweep (\(reason)) by Transaction.reason: \(reasons.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", "))")
      SKLogger.logInfo("SKStoreKitService: history sweep (\(reason)) reason == .purchase: [\(initialPurchases.joined(separator: ", "))]")
    }
  }

  /// `Transaction.reason` tells a first purchase from a renewal properly, but only from iOS 17.
  /// Logged rather than acted on until there is a measurement to back a rule on it.
  static func describeReason(_ transaction: StoreKit.Transaction) -> String {
    if #available(iOS 17.0, *) {
      return ", reason \(transaction.reason)"
    }
    return ""
  }

  /// Creation date of the Documents folder - the same value `installV4` sends as `docDate`.
  static var appInstallDate: Date {
    guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last,
          let created = try? FileManager.default.attributesOfItem(atPath: documents.path)[.creationDate] as? Date else {
      SKLogger.logInfo("SKStoreKitService: could not read the install date, sweeping the whole history")
      return Date(timeIntervalSince1970: 0)
    }
    return created
  }

  /// Recovers transactions left unfinished by a previous run, e.g. after a crash between
  /// the purchase and `finish()`.
  func drainUnfinishedTransactions() {
    unfinishedTask = Task(priority: .background) { [weak self] in
      for await verification in StoreKit.Transaction.unfinished {
        guard let self = self else { return }
        SKLogger.logInfo("SKStoreKitService: draining unfinished transaction at launch")
        await self.handle(verification, source: "Transaction.unfinished")
      }
    }
  }

  func handle(_ verification: VerificationResult<StoreKit.Transaction>, source: String) async {
    switch verification {
      case .verified(let transaction):
        // Logged before any filtering, for the same reason the queue logs every state: whether a
        // channel saw a purchase at all has to be separable from what was done about it.
        SKLogger.logInfo("SKStoreKitService: \(source) delivered transaction \(transaction.id) for \(transaction.productID), purchased \(transaction.purchaseDate), original \(transaction.originalID), ourPurchase = \(hasPendingPurchase(transaction.productID))")
        if let revocationDate = transaction.revocationDate {
          SKLogger.logInfo("SKStoreKitService: \(source) reported REVOKED transaction \(transaction.id) for \(transaction.productID), revoked at \(revocationDate). Finishing without reporting.")
          await settle(transaction)
          return
        }
        guard markReported(String(transaction.id)) else {
          SKLogger.logInfo("SKStoreKitService: \(source) re-delivered transaction \(transaction.id) for \(transaction.productID), already reported in this session. Finishing without reporting again.")
          await settle(transaction)
          // Reported already, but `purchase()` may have parked a completion it never answered.
          await resolvePendingPurchase(transaction.productID, .success(true))
          return
        }
        // A device can carry a large backlog of never-finished transactions - 45 on one
        // measured TestFlight install - and the launch drain hands over every one. Without this
        // each would cost a product fetch, a command-building pass and a fresh `.purchased`.
        if await isAlreadyReportedToBackend(String(transaction.id)) {
          SKLogger.logInfo("SKStoreKitService: \(source) delivered transaction \(transaction.id) for \(transaction.productID), already reported in an earlier session. Finishing without reporting again.")
          await settle(transaction)
          // A caller waiting on this product is not a backlog entry - it is somebody who just
          // tapped buy, and its paywall spinner would hang. Nothing waits during a launch drain.
          if hasPendingPurchase(transaction.productID) {
            notifyObserver(.purchased, productId: transaction.productID)
            await resolvePendingPurchase(transaction.productID, .success(true))
          }
          return
        }
        SKLogger.logInfo("SKStoreKitService: \(source) reported transaction \(transaction.id) for \(transaction.productID), purchased \(transaction.purchaseDate), expires \(String(describing: transaction.expirationDate))")
        await reportPurchased(SKPurchaseEvent(transaction: transaction, jws: verification.jwsRepresentation))
        notifyObserver(.purchased, productId: transaction.productID)
        await settle(transaction)
        // No-op unless a `purchasePackage` caller is still waiting on this product.
        await resolvePendingPurchase(transaction.productID, .success(true))

      case .unverified(let transaction, let error):
        SKLogger.logError("SKStoreKitService: \(source) reported an UNVERIFIED transaction \(transaction.id) for \(transaction.productID). Not reported to the backend. Error = \(error.localizedDescription)",
                          features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                     SKLoggerFeatureType.internalValue.name: transaction.productID])
    }
  }

  /// The StoreKit 2 transaction behind a queue-reported purchase - for its JWS, and to finish it
  /// through the same path every other transaction takes. A nil `transactionId` means "the newest
  /// for this product", which is what `SkarbSDK.reportPurchase` passes when the host knows only
  /// the product. Returning nil is normal: a consumable is absent from history unless the host
  /// sets `SKIncludeConsumableInAppPurchaseHistory` (iOS 18+).
  func matchedTransaction(productId: String,
                          transactionId: String?) async -> (transaction: StoreKit.Transaction, jws: String)? {
    guard let verification = await StoreKit.Transaction.latest(for: productId) else {
      return nil
    }
    guard case .verified(let transaction) = verification else {
      SKLogger.logInfo("SKStoreKitService: latest transaction for \(productId) is UNVERIFIED, not used as a signed transaction")
      return nil
    }
    if let transactionId = transactionId, String(transaction.id) != transactionId {
      SKLogger.logInfo("SKStoreKitService: latest transaction for \(productId) is \(transaction.id) but \(transactionId) was reported - not the same purchase")
      return nil
    }
    return (transaction, verification.jwsRepresentation)
  }

  // MARK: Reporting

  /// The single place both channels turn an observed purchase into backend commands. It takes an
  /// `SKPurchaseEvent` rather than a `StoreKit.Transaction` so the queue path fits: it has only
  /// an `SKPaymentTransaction` when no signed transaction could be matched.
  func reportPurchased(_ event: SKPurchaseEvent) async {
    // Product metadata drives the intro-offer suppression of `.setReceipt` and the
    // region / currency fields, so cache it before building commands.
    await ensureProductCached(event.productId)
    await buildCommands { factory in
      factory.createFetchProductsCommand(purchasedEvents: [event])
      factory.createPurchaseAndTransactionCommand(purchasedEvents: [event])
    }
  }

  func makeCommandFactory() async -> SKPurchaseCommandFactory {
    let countryCode = await Storefront.current?.countryCode
    return SKPurchaseCommandFactory(cachedProducts: allProducts ?? [],
                                    storefrontCountryCode: countryCode)
  }

  /// Runs command building off the cooperative pool, see `commandQueue`.
  func buildCommands(_ work: @escaping (SKPurchaseCommandFactory) -> Void) async {
    let factory = await makeCommandFactory()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      commandQueue.async {
        work(factory)
        continuation.resume()
      }
    }
  }

  /// Whether the backend already has this id. Unlike `markReported`, which is in-memory and only
  /// covers one session, this survives restarts: `transactionV4` commands outlive their sending.
  ///
  /// Async for the same reason `buildCommands` is: the read goes through `SKCommandStore`'s own
  /// serial queue, and a `queue.sync` from a `Task` parks a cooperative-pool thread.
  func isAlreadyReportedToBackend(_ transactionId: String) async -> Bool {
    return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
      commandQueue.async {
        continuation.resume(returning: SKServiceRegistry.commandStore.getNewTransactionIds([transactionId]).isEmpty)
      }
    }
  }

  /// Returns true the first time a transaction id is seen, false on every redelivery.
  func markReported(_ transactionId: String) -> Bool {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    return reportedTransactionIds.insert(transactionId).inserted
  }

  /// `isObservable == true` means the host app owns finishing.
  func settle(_ transaction: StoreKit.Transaction) async {
    guard isObservable else {
      await transaction.finish()
      SKLogger.logInfo("SKStoreKitService: finished transaction \(transaction.id) for \(transaction.productID)")
      return
    }
    guard let observer = observer else {
      SKLogger.logInfo("SKStoreKitService: isObservable == true and no SKStoreKitObserver is set, so transaction \(transaction.id) for \(transaction.productID) stays unfinished - StoreKit 2 will redeliver it on every launch. Set an observer or initialize with isObservable: false.")
      return
    }
    let handle = SKTransactionHandle(productId: transaction.productID, finishAction: {
      Task {
        await transaction.finish()
        SKLogger.logInfo("SKStoreKitService: host app finished transaction \(transaction.id)")
      }
    })
    await MainActor.run {
      observer.skarbTransactionNeedsFinish(handle)
    }
  }

  // MARK: Product cache

  func cache(_ products: [Product]) {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    for product in products {
      cachedStoreProducts[product.id] = product
      // Matches StoreKit 1: an already-cached product is not refreshed.
      if cachedAllProducts.first(where: { $0.productId == product.id }) == nil {
        cachedAllProducts.append(SKProductInfo(product: product))
      }
    }
  }

  func ensureProductCached(_ productId: String) async {
    if fetchProduct(by: productId) != nil {
      return
    }
    do {
      let products = try await Product.products(for: [productId])
      cache(products)
      SKLogger.logInfo("SKStoreKitService: fetched metadata for \(productId) before building commands")
    } catch {
      SKLogger.logInfo("SKStoreKitService: could not fetch metadata for \(productId) before building commands: \(error.localizedDescription)")
    }
  }

  func storeProduct(for productId: String) async throws -> Product {
    cacheLock.lock()
    let cached = cachedStoreProducts[productId]
    cacheLock.unlock()
    if let cached = cached {
      return cached
    }
    let products = try await Product.products(for: [productId])
    cache(products)
    guard let product = products.first(where: { $0.id == productId }) else {
      throw SKResponseError(errorCode: 0, message: "There is no product for \(productId)")
    }
    return product
  }

  // MARK: Pending purchases

  func parkPendingPurchase(_ productId: String, _ completion: @escaping (Result<Bool, Error>) -> Void) {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    if let previous = pendingPurchases[productId] {
      // The map holds one completion per product, so the earlier caller must be answered here.
      SKLogger.logInfo("SKStoreKitService: a purchase of \(productId) was already in flight, answering the previous caller with a failure")
      let error = SKResponseError(errorCode: 0, message: "Another purchase of this product was started")
      DispatchQueue.main.async { previous(.failure(error)) }
    }
    pendingPurchases[productId] = completion
  }

  func hasPendingPurchase(_ productId: String) -> Bool {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    return pendingPurchases[productId] != nil
  }

  /// Answers a parked `purchasePackage` completion exactly once - whichever path gets here first
  /// wins, the others find nothing.
  func resolvePendingPurchase(_ productId: String, _ result: Result<Bool, Error>) async {
    cacheLock.lock()
    let completion = pendingPurchases.removeValue(forKey: productId)
    cacheLock.unlock()

    guard let completion = completion else {
      return
    }
    await MainActor.run {
      completion(result)
    }
  }

  func deliver(_ completion: @escaping (Result<Bool, Error>) -> Void,
               _ result: Result<Bool, Error>) async {
    await MainActor.run {
      completion(result)
    }
  }

  func deliverProducts(_ completion: @escaping (Result<[SKProductInfo], Error>) -> Void,
                       _ result: Result<[SKProductInfo], Error>) async {
    await MainActor.run {
      completion(result)
    }
  }

  func notifyObserver(_ state: SKPurchaseState, productId: String) {
    DispatchQueue.main.async { [weak self] in
      self?.observer?.skarbPurchaseStateDidChange(state, productId: productId)
    }
  }
}

// MARK: - Signed transactions

/// Separate from the private extension above on purpose: this satisfies `SKStoreKitService`,
/// so it has to be at least internal, and declaring it `internal` inside a `private extension`
/// is a warning.
@available(iOS 15.0, *)
extension SKStoreKit2ServiceImplementation {

  /// Consumables and live entitlements from the account's history, as signed by Apple.
  /// `Transaction.all` rather than `currentEntitlements`, which drops a consumable at `finish()`.
  /// Consumables appear here ONLY when the host sets `SKIncludeConsumableInAppPurchaseHistory`
  /// (iOS 18+). One JWS measures ~5.4 KB, which is why the count and size are logged.
  func collectSignedTransactions(completion: @escaping ([String]) -> Void) {
    Task {
      // Mapped into a StoreKit-free candidate so the choice of what to send can live in
      // `SKSignedTransactionSelection`, where it is testable.
      var candidates: [SKSignedTransactionCandidate] = []
      for await verification in StoreKit.Transaction.all {
        // Unverified is not proof of anything, same rule as on the reporting path.
        guard case .verified(let transaction) = verification else { continue }
        candidates.append(SKSignedTransactionCandidate(transactionId: String(transaction.id),
                                                       productId: transaction.productID,
                                                       productType: transaction.productType.rawValue,
                                                       purchaseDate: transaction.purchaseDate,
                                                       expirationDate: transaction.expirationDate,
                                                       revocationDate: transaction.revocationDate,
                                                       jws: verification.jwsRepresentation))
      }

      let selected = SKSignedTransactionSelection.prepare(candidates, now: Date())
      if candidates.count > selected.count {
        SKLogger.logInfo("SKStoreKitService: \(candidates.count) transaction(s) in history, \(selected.count) selected for signed_transactions (expired and revoked dropped, cap \(Purchaseapi_ReceiptRequest.maxSignedTransactions))")
      }
      let totalBytes = selected.reduce(0) { $0 + $1.jws.count }
      let consumables = selected.filter { $0.productType == SKSignedTransactionCandidate.consumableType }.count
      SKLogger.logInfo("verifyReceipt signed_transactions (field 4): \(selected.count) transaction(s) - \(consumables) consumable(s) plus live entitlements, \(totalBytes / 1024) KB total")
      let described = selected.map { "\($0.transactionId)/\($0.productId)/\($0.productType)" }
      SKLogger.logInfo("verifyReceipt signed_transactions detail: [\(described.joined(separator: ", "))]")
      completion(selected.map { $0.jws })
    }
  }
}
