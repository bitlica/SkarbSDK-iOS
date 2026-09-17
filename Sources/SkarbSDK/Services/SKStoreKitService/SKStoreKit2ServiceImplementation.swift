//
//  SKStoreKit2ServiceImplementation.swift
//  SkarbSDK
//

import Foundation
import StoreKit

/// StoreKit 2 implementation of `SKStoreKitService`.
///
/// The backend contract is additive, not replaced: the app receipt still travels in every
/// command, and every command is built by `SKPurchaseCommandFactory`, the same one the StoreKit 1
/// path uses. What StoreKit 2 adds on top:
///
/// - Apple-signed transactions (`VerificationResult.jwsRepresentation`) alongside the receipt -
///   the purchase's own in `SetReceipt`, and consumables plus live entitlements from
///   `Transaction.all` in `VerifyReceipt` (see `collectSignedTransactions`). Nothing else can
///   prove a consumable: a StoreKit 2 receipt has no `in_app` entry for one.
///
/// Entitlements themselves stay entirely server-derived, on both versions: `SKUserPurchaseInfo`
/// is built from the `verifyReceipt` answer and the SDK adds nothing of its own to it.
@available(iOS 15.0, *)
final class SKStoreKit2ServiceImplementation: NSObject, SKStoreKitService {

//  MARK: Public

  weak var delegate: SKStoreKitDelegate?
  weak var observer: SKStoreKitObserver?

//  MARK: Private
  private let isObservable: Bool

  /// `NSLock` rather than a serial `DispatchQueue`: this cache is touched from async
  /// contexts, and a `queue.sync` there parks a cooperative-pool thread.
  private let cacheLock = NSLock()
  private var cachedAllProducts: [SKProductInfo] = []
  /// Raw StoreKit 2 products, needed to start a purchase.
  private var cachedStoreProducts: [String: Product] = [:]

  private var updatesTask: Task<Void, Never>?
  private var unfinishedTask: Task<Void, Never>?

  /// A transaction is delivered by BOTH `purchase()` and `Transaction.updates`, and at launch by
  /// both `Transaction.updates` and `Transaction.unfinished`. Without this it gets reported to
  /// the backend more than once, which duplicates `priceV4`.
  private var reportedTransactionIds: Set<UInt64> = []

  /// Completions of `purchasePackage` calls that have not been answered yet, keyed by product id.
  ///
  /// `product.purchase()` is not a reliable way to learn that a purchase went through. Measured
  /// on a live sandbox build on 14.09.2026, it failed in two different ways while the purchase
  /// itself completed and reached the backend through `Transaction.updates`:
  ///
  /// - it never returned at all, leaving the paywall spinner up forever;
  /// - it returned `.userCancelled` eleven seconds after the sheet had already closed, with the
  ///   user having tapped nothing.
  ///
  /// Both left the caller waiting for a result that the device already had. So the completion is
  /// parked here and whichever path sees the transaction first answers it - the `purchase()`
  /// continuation or the `Transaction.updates` listener.
  private var pendingPurchases: [String: (Result<Bool, Error>) -> Void] = [:]

  /// Command building calls into `SKCommandStore`, which is GCD-serial-queue based. Running that
  /// straight from a `Task` parks a cooperative-pool thread on `queue.sync`, so it is pushed onto
  /// a regular queue instead.
  private let commandQueue = DispatchQueue(label: "com.skarbSDK.skStoreKit2.commands")

  var allProducts: [SKProductInfo]? {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    return cachedAllProducts
  }

  init(isObservable: Bool) {
    self.isObservable = isObservable
    super.init()
    // The StoreKit 1 queue is kept ONLY to answer `shouldAddStorePayment` for purchases
    // promoted in the App Store. StoreKit 2 replaces it with `PurchaseIntent`, which needs
    // iOS 16.4, so that is a follow-up. No transaction handling happens through it.
    SKPaymentQueue.default().add(self)
    startTransactionUpdatesListener()
    drainUnfinishedTransactions()
    SKLogger.logInfo("SKStoreKitService: running on StoreKit 2. isObservable = \(isObservable) (SDK \(isObservable ? "will NOT" : "will") finish transactions)")
  }

  deinit {
    updatesTask?.cancel()
    unfinishedTask?.cancel()
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
                if self.markReported(transaction) {
                  await self.reportPurchased(transaction, jws: verification.jwsRepresentation)
                  // Notified only by whichever path actually reported the transaction.
                  // `Transaction.updates` delivers the same one, and if it wins the race it
                  // notifies from `handle(_:source:)` - otherwise the observer would see
                  // `.purchased` twice for a single purchase.
                  self.notifyObserver(.purchased, productId: package.productId)
                } else {
                  SKLogger.logInfo("transaction \(transaction.id) was already reported by Transaction.updates, not reporting again")
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
            // NOT necessarily the user: StoreKit returns `.userCancelled` for a sheet that
            // dismissed itself too - a sandbox account that cannot authenticate, a timeout -
            // and carries no reason code to tell them apart.
            //
            // Reported immediately all the same. An earlier version waited several seconds here
            // in case `Transaction.updates` contradicted it, but that delay is paid on every
            // real cancellation - closing the sheet felt broken - and it never once paid off:
            // in both observed false cancellations no transaction ever arrived, and the case
            // that does need rescuing is a `purchase()` that never returns at all, which the
            // `Transaction.updates` path below handles on its own.
            //
            // The guard is still worth keeping: if updates won the race and already answered the
            // caller, there is nothing left to fail.
            guard self.hasPendingPurchase(package.productId) else {
              SKLogger.logInfo("purchase for \(package.productId) came back as userCancelled, but Transaction.updates had already reported it - the cancellation was not real")
              return
            }
            SKLogger.logInfo("purchase for \(package.productId) came back as userCancelled")
            // Bridged into SKErrorDomain so `error as? SKError` keeps working in host apps
            // that already special-case cancellation.
            let error = NSError(domain: SKErrorDomain,
                                code: SKError.Code.paymentCancelled.rawValue,
                                userInfo: [NSLocalizedDescriptionKey: "Purchase was cancelled"])
            self.notifyObserver(.failed(error), productId: package.productId)
            await self.resolvePendingPurchase(package.productId, .failure(error))

          case .pending:
            // Ask-to-Buy / SCA. The completion MUST be called, otherwise the caller's
            // paywall spinner hangs forever waiting for a result that never arrives.
            SKLogger.logInfo("purchase for \(package.productId) is PENDING external approval (Ask-to-Buy / SCA). It will arrive through Transaction.updates once approved.")
            self.notifyObserver(.deferred, productId: package.productId)
            await self.resolvePendingPurchase(package.productId,
                                              .failure(SKResponseError(errorCode: 35,
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
        // Only what this response brought, not the whole cache: a single-product refetch after a
        // purchase used to print all 45 offering products and drown the interesting lines.
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

  var canMakePayments: Bool {
    return AppStore.canMakePayments
  }
}

// MARK: - Promoted purchases only

@available(iOS 15.0, *)
extension SKStoreKit2ServiceImplementation: SKPaymentTransactionObserver {

  /// Purchases are handled through `Transaction.updates`, so nothing is reported from here.
  ///
  /// `.failed` and `.restored` still have to be finished though: registering an observer makes
  /// the StoreKit 1 queue deliver them, and a state it delivers but nobody finishes stays in the
  /// queue and is redelivered on every launch, forever. `.purchased` is deliberately left alone -
  /// StoreKit 2 owns reporting and finishing it, and `finish()` there settles this queue too.
  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    guard !isObservable else {
      // The host app owns finishing in this mode, same rule as on the StoreKit 1 path.
      return
    }
    for transaction in transactions {
      switch transaction.transactionState {
        case .failed, .restored:
          SKLogger.logInfo("SKStoreKitService: finishing StoreKit 1 queue leftover for \(transaction.payment.productIdentifier), state \(transaction.transactionState.rawValue)")
          queue.finishTransaction(transaction)
        default:
          break
      }
    }
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
        if let revocationDate = transaction.revocationDate {
          SKLogger.logInfo("SKStoreKitService: \(source) reported REVOKED transaction \(transaction.id) for \(transaction.productID), revoked at \(revocationDate). Finishing without reporting.")
          await settle(transaction)
          return
        }
        guard markReported(transaction) else {
          SKLogger.logInfo("SKStoreKitService: \(source) re-delivered transaction \(transaction.id) for \(transaction.productID), already reported in this session. Finishing without reporting again.")
          await settle(transaction)
          // Reported already, but a caller can still be waiting - `purchase()` may have parked a
          // completion it never answered.
          await resolvePendingPurchase(transaction.productID, .success(true))
          return
        }
        // A device can carry a large backlog of transactions the app never finished - a
        // TestFlight install with a year of sandbox renewals showed 45 of them. StoreKit hands
        // every one of those to the launch drain, and without this check each would cost a
        // product fetch plus a full command-building pass, and would be announced to the host as
        // a fresh `.purchased`. `getNewTransactionIds` is the same durable dedup the backend
        // reporting already relies on, so an id it does not consider new has been reported
        // before: finish it and move on.
        if isAlreadyReportedToBackend(transaction) {
          SKLogger.logInfo("SKStoreKitService: \(source) delivered transaction \(transaction.id) for \(transaction.productID), already reported in an earlier session. Finishing without reporting or notifying again.")
          await settle(transaction)
          return
        }
        SKLogger.logInfo("SKStoreKitService: \(source) reported transaction \(transaction.id) for \(transaction.productID), purchased \(transaction.purchaseDate), expires \(String(describing: transaction.expirationDate))")
        await reportPurchased(transaction, jws: verification.jwsRepresentation)
        notifyObserver(.purchased, productId: transaction.productID)
        await settle(transaction)
        // A `purchasePackage` caller may still be waiting on this product: `purchase()` can hang
        // or answer `.userCancelled` while the transaction arrives here instead. No-op when
        // nothing is waiting, which is the normal case for a renewal or a launch-time drain.
        await resolvePendingPurchase(transaction.productID, .success(true))

      case .unverified(let transaction, let error):
        SKLogger.logError("SKStoreKitService: \(source) reported an UNVERIFIED transaction \(transaction.id) for \(transaction.productID). Not reported to the backend. Error = \(error.localizedDescription)",
                          features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                     SKLoggerFeatureType.internalValue.name: transaction.productID])
    }
  }

  // MARK: Reporting

  func reportPurchased(_ transaction: StoreKit.Transaction, jws: String) async {
    // Consumables are not recorded on the device. `verifyReceipt` is the single source of
    // truth for them: the backend resolves the reported transaction id against the App Store
    // Server API and returns the purchase in `onetimes`. The app receipt never carries one -
    // it was absent from all seven receipts examined on 14.09.2026 - so the signed transaction
    // below is what makes it resolvable. With it, and with
    // `SKIncludeConsumableInAppPurchaseHistory` set by the host, four consecutive consumables
    // came back from the server in 4 seconds each.
    //
    // Product metadata drives the intro-offer suppression of `.setReceipt` and the
    // region / currency fields, so make sure it is cached before building commands.
    await ensureProductCached(transaction.productID)
    let event = SKPurchaseEvent(transaction: transaction, jws: jws)
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

  /// Whether the backend already has this transaction id, across launches.
  ///
  /// Unlike `markReported`, which is in-memory and only guards against the same transaction
  /// arriving through two channels in one session, this survives restarts: it reads the command
  /// queue, which keeps `transactionV4` commands after they are done.
  func isAlreadyReportedToBackend(_ transaction: StoreKit.Transaction) -> Bool {
    let id = String(transaction.id)
    return SKServiceRegistry.commandStore.getNewTransactionIds([id]).isEmpty
  }

  /// Returns true the first time a transaction is seen, false on every redelivery.
  func markReported(_ transaction: StoreKit.Transaction) -> Bool {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    return reportedTransactionIds.insert(transaction.id).inserted
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

  // MARK: Callback plumbing


  // MARK: Pending purchases

  func parkPendingPurchase(_ productId: String, _ completion: @escaping (Result<Bool, Error>) -> Void) {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    if let previous = pendingPurchases[productId] {
      // Two overlapping calls for the same product: the earlier caller would otherwise never be
      // answered, because the map holds one completion per product.
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

  /// Answers a parked `purchasePackage` completion exactly once. Whichever of the two paths -
  /// the `purchase()` continuation or `Transaction.updates` - gets here first wins; the other
  /// finds nothing and does nothing.
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
  ///
  /// Walked over `Transaction.all` rather than `currentEntitlements`, because entitlements hold
  /// only what is active right now and drop a consumable at `finish()` - and that is exactly the
  /// user whose purchases the backend cannot resolve from the receipt either, since a StoreKit 2
  /// receipt carries no consumable `in_app` entry to key on. Expired subscriptions and past
  /// renewals are filtered out: see the guard in the loop.
  ///
  /// Consumables appear here ONLY when the host app sets
  /// `SKIncludeConsumableInAppPurchaseHistory` to true in its Info.plist; finished ones are
  /// omitted otherwise (measured 14.09.2026 without the key: all=61, consumables=0). Apple
  /// documents the key from iOS 18.
  ///
  /// Cost to be aware of: one JWS measures ~5.4 KB, so this is still a few KB per call on a
  /// normal account and grows with each consumable. The count and total size are logged for
  /// exactly that reason.
  func collectSignedTransactions(completion: @escaping ([String]) -> Void) {
    Task {
      // Mapped into a StoreKit-free candidate so the choice of what to send can live in
      // `SKSignedTransactionSelection`, where it is testable - `StoreKit.Transaction` has no
      // public initializer.
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
