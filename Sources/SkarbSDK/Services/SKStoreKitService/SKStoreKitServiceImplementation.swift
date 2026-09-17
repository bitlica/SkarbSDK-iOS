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

//  MARK: Public

  weak var delegate: SKStoreKitDelegate?
  weak var observer: SKStoreKitObserver?

//  MARK: Private
  private let isObservable: Bool
  private let paymentQueue: SKPaymentQueue
  private var restorePurchasingCompletion: ((Result<Bool, Error>) -> Void)?
  private var purchasingProductCompletions: [String: ((Result<Bool, Error>) -> Void)]

  private let exclusionSerialQueue = DispatchQueue(label: "com.skarbSDK.skStoreKitService.exclusion")

  private var cachedAllProducts: [SKProductInfo]
  var allProducts: [SKProductInfo]? {
    var localAllProducts: [SKProductInfo]? = nil
    exclusionSerialQueue.sync {
      localAllProducts = cachedAllProducts
    }

    return localAllProducts
  }

  private typealias RequestProductCompletion = (Result<[SKProductInfo], Error>) -> Void
  private var requestProductsCompletions: [SKRequest: RequestProductCompletion]

  /// Storefront is read at build time because it can change while the app is running.
  private var commandFactory: SKPurchaseCommandFactory {
    var countryCode: String? = nil
    if #available(iOS 13.0, *) {
      countryCode = SKPaymentQueue.default().storefront?.countryCode
    }
    return SKPurchaseCommandFactory(cachedProducts: allProducts ?? [],
                                    storefrontCountryCode: countryCode)
  }

  init(isObservable: Bool) {
    self.isObservable = isObservable
    self.paymentQueue = SKPaymentQueue.default()
    cachedAllProducts = []
    purchasingProductCompletions = [:]
    requestProductsCompletions = [:]
    super.init()
    self.paymentQueue.add(self)
    SKLogger.logInfo("SKStoreKitService: running on StoreKit 1. isObservable = \(isObservable) (SDK \(isObservable ? "will NOT" : "will") finish transactions)")
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
          self?.commandFactory.createPriceCommand(fetchProducts: fetchProducts,
                                                  products: products,
                                                  command: editedCommand)
        case .failure(let error):
          SKLogger.logInfo("Getting error during fetching products. Error = \(error.localizedDescription)")
      }
    }
  }

  func restorePurchases(completion: @escaping (Result<Bool, Error>) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    SKLogger.logInfo("calling restorePurchases with SKPaymentQueue.restoreCompletedTransactions")
    restorePurchasingCompletion = completion
    paymentQueue.restoreCompletedTransactions()
  }

  func purchasePackage(_ package: SKOfferPackage, completion: @escaping (Result<Bool, Error>) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard let product = fetchProduct(by: package.productId)?.storeProduct ?? package.storeProduct else {
      SKLogger.logError("purchasePackage called but there is no SKProduct for productId = \(package.productId)",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.internalValue.name: package.productId])
      completion(.failure(SKResponseError(errorCode: 0, message: "There is no product for \(package.productId)")))
      return
    }
    SKLogger.logInfo("calling purchaseProduct with productId = \(product.productIdentifier)")
    let payment = SKMutablePayment(product: product)
    SKPaymentQueue.default().add(payment)
    exclusionSerialQueue.sync {
      purchasingProductCompletions[product.productIdentifier] = completion
    }
  }

  /// Might be called on any thread. Callback wil be on the main thread
  func requestProductsInfo(productIds: [String],
                           completion: @escaping (Result<[SKProductInfo], Error>) -> Void) {

    let request = SKProductsRequest(productIdentifiers: Set(productIds))
    request.delegate = self

    exclusionSerialQueue.sync {
      requestProductsCompletions[request] = completion
    }

    SKLogger.logInfo("SKStoreKitService: requesting products \(productIds) via StoreKit 1")
    request.start()
  }

  /// StoreKit 1 has no signed transactions - the app receipt is the only proof it can offer,
  /// and it already travels in `receipt`.
  func collectSignedTransactions(completion: @escaping ([String]) -> Void) {
    completion([])
  }

  func fetchProduct(by productId: String) -> SKProductInfo? {
    return allProducts?.filter({ $0.productId == productId }).first
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
      delegate?.storeKitUpdatedTransaction(transaction)
      let productId = transaction.payment.productIdentifier
      switch transaction.transactionState {
        case .purchased:
          notifyObserver(.purchased, productId: productId)
          purchasedTransactions.append(transaction)
        case .failed:
          failed(transaction)
        case .restored:
          restored(transaction)
        case .deferred:
          notifyObserver(.deferred, productId: productId)
        case .purchasing:
          notifyObserver(.purchasing, productId: productId)
        @unknown default: break
      }
    }

    purchased(purchasedTransactions)
  }

  /// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
  public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    SKLogger.logInfo("paymentQueueRestoreCompletedTransactionsFinished was called")
    DispatchQueue.main.async {
      self.restorePurchasingCompletion?(.success(true))
      self.restorePurchasingCompletion = nil
    }
  }

  /// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
  public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
    SKLogger.logInfo(String(format: "paymentQueueRestoreCompletedTransactionsFailedWithError was called with error %@", error.localizedDescription))
    DispatchQueue.main.async {
      self.restorePurchasingCompletion?(.failure(error))
      self.restorePurchasingCompletion = nil
    }
  }

  public func paymentQueue(_ queue: SKPaymentQueue,
                           shouldAddStorePayment payment: SKPayment,
                           for product: SKProduct) -> Bool {
    if let delegate = delegate {
      return delegate.storeKit(shouldAddStorePayment: payment, for: product)
    }
    return observer?.skarbShouldAddStorePayment(productId: product.productIdentifier) ?? false
  }
}

extension SKStoreKitServiceImplementation: SKProductsRequestDelegate {

  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {

    exclusionSerialQueue.sync {
      for product in response.products {
        if cachedAllProducts.filter({ $0.productId == product.productIdentifier }).first == nil {
          cachedAllProducts.append(SKProductInfo(skProduct: product))
        }
      }
    }
    SKLogger.logInfo("SKRequestDelegate fetched products successful. Received \(response.products.count), invalid = \(response.invalidProductIdentifiers)")

    var completion: RequestProductCompletion? = nil
    exclusionSerialQueue.sync {
      completion = self.requestProductsCompletions[request]
      self.requestProductsCompletions.removeValue(forKey: request)
    }

    DispatchQueue.main.async {
      completion?(.success(self.allProducts ?? []))
    }
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {

    SKLogger.logInfo("SKRequestDelegate got called with didFailWithError: \(error)")

    var completion: RequestProductCompletion? = nil
    exclusionSerialQueue.sync {
      completion = self.requestProductsCompletions[request]
      self.requestProductsCompletions.removeValue(forKey: request)
    }

    DispatchQueue.main.async {
      completion?(.failure(error))
    }
  }
}

//MARK: Private
private extension SKStoreKitServiceImplementation {

  private func purchased(_ transactions: [SKPaymentTransaction]) {

    guard !transactions.isEmpty else {
      return
    }

    // Sends success callback if purchasing was initiated by SkarbSDK.purchaseProduct(...) method
    for transaction in transactions {
      var purchaseCompletion: ((Result<Bool, Error>) -> Void)? = nil
      let productIdentifier = transaction.payment.productIdentifier
      exclusionSerialQueue.sync {
        purchaseCompletion = purchasingProductCompletions[productIdentifier]
        purchasingProductCompletions.removeValue(forKey: productIdentifier)
      }

      DispatchQueue.main.async {
        purchaseCompletion?(.success(true))
      }
    }

    for transaction in transactions {
      SKLogger.logInfo("paymentQueue updatedTransactions: called. TransactionState is purchased. ProductIdentifier = \(transaction.payment.productIdentifier), transactionDate = \(String(describing: transaction.transactionDate))")
    }

    let purchasedEvents = transactions.map { SKPurchaseEvent(skTransaction: $0) }
    let factory = commandFactory
    factory.createFetchProductsCommand(purchasedEvents: purchasedEvents)
    factory.createPurchaseAndTransactionCommand(purchasedEvents: purchasedEvents)

    if !isObservable {
      transactions.forEach { paymentQueue.finishTransaction($0) }
    } else {
      transactions.forEach { handOverForFinishing($0) }
    }
  }

  private func restored(_ transaction: SKPaymentTransaction) {
    if !isObservable {
      SKPaymentQueue.default().finishTransaction(transaction)
    } else {
      handOverForFinishing(transaction)
    }
  }

  private func failed(_ transaction: SKPaymentTransaction) {
    if !isObservable {
      SKPaymentQueue.default().finishTransaction(transaction)
    } else {
      handOverForFinishing(transaction)
    }

    var purchaseCompletion: ((Result<Bool, Error>) -> Void)? = nil
    let productIdentifier = transaction.payment.productIdentifier
    exclusionSerialQueue.sync {
      purchaseCompletion = purchasingProductCompletions[productIdentifier]
      purchasingProductCompletions.removeValue(forKey: productIdentifier)
    }

    guard let error = transaction.error as? SKError else {
      if let error = transaction.error {
        notifyObserver(.failed(error), productId: productIdentifier)
        DispatchQueue.main.async {
          purchaseCompletion?(.failure(error))
        }
      } else {
        let error = SKResponseError(errorCode: 0, message: "Purchasing failed")
        notifyObserver(.failed(error), productId: productIdentifier)
        DispatchQueue.main.async {
          purchaseCompletion?(.failure(error))
        }
      }
      return
    }

    notifyObserver(.failed(error), productId: productIdentifier)
    DispatchQueue.main.async {
      purchaseCompletion?(.failure(error))
    }
  }

  /// The StoreKit 1 payment queue does not promise a thread, so observer callbacks are
  /// dispatched to main - matching the StoreKit 2 path and letting host apps touch UI directly.
  private func notifyObserver(_ state: SKPurchaseState, productId: String) {
    DispatchQueue.main.async { [weak self] in
      self?.observer?.skarbPurchaseStateDidChange(state, productId: productId)
    }
  }

  /// `isObservable == true` means the host app owns finishing.
  private func handOverForFinishing(_ transaction: SKPaymentTransaction) {
    let productId = transaction.payment.productIdentifier
    guard let observer = observer else {
      SKLogger.logInfo("SKStoreKitService: isObservable == true and no observer is set, so transaction for \(productId) stays unfinished. The host app must finish it.")
      return
    }
    let handle = SKTransactionHandle(productId: productId, finishAction: { [weak self] in
      self?.paymentQueue.finishTransaction(transaction)
    })
    DispatchQueue.main.async {
      observer.skarbTransactionNeedsFinish(handle)
    }
  }
}
