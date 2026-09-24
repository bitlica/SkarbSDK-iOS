//
//  SKPurchaseCommandFactory.swift
//  SkarbSDK
//

import Foundation

/// Builds and enqueues the backend commands for observed purchases. Both StoreKit
/// implementations funnel through here, so the wire payload cannot drift between v1 and v2.
/// The decisions the building rests on are the static functions below, covered by
/// `SKPurchaseCommandFactoryTests`.
struct SKPurchaseCommandFactory {

  /// Product metadata already cached by the StoreKit service.
  let cachedProducts: [SKProductInfo]
  /// Resolved by the caller: `SKPaymentQueue.storefront` on v1, `Storefront.current` on v2.
  let storefrontCountryCode: String?

  private var regionCode: String? {
    return cachedProducts.first?.regionCode
  }

  private var currencyCode: String? {
    return cachedProducts.first?.currencyCode
  }

  private func product(by productId: String) -> SKProductInfo? {
    return cachedProducts.first(where: { $0.productId == productId })
  }

//  MARK: Decisions

  /// Whether the app receipt has to travel for this product. Inherited from StoreKit 1: an
  /// unknown product always gets its receipt, a subscription does not need one because the system
  /// rewrites the receipt after the purchase. StoreKit 2 rewrites nothing and `transactionV4` has
  /// no field for a signature, so a purchase carrying one always gets its receipt.
  static func shouldSendReceipt(productId: String,
                                events: [SKPurchaseEvent],
                                product: SKProductInfo?) -> Bool {
    if events.contains(where: { $0.productId == productId && $0.jws != nil }) {
      return true
    }
    guard let product = product else {
      return true
    }
    return product.introductoryOffer == nil
  }

  /// The events the backend has not been told about yet, given the ids it considers new. An event
  /// without an id is always kept: StoreKit 1 can report one, and there is nothing to dedup it
  /// against, so dropping it would silently lose the purchase.
  static func unreportedEvents(_ events: [SKPurchaseEvent],
                               newTransactionIds: Set<String>) -> [SKPurchaseEvent] {
    return events.filter { event in
      guard let id = event.transactionId else { return true }
      return newTransactionIds.contains(id)
    }
  }

  /// One `SKFetchProduct` per product id, carrying its newest purchase. An event with no date
  /// loses to one that has a date - an unknown date must not pass for the most recent.
  static func fetchProducts(for events: [SKPurchaseEvent]) -> [SKFetchProduct] {
    let productIds = Array(Set(events.map { $0.productId }))
    var fetchProducts: [SKFetchProduct] = []
    for productId in productIds {
      let event = events
        .filter { $0.productId == productId }
        .sorted { $0.transactionDate ?? .distantPast < $1.transactionDate ?? .distantPast }.last
      if let event = event {
        fetchProducts.append(SKFetchProduct(productId: event.productId,
                                            transactionDate: event.transactionDate,
                                            transactionId: event.transactionId))
      }
    }
    return fetchProducts
  }

  /// Price payloads for the fetched products whose metadata actually arrived, plus the ids whose
  /// metadata did not - the caller logs those, since logging an error here would itself queue a
  /// command.
  static func priceProducts(for fetchProducts: [SKFetchProduct],
                            products: [SKProductInfo]) -> (products: [Priceapi_Product],
                                                           missingProductIds: [String]) {
    var priceApiProducts: [Priceapi_Product] = []
    var missing: [String] = []
    for fetchProduct in fetchProducts {
      guard let product = products.first(where: { $0.productId == fetchProduct.productId }) else {
        missing.append(fetchProduct.productId)
        continue
      }
      priceApiProducts.append(Priceapi_Product(product: product,
                                               transactionDate: fetchProduct.transactionDate,
                                               transactionId: fetchProduct.transactionId))
    }
    return (priceApiProducts, missing)
  }

  /// `unreportedEvents` against the durable check: an id `getNewTransactionIds` does not consider
  /// new was queued before, in this run or an earlier one. Until this existed only
  /// `transactionV4` was protected, so `setReceipt`, `priceV4` and `fetchProducts` were rebuilt
  /// every time the same purchase was observed again.
  static func newEvents(_ events: [SKPurchaseEvent]) -> [SKPurchaseEvent] {
    let ids = events.compactMap { $0.transactionId }
    guard !ids.isEmpty else {
      return events
    }
    let unknown = Set(SKServiceRegistry.commandStore.getNewTransactionIds(ids))
    let kept = unreportedEvents(events, newTransactionIds: unknown)
    if kept.count < events.count {
      let dropped = events.count - kept.count
      SKLogger.logInfo("SKPurchaseCommandFactory: \(dropped) of \(events.count) purchase(s) already queued for the backend, not rebuilt")
    }
    return kept
  }

//  MARK: Commands

  func createFetchProductsCommand(purchasedEvents: [SKPurchaseEvent]) {
    let purchasedEvents = Self.newEvents(purchasedEvents)
    guard !purchasedEvents.isEmpty else {
      return
    }
    let fetchProducts = Self.fetchProducts(for: purchasedEvents)
    let encoder = JSONEncoder()
    if let productData = try? encoder.encode(fetchProducts) {
      let fetchCommand = SKCommand(commandType: .fetchProducts,
                                   status: .pending,
                                   data: productData)
      SKServiceRegistry.commandStore.saveCommand(fetchCommand)
      SKLogger.logInfo("SKPurchaseCommandFactory: created fetchProducts command for \(fetchProducts.map { $0.productId })")
    } else {
      SKLogger.logError("paymentQueue updatedTransactions: called. Need to fetch products but purchasedProductId.data(using: .utf8) == nil",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.internalValue.name: fetchProducts.description])
    }
  }

  func createPurchaseAndTransactionCommand(purchasedEvents: [SKPurchaseEvent]) {
    let purchasedEvents = Self.newEvents(purchasedEvents)
    guard !purchasedEvents.isEmpty else {
      return
    }
    let transactionIds: [String] = purchasedEvents.compactMap { $0.transactionId }
    // Empty under StoreKit 1: only StoreKit 2 has signed transactions.
    let signedTransactions: [String] = purchasedEvents.compactMap { $0.jws }
    let installData = SKServiceRegistry.commandStore.getDeviceRequest()

    SKLogger.logInfo("SKPurchaseCommandFactory: building commands. storefront = \(storefrontCountryCode ?? "nil"), region = \(regionCode ?? "nil"), currency = \(currencyCode ?? "nil"), transactions = \(transactionIds)")
    // The receipt is read into the payload inside `Purchaseapi_ReceiptRequest.init`, so its state
    // at this exact moment is the only way to tell an empty payload caused by a missing receipt
    // from one caused by the App Store writing the file a moment later than we asked for it.
    SKLogger.logInfo("SKPurchaseCommandFactory: app receipt at command-creation time - \(Self.receiptState())")

    if !SKServiceRegistry.commandStore.hasPurhcaseV4Command {
      let purchaseDataV4 = Purchaseapi_ReceiptRequest(storefront: storefrontCountryCode,
                                                      region: regionCode,
                                                      currency: currencyCode,
                                                      newTransactions: transactionIds,
                                                      newSignedTransactions: signedTransactions,
                                                      docFolderDate: installData?.docDate,
                                                      appBuildDate: installData?.buildDate)
      let purchaseV4Command = SKCommand(commandType: .purchaseV4,
                                        status: .pending,
                                        data: purchaseDataV4.getData())
      SKServiceRegistry.commandStore.saveCommand(purchaseV4Command)
      SKLogger.logInfo("SKPurchaseCommandFactory: created purchaseV4 command (first purchase)")
    }

    // Just no need to send receipt for duplicated product identifiers
    let productIdentifiers = Set(purchasedEvents.map { $0.productId })
    for productId in productIdentifiers {
      let shouldSendPurchase = Self.shouldSendReceipt(productId: productId,
                                                      events: purchasedEvents,
                                                      product: product(by: productId))
      if shouldSendPurchase {
        let purchaseDataV4 = Purchaseapi_ReceiptRequest(storefront: storefrontCountryCode,
                                                        region: regionCode,
                                                        currency: currencyCode,
                                                        newTransactions: transactionIds,
                                                        newSignedTransactions: signedTransactions,
                                                        docFolderDate: installData?.docDate,
                                                        appBuildDate: installData?.buildDate)
        let purchaseV4Command = SKCommand(commandType: .setReceipt,
                                          status: .pending,
                                          data: purchaseDataV4.getData())
        SKServiceRegistry.commandStore.saveCommand(purchaseV4Command)
        SKLogger.logInfo("SKPurchaseCommandFactory: created setReceipt command for \(productId). signed_transactions (field 15): \(signedTransactions.count) - \(purchasedEvents.map { "\($0.transactionId ?? "nil")/\($0.jws?.count ?? 0)ch" })")
      } else {
        SKLogger.logInfo("SKPurchaseCommandFactory: skipped setReceipt for \(productId) - product has an introductory offer and the purchase carries no signed transaction")
      }
    }

    // Always sends transactions even in case if it was the first purchase
    // and transactions are included into purchase command
    let newTransactions = SKServiceRegistry.commandStore.getNewTransactionIds(transactionIds)
    if !newTransactions.isEmpty {
      let transactionDataV4 = Purchaseapi_TransactionsRequest(newTransactions: newTransactions,
                                                              docFolderDate: installData?.docDate,
                                                              appBuildDate: installData?.buildDate)
      let transactionV4Command = SKCommand(commandType: .transactionV4,
                                           status: .pending,
                                           data: transactionDataV4.getData())
      SKServiceRegistry.commandStore.saveCommand(transactionV4Command)
      SKLogger.logInfo("SKPurchaseCommandFactory: created transactionV4 command for \(newTransactions)")
    } else {
      SKLogger.logInfo("SKPurchaseCommandFactory: no new transactions to report, all of \(transactionIds) are already queued")
    }
  }

  func createPriceCommand(fetchProducts: [SKFetchProduct],
                          products: [SKProductInfo],
                          command: SKCommand) {
    let (priceApiProducts, missing) = Self.priceProducts(for: fetchProducts, products: products)
    for productId in missing {
      SKLogger.logError("SKSyncServiceImplementation. Send command for price. Product is nil. FetchProduct = \(productId)",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.retryCount.name: command.retryCount])
    }

    guard !priceApiProducts.isEmpty else {
      return
    }

    let productRequest = Priceapi_PricesRequest(storefront: storefrontCountryCode,
                                                region: products.first?.regionCode,
                                                currency: products.first?.currencyCode,
                                                products: priceApiProducts)
    let priceCommand = SKCommand(commandType: .priceV4,
                                 status: .pending,
                                 data: productRequest.getData())
    SKServiceRegistry.commandStore.saveCommand(priceCommand)

    for priceApiProduct in priceApiProducts {
      SKLogger.logInfo("SKPurchaseCommandFactory: priceV4 product \(priceApiProduct.productID) - price \(priceApiProduct.price), period \(priceApiProduct.period.unit)/\(priceApiProduct.period.count), intro mode \(priceApiProduct.intro.mode) type \(priceApiProduct.intro.type), discounts \(priceApiProduct.discounts.count)")
    }
    SKLogger.logInfo("SKPurchaseCommandFactory: created priceV4 command. storefront = \(storefrontCountryCode ?? "nil"), region = \(products.first?.regionCode ?? "nil"), currency = \(products.first?.currencyCode ?? "nil")")
  }

  /// Presence and size of the app receipt file, for logging.
  static func receiptState() -> String {
    guard let url = Bundle.main.appStoreReceiptURL else {
      return "appStoreReceiptURL is nil"
    }
    guard FileManager.default.fileExists(atPath: url.path) else {
      return "no file at \(url.lastPathComponent)"
    }
    guard let data = try? Data(contentsOf: url) else {
      return "file at \(url.lastPathComponent) exists but is unreadable"
    }
    return "\(data.count) bytes at \(url.lastPathComponent)"
  }
}
