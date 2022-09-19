//
//  VerifyReceipt.swift
//  SkarbSDK
//
//  Created by Artem Hitrik on 16.09.22.
//

import Foundation
import SwiftProtobuf

public struct SKVerifyReceipt {
  var environment: String
  var activeSubscriptions: [SKActiveSubscription] = []
  var nonSubscriptions: [NonSubscription] = []
  
  init(verifyReceiptResponse: Purchaseapi_VerifyReceiptResponse) {
    self.environment = verifyReceiptResponse.environment
    self.activeSubscriptions = verifyReceiptResponse.activeSubscriptions.map({ SKActiveSubscription(activeSubscription: $0) })
  }
}

public struct SKActiveSubscription {
  let transactionID: String
  let originalTransactionID: String
  let expiryDate: Date
  let productID: String
  let quantity: Int32
  let introOfferPeriod: Bool
  let trialPeriod: Bool
  let renewalInfo: String
  
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
}

public struct NonSubscription {
  let transactionID: String
  let originalTransactionID: String
  let purchaseDate: Date
  let productID: String
  let quantity: Int32
  
  init(nonSubscription: Purchaseapi_NonSubscription) {
    transactionID = nonSubscription.transactionID
    originalTransactionID = nonSubscription.originalTransactionID
    purchaseDate = nonSubscription.purchaseDate.date
    productID = nonSubscription.productID
    quantity = nonSubscription.quantity
  }
}
