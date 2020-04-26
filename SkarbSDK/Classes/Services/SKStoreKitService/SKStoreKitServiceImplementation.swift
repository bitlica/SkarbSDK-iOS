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
    guard let productId = String(data: command.data, encoding: .utf8) else {
      SKLogger.logError("SKSyncServiceImplementation requestProductInfoAndSendPurchase: called with fetchProducts but command.data is not String. Command.data == \(String(describing: String(data: command.data, encoding: .utf8)))", features: [SKLoggerFeatureType.internalError: SKLoggerFeatureType.internalError])
      editedCommand.changeStatus(to: .canceled)
      SKServiceRegistry.commandStore.saveCommand(command)
      return
    }
    
    requestProductInfo(productId: productId) { products in
      if let product = products.filter({ $0.productIdentifier == productId }).first {
        guard !SKServiceRegistry.commandStore.hasPurhcaseCommand else {
          return
        }
        SkarbSDK.sendPurchase(productId: productId,
                              price: product.price.floatValue,
                              currency: product.priceLocale.currencyCode ?? "")
      } else {
        editedCommand.incrementRetryCount()
        editedCommand.changeStatus(to: .pending)
        SKServiceRegistry.commandStore.saveCommand(command)
      }
    }
  }
}

extension SKStoreKitServiceImplementation: SKPaymentTransactionObserver {
  
  
  /// Sent when the transaction array has changed (additions or state changes).  Client should check state of transactions and finish as appropriate.
  public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    
    for transaction in transactions.reversed() {
      
      switch transaction.transactionState {
        case .purchased:
          SKLogger.logInfo("paymentQueue updatedTransactions: called. TransactionState is purchased. ProductIdentifier = \(transaction.payment.productIdentifier), transactionDate = \(String(describing: transaction.transactionDate))")
          DispatchQueue.main.async { [weak self] in
            
            guard let self = self,
              self.isObservable,
              !SKServiceRegistry.commandStore.hasPurhcaseCommand else {
                return
            }
            
            let purchasedProductId = transaction.payment.productIdentifier
            if let allProducts = self.allProducts,
              let product = allProducts.filter({ $0.productIdentifier == purchasedProductId }).first {
              SkarbSDK.sendPurchase(productId: purchasedProductId,
                                    price: product.price.floatValue,
                                    currency: product.priceLocale.currencyCode ?? "")
            } else {
              guard let productData = purchasedProductId.data(using: .utf8) else {
                SKLogger.logError("paymentQueue updatedTransactions: called. Need to fetch products but purchasedProductId.data(using: .utf8) == nil",
                                  features: [SKLoggerFeatureType.internalError: SKLoggerFeatureType.internalError])
                return
              }
              let fetchCommand = SKCommand(timestamp: Date().nowTimestampInt,
                                           commandType: .fetchProducts,
                                           status: .pending,
                                           data: productData,
                                           retryCount: 0)
              SKServiceRegistry.commandStore.saveCommand(fetchCommand)
            }
        }
        case .failed:
          SKLogger.logInfo("updatedTransactions: called. Transaction was failed. Date = \(String(describing: transaction.transactionDate))")
        case .restored:
          SKLogger.logInfo("updatedTransactions: called. Transaction was restored. Date = \(String(describing: transaction.transactionDate))")
        default:
          break
      }
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
    
    productInfoCompletion?(response.products)
  }
  
  func request(_ request: SKRequest, didFailWithError error: Error) {
    
    SKLogger.logInfo("SKRequestDelegate got called with didFailWithError: \(error)")
    
    productInfoCompletion?([])
  }
}

private extension SKStoreKitServiceImplementation {
  func requestProductInfo(productId: String, completion: @escaping ([SKProduct]) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    
    productInfoCompletion = completion
    
    let request = SKProductsRequest(productIdentifiers: Set([productId]))
    request.delegate = self
    
    request.start()
  }
}
