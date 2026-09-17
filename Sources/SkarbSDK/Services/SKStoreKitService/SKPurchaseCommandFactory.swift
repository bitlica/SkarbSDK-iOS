//
//  SKPurchaseCommandFactory.swift
//  SkarbSDK
//

import Foundation

/// Builds and enqueues the backend commands for observed purchases.
///
/// Both StoreKit implementations funnel through here, so the wire payload cannot
/// drift between v1 and v2. Logic is a straight lift from the original
/// `SKStoreKitServiceImplementation` — comments included — so the payload stays identical.
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

  /// Create one SKFetchProduct or each unique productId.
  /// Need to attach the newest transaction Date and Id
  func createFetchProductsCommand(purchasedEvents: [SKPurchaseEvent]) {
    let productIds = Array(Set(purchasedEvents.map { $0.productId }))
    var fetchProducts: [SKFetchProduct] = []
    for productId in productIds {
      let event = purchasedEvents
        .filter { $0.productId == productId }
        .sorted { $0.transactionDate ?? Date() < $1.transactionDate ?? Date() }.last
      if let event = event {
        fetchProducts.append(SKFetchProduct(productId: event.productId,
                                            transactionDate: event.transactionDate,
                                            transactionId: event.transactionId))
      }
    }
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
    let transactionIds: [String] = purchasedEvents.compactMap { $0.transactionId }
    // Empty under StoreKit 1: only StoreKit 2 has signed transactions.
    let signedTransactions: [String] = purchasedEvents.compactMap { $0.jws }
    let installData = SKServiceRegistry.commandStore.getDeviceRequest()

    SKLogger.logInfo("SKPurchaseCommandFactory: building commands. storefront = \(storefrontCountryCode ?? "nil"), region = \(regionCode ?? "nil"), currency = \(currencyCode ?? "nil"), transactions = \(transactionIds)")
    // The receipt is read into the command payload right here, inside
    // `Purchaseapi_ReceiptRequest.init`. Logging its state at this exact moment is the only way
    // to tell an empty payload caused by a missing receipt from one caused by the App Store
    // writing the file a moment later than we asked for it.
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
      // default is true bacause we may not have product metadata and purchase might be not subscription
      // server should have each updated receipt at this case not to lose one time puchases
      // no needs to send receipt for subscription purchases
      var shouldSendPurchase = true
      if let product = product(by: productId),
         product.introductoryOffer != nil {
        shouldSendPurchase = false
      }
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
        SKLogger.logInfo("SKPurchaseCommandFactory: skipped setReceipt for \(productId) - product has an introductory offer")
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

  func createPriceCommand(fetchProducts: [SKFetchProduct],
                          products: [SKProductInfo],
                          command: SKCommand) {
    var priceApiProducts: [Priceapi_Product] = []
    for fetchProduct in fetchProducts {
      guard let product = products.first(where: { $0.productId == fetchProduct.productId }) else {
        SKLogger.logError("SKSyncServiceImplementation. Send command for price. Product is nil. FetchProduct = \(fetchProduct.productId)",
                          features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                     SKLoggerFeatureType.retryCount.name: command.retryCount])
        continue
      }
      let priceApiProduct = Priceapi_Product(product: product,
                                             transactionDate: fetchProduct.transactionDate,
                                             transactionId: fetchProduct.transactionId)
      priceApiProducts.append(priceApiProduct)
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
}
