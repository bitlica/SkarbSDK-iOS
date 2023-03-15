//
//  VerifyReceipt.swift
//  SkarbSDK
//
//  Created by Artem Hitrik on 16.09.22.
//

import Foundation
import SwiftProtobuf


public struct SKUserPurchaseInfo {
  public var environment: String
  public var purchasedSubscriptions: [SKPurchasedSubscription] = []
  public var onetimePurchases: [SKOnetimePurchase] = []
  
  init(verifyReceiptResponse: Purchaseapi_VerifyReceiptResponse) {
    environment = verifyReceiptResponse.environment
    purchasedSubscriptions = verifyReceiptResponse.activeSubscriptions.map({ SKPurchasedSubscription(activeSubscription: $0) })
    onetimePurchases = verifyReceiptResponse.onetimes.map({ SKOnetimePurchase(onetimePurchase: $0) })
  }
  
  public var isActiveSubscription: Bool {
    return !purchasedSubscriptions.filter { $0.isActive }.isEmpty
  }
  public var isAnyOnetimePurchased: Bool {
    return !onetimePurchases.isEmpty
  }
  /// User has any valid subscription or any non subscription product was purchased
  public var isActive: Bool {
    return isActiveSubscription || isAnyOnetimePurchased
  }
  
  public func fetchActiveSubscription(by productId: String) -> SKPurchasedSubscription? {
    return purchasedSubscriptions.first { $0.productID == productId }
  }
}


public struct SKPurchasedSubscription {
  public let transactionID: String
  public let originalTransactionID: String
  public let expiryDate: Date
  public let productID: String
  public let quantity: Int32
  public let introOfferPeriod: Bool
  public let trialPeriod: Bool
  public let renewalInfo: String
  
  init(activeSubscription: Purchaseapi_ActiveSubscription) {
    transactionID = activeSubscription.transactionID
    originalTransactionID = activeSubscription.originalTransactionID
    expiryDate = activeSubscription.expiryDate.date
    productID = activeSubscription.productID
    quantity = activeSubscription.quantity
    introOfferPeriod = activeSubscription.introOfferPeriod
    trialPeriod = activeSubscription.trialPeriod
    renewalInfo = activeSubscription.renewalInfo
  }
  
  public var isActive: Bool {
    return expiryDate >= Date()
  }
  
  public var willRenew: Bool {
    return renewalInfo == "active"
  }
  
  public var isExpired: Bool {
    return renewalInfo == "expired"
  }
  
  public var isInBillingRetry: Bool {
    return renewalInfo == "billing_retry"
  }
  
  public var isInGracePeriod: Bool {
    return renewalInfo == "grace_period"
  }
  
  public var isTrial: Bool {
    return trialPeriod
  }
  
  public var willCancel: Bool {
    return renewalInfo == "will_cancel"
  }
  
  public var isRefunded: Bool {
    return renewalInfo == "refunded"
  }
}


public struct SKOnetimePurchase {
  public let transactionID: String
  public let purchaseDate: Date
  public let productID: String
  public let quantity: Int32
  
  init(onetimePurchase: Purchaseapi_OnetimePurchase) {
    transactionID = onetimePurchase.transactionID
    purchaseDate = onetimePurchase.purchaseDate.date
    productID = onetimePurchase.productID
    quantity = onetimePurchase.quantity
  }
}
