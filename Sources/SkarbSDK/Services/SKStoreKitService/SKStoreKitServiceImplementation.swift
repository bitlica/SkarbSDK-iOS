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
  private var productInfoCompletion: ((Result<[SKProduct], Error>) -> Void)?
  private var restorePurchasingCompletion: ((Result<Bool, Error>) -> Void)?
  private var purchasingProductCompletion: ((Result<Bool, Error>) -> Void)?
  
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
    
    requestProductInfo(productIds: fetchProducts.map({ $0.productId })) { [weak self] result in
      switch result {
        case .success(let products):
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
        case .failure(let error):
          SKLogger.logInfo("Getting error during fetching products. Error = \(error.localizedDescription)")
      }
    }
  }
  
  func restorePurchases(compltion: @escaping (Result<Bool, Error>) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    SKLogger.logInfo("calling restorePurchases with SKPaymentQueue.restoreCompletedTransactions")
    restorePurchasingCompletion = compltion
    paymentQueue.restoreCompletedTransactions()
  }
  
  func purchaseProduct(_ product: SKProduct, completion: @escaping (Result<Bool, Error>) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    SKLogger.logInfo("calling purchaseProduct with productId = \(product.productIdentifier)")
    let payment = SKMutablePayment(product: product)
    SKPaymentQueue.default().add(payment)
    purchasingProductCompletion = completion
  }
  
  func purchasePackage(_ package: SKOfferPackage, completion: @escaping (Result<Bool, Error>) -> Void) {
    guard let product = allProducts?.first(where: { $0.productIdentifier == package.products.first }) else {
      requestProductInfo(productIds: package.products, completion: { [weak self] result in
        switch result {
          case .success(let products):
            guard let product = products.first(where: { $0.productIdentifier == package.products.first }) else {
              completion(.failure(SKResponseError(errorCode: 0, message: "Can't find productID in pacjage in [SKProducts] from App Store")))
              return
            }
            self?.purchaseProduct(product, completion: completion)
          case .failure(let error):
            completion(.failure(error))
        }
      })
      return
    }
    
    purchaseProduct(product, completion: completion)
  }
  
  var canMakePayments: Bool {
    return SKPaymentQueue.canMakePayments()
  }
}

//MARK: SKPaymentTransactionObserver
extension SKStoreKitServiceImplementation: SKPaymentTransactionObserver {
  
  
  /// Sent when the transaction array has changed (additions or state changes).  Client should check state of transactions and finish as appropriate.
  public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    var purchasedTransactions: [SKPaymentTransaction] = []
    
    transactions.forEach { transaction in
      switch transaction.transactionState {
        case .purchased:
          purchasedTransactions.append(transaction)
        case .failed:
          failed(transaction)
        case .restored:
          restored(transaction)
        case .deferred, .purchasing: break
        @unknown default: break
      }
    }
    
    purchased(purchasedTransactions)
  }
  
  /// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
  public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    SKLogger.logInfo("paymentQueueRestoreCompletedTransactionsFinished was called")
    restorePurchasingCompletion?(.success(true))
    restorePurchasingCompletion = nil
  }
  
  /// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
  public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
    SKLogger.logInfo(String(format: "paymentQueueRestoreCompletedTransactionsFailedWithError was called with error %@", error.localizedDescription))
    restorePurchasingCompletion?(.failure(error))
    restorePurchasingCompletion = nil
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
    
    DispatchQueue.main.async {
      self.productInfoCompletion?(.success(self.allProducts ?? []))
    }
  }
  
  func request(_ request: SKRequest, didFailWithError error: Error) {
    
    SKLogger.logInfo("SKRequestDelegate got called with didFailWithError: \(error)")
    
    DispatchQueue.main.async {
      self.productInfoCompletion?(.success(self.allProducts ?? []))
    }
  }
}

//MARK: Private
private extension SKStoreKitServiceImplementation {
  
  /// Mignt be called on any thread. Callback wil be on the main thread
  func requestProductInfo(productIds: [String], completion: @escaping (Result<[SKProduct], Error>) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    
    productInfoCompletion = completion
    
    let request = SKProductsRequest(productIdentifiers: Set(productIds))
    request.delegate = self
    
    request.start()
  }
  
  private func purchased(_ transactions: [SKPaymentTransaction]) {

    guard !transactions.isEmpty else {
      return
    }
    
    // Sends success callback if purchasing was initiated by SkarbSDK.purchaseProduct(...) method
    self.purchasingProductCompletion?(.success(true))
    
    for transaction in transactions {
      SKLogger.logInfo("paymentQueue updatedTransactions: called. TransactionState is purchased. ProductIdentifier = \(transaction.payment.productIdentifier), transactionDate = \(String(describing: transaction.transactionDate))")
    }
    
    self.sendPurchase(purchasedTransactions: transactions)
    self.createFetchProductsCommand(purchasedTransactions: transactions)
    // V4 part
    self.createPurchaseAndTransactionCommand(purchasedTransactions: transactions)
    
    if !isObservable {
      transactions.forEach { paymentQueue.finishTransaction($0) }
    }
  }
  
  private func restored(_ transaction: SKPaymentTransaction) {
    if !isObservable {
      SKPaymentQueue.default().finishTransaction(transaction)
    }
  }
  
  private func failed(_ transaction: SKPaymentTransaction) {
    if !isObservable {
      SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    guard let error = transaction.error as? SKError else {
      if let error = transaction.error {
        purchasingProductCompletion?(.failure(error))
      } else {
        purchasingProductCompletion?(.failure(SKResponseError(errorCode: 0, message: "Purchasing failed")))
      }
      return
    }
    
    purchasingProductCompletion?(.failure(error))
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
