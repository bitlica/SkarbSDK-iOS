//
//  SKStoreKitServiceImplementation.swift
//  ios
//
//  Created by Artem Hitrik on 2/20/20.
//  Copyright © 2020 Ihnat Kandrashou. All rights reserved.
//

import Foundation
import StoreKit

enum SKStoreKitSyncType: String {
  case fetchProducts = "sk_sync_service_type_fetchProducts"
}

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
  
  func requestProductInfoAndSendPurchase(productId: String) {
    requestProductInfo(productId: productId) { products in
      if let product = products.filter({ $0.productIdentifier == productId }).first {
        SKServiceRegistry.userDefaultsService.removeValue(forKey: .fetchAllProductsAndSync)
        SkarbSDK.sendPurchase(productId: productId,
                              price: product.price.floatValue,
                              currency: product.priceLocale.currencyCode)
      } else {
        SKServiceRegistry.userDefaultsService.setValue(productId, forKey: .fetchAllProductsAndSync)
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
          SKPaymentQueue.default().finishTransaction(transaction)
          SKSyncLog.logError("updatedTransactions was called. Transaction was failed. Date = \(String(describing: transaction.transactionDate))")
          DispatchQueue.main.async { [weak self] in
            
            guard let self = self,
                self.isObservable,
                !SKServiceRegistry.userDefaultsService.bool(forKey: .purchaseSentBySwizzling) else {
                return
              }
              SKServiceRegistry.userDefaultsService.setValue(true, forKey: .purchaseSentBySwizzling)
              
              let purchasedProductId = transaction.payment.productIdentifier
              SkarbSDK.sendPurchase(productId: purchasedProductId)
            if let allProducts = self.allProducts,
                let product = allProducts.filter({ $0.productIdentifier == purchasedProductId }).first {
                SkarbSDK.sendPurchase(productId: purchasedProductId,
                                      price: product.price.floatValue,
                                      currency: product.priceLocale.currencyCode)
              } else {
              self.requestProductInfoAndSendPurchase(productId: purchasedProductId)
            }
          }
        case .failed:
          SKPaymentQueue.default().finishTransaction(transaction)
          SKSyncLog.logError("updatedTransactions was called. Transaction was failed. Date = \(String(describing: transaction.transactionDate))")
        case .restored:
          SKPaymentQueue.default().finishTransaction(transaction)
          SKSyncLog.logInfo("updatedTransactions was called. Transaction was restored. Date = \(String(describing: transaction.transactionDate))")
        default:
          break
      }
    }
  }
  
  /// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
  public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    SKSyncLog.logInfo("paymentQueueRestoreCompletedTransactionsFinished was called")
  }
  
  /// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
  public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
    SKSyncLog.logError(String(format: "paymentQueueRestoreCompletedTransactionsFailedWithError was called with error %@", error.localizedDescription))
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
    SKSyncLog.logInfo("SKRequestDelegate fetched products successful")
    
    productInfoCompletion?(response.products)
  }
  
  func request(_ request: SKRequest, didFailWithError error: Error) {
    
    SyncLog.logError("SKRequestDelegate got called with didFailWithError: \(error)")
    
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
