//
//  SKStoreKitServiceImplementation.swift
//  ios
//
//  Created by Bitlica Inc. on 2/20/20.
//  Copyright © 2020 Ihnat Kandrashou. All rights reserved.
//

import Foundation
import StoreKit

class SKStoreKitServiceImplementation: NSObject, SKStoreKitService {
  
  private let isObservable: Bool
  private let paymentQueue: SKPaymentQueue
  private var productInfoCompletion: (([SKProduct]) -> Void)?
  
  private let exclusionSerialQueue = DispatchQueue(label: "com.skarbSDK.skStoreKitService.exclusion")
  
  private var cachedAllProducts: [SKProduct]
  var allProducts: [SKProduct]? {
    var localAllProducts: [SKProduct]? = nil
    exclusionSerialQueue.sync {
      localAllProducts = cachedAllProducts
    }
    
    return localAllProducts
  }
  
  init(isObservable: Bool) {
    self.isObservable = isObservable
    self.paymentQueue = SKPaymentQueue.default()
    cachedAllProducts = []
    super.init()
    self.paymentQueue.add(self)
  }
  
  func requestProductInfoAndSendPurchase(command: SKCommand) {
    var editedCommand = command
    let decoder = JSONDecoder()
    
    guard let fetchProducts = try? decoder.decode(Array<SKFetchProduct>.self, from: command.data) else {
      SKLogger.logError("SKSyncServiceImplementation requestProductInfoAndSendPurchase: called with fetchProducts but command.data is not SKFetchProduct. Command.data == \(String(describing: String(data: command.data, encoding: .utf8)))", features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
      editedCommand.changeStatus(to: .canceled)
      SKServiceRegistry.commandStore.saveCommand(editedCommand)
      return
    }
    
    requestProductInfo(productIds: fetchProducts.map({ $0.productId })) { [weak self] products in
      if let product = products.first {
        SkarbSDK.sendPurchase(productId: product.productIdentifier,
                              price: product.price.floatValue,
                              currency: product.priceLocale.currencyCode ?? "")
        editedCommand.changeStatus(to: .done)
      } else {
        editedCommand.updateRetryCountAndFireDate()
        editedCommand.changeStatus(to: .pending)
      }
      SKServiceRegistry.commandStore.saveCommand(editedCommand)
      
      // V4. Send command for price
      self?.createPriceCommand(fetchProducts: fetchProducts,
                               products: products,
                               command: editedCommand)
    }
  }
}

extension SKStoreKitServiceImplementation: SKPaymentTransactionObserver {
  
  
  /// Sent when the transaction array has changed (additions or state changes).  Client should check state of transactions and finish as appropriate.
  public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    
    DispatchQueue.main.async { [weak self] in
      
      guard let self = self,
            self.isObservable else {
        return
      }
      
      let purchasedTransactions = transactions.filter { $0.transactionState == .purchased }
      
      for transaction in purchasedTransactions {
        SKLogger.logInfo("paymentQueue updatedTransactions: called. TransactionState is purchased. ProductIdentifier = \(transaction.payment.productIdentifier), transactionDate = \(String(describing: transaction.transactionDate))")
      }
      
      self.sendPurchase(purchasedTransactions: purchasedTransactions)
      self.createFetchProductsCommand(purchasedTransactions: purchasedTransactions)
      // V4 part
      self.createPurchaseAndTransactionCommand(purchasedTransactions: purchasedTransactions)
    }
  }
  
  /// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
  public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    SKLogger.logInfo("paymentQueueRestoreCompletedTransactionsFinished was called")
  }
  
  /// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
  public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
    SKLogger.logInfo(String(format: "paymentQueueRestoreCompletedTransactionsFailedWithError was called with error %@", error.localizedDescription))
  }
}

extension SKStoreKitServiceImplementation: SKProductsRequestDelegate {
  
  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    
    exclusionSerialQueue.sync {
      for product in response.products {
        if !cachedAllProducts.contains(product) {
          cachedAllProducts.append(product)
        }
      }
    }
    SKLogger.logInfo("SKRequestDelegate fetched products successful")
    
    productInfoCompletion?(allProducts ?? [])
  }
  
  func request(_ request: SKRequest, didFailWithError error: Error) {
    
    SKLogger.logInfo("SKRequestDelegate got called with didFailWithError: \(error)")
    
    productInfoCompletion?([])
  }
}

private extension SKStoreKitServiceImplementation {
  func requestProductInfo(productIds: [String], completion: @escaping ([SKProduct]) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    
    productInfoCompletion = completion
    
    let request = SKProductsRequest(productIdentifiers: Set(productIds))
    request.delegate = self
    
    request.start()
  }
  
  ///V3
  func sendPurchase(purchasedTransactions: [SKPaymentTransaction]) {
    if let allProducts = self.allProducts,
       let purchasedTransaction = purchasedTransactions.first,
       let product = allProducts.filter({ $0.productIdentifier == purchasedTransaction.payment.productIdentifier }).first {
      SkarbSDK.sendPurchase(productId: purchasedTransaction.payment.productIdentifier,
                            price: product.price.floatValue,
                            currency: product.priceLocale.currencyCode ?? "")
    }
  }
  
  /// V3 and V4. Create one SKFetchProduct or each unique productId
  /// Need to attach the newest transaction Date and Id
  func createFetchProductsCommand(purchasedTransactions: [SKPaymentTransaction]) {
    guard purchasedTransactions.isEmpty else {
      return
    }
    
    let productIds = Array(Set(purchasedTransactions.map { $0.payment.productIdentifier }))
    var fetchProducts: [SKFetchProduct] = []
    for productId in productIds {
      let transaction = purchasedTransactions
        .filter { $0.payment.productIdentifier == productId }
        .sorted { $0.transactionDate ?? Date() < $1.transactionDate ?? Date() }.last
      if let transaction = transaction {
        fetchProducts.append(SKFetchProduct(productId: transaction.payment.productIdentifier,
                                            transactionDate: transaction.transactionDate,
                                            transactionId: transaction.transactionIdentifier))
      }
    }
    let encoder = JSONEncoder()
    if let productData = try? encoder.encode(fetchProducts) {
      let fetchCommand = SKCommand(commandType: .fetchProducts,
                                   status: .pending,
                                   data: productData)
      SKServiceRegistry.commandStore.saveCommand(fetchCommand)
    } else {
      SKLogger.logError("paymentQueue updatedTransactions: called. Need to fetch products but purchasedProductId.data(using: .utf8) == nil",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.internalValue.name: fetchProducts.description])
    }
  }
  
  func createPurchaseAndTransactionCommand(purchasedTransactions: [SKPaymentTransaction]) {
    guard !purchasedTransactions.isEmpty else {
      return
    }
    let transactionIds: [String] = purchasedTransactions.compactMap { $0.transactionIdentifier }
    if !SKServiceRegistry.commandStore.hasPurhcaseV4Command {
      var countryCode: String? = nil
      if #available(iOS 13.0, *) {
        countryCode = SKPaymentQueue.default().storefront?.countryCode
      }
      let installData = SKServiceRegistry.commandStore.getDeviceRequest()
      let purchaseDataV4 = Purchaseapi_ReceiptRequest(storefront: countryCode,
                                                      region: self.allProducts?.first?.priceLocale.regionCode,
                                                      currency: self.allProducts?.first?.priceLocale.currencyCode,
                                                      newTransactions: transactionIds,
                                                      docFolderDate: installData?.docDate,
                                                      appBuildDate: installData?.buildDate)
      let purchaseV4Command = SKCommand(commandType: .purchaseV4,
                                        status: .pending,
                                        data: purchaseDataV4.getData())
      SKServiceRegistry.commandStore.saveCommand(purchaseV4Command)
    }
    
    // Always sends transactions even in case if it was the first purchase
    // and transactions are included into purchase command
    let newTransactions = SKServiceRegistry.commandStore.getNewTransactionIds(transactionIds)
    if !newTransactions.isEmpty {
      let installData = SKServiceRegistry.commandStore.getDeviceRequest()
      let transactionDataV4 = Purchaseapi_TransactionsRequest(newTransactions: newTransactions,
                                                              docFolderDate: installData?.docDate,
                                                              appBuildDate: installData?.buildDate)
      let transactionV4Command = SKCommand(commandType: .transactionV4,
                                           status: .pending,
                                           data: transactionDataV4.getData())
      SKServiceRegistry.commandStore.saveCommand(transactionV4Command)
    }
  }
  
  func createPriceCommand(fetchProducts: [SKFetchProduct],
                          products: [SKProduct],
                          command: SKCommand) {
    var priceApiProducts: [Priceapi_Product] = []
    for fetchProduct in fetchProducts {
      guard let product = products.first(where: { $0.productIdentifier == fetchProduct.productId }) else {
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
    
    var countryCode: String? = nil
    if #available(iOS 13.0, *) {
      countryCode = SKPaymentQueue.default().storefront?.countryCode
    }
    let productRequest = Priceapi_PricesRequest(storefront: countryCode,
                                                region: products.first?.priceLocale.regionCode,
                                                currency: products.first?.priceLocale.currencyCode,
                                                products: priceApiProducts)
    let command = SKCommand(commandType: .priceV4,
                            status: .pending,
                            data: productRequest.getData())
    SKServiceRegistry.commandStore.saveCommand(command)
  }
}
