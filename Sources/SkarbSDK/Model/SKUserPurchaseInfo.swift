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
  public var activeSubscriptions: [SKActiveSubscription] = []
  public var nonSubscriptions: [SKNonSubscription] = []
  
  init(verifyReceiptResponse: Purchaseapi_VerifyReceiptResponse) {
    self.environment = verifyReceiptResponse.environment
    self.activeSubscriptions = verifyReceiptResponse.activeSubscriptions.map({ SKActiveSubscription(activeSubscription: $0) })
  }
  
  public var isActiveSubscription: Bool {
    return !activeSubscriptions.filter { $0.expiryDate >= Date() }.isEmpty
  }
  public var isActiveAnyNonSubscription: Bool {
    return !nonSubscriptions.isEmpty
  }
  /// User has any valid subscription or any non subscription product was purchased
  public var isActive: Bool {
    return isActiveSubscription || isActiveAnyNonSubscription
  }
}


public struct SKActiveSubscription {
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
  
  public var willRenew: Bool {
    return renewalInfo == "active"
  }
  
  public var isCancelled: Bool {
    return renewalInfo == "cancelled"
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
}


public struct SKNonSubscription {
  public let transactionID: String
  public let originalTransactionID: String
  public let purchaseDate: Date
  public let productID: String
  public let quantity: Int32
  
  init(nonSubscription: Purchaseapi_NonSubscription) {
    transactionID = nonSubscription.transactionID
    originalTransactionID = nonSubscription.originalTransactionID
    purchaseDate = nonSubscription.purchaseDate.date
    productID = nonSubscription.productID
    quantity = nonSubscription.quantity
  }
}
