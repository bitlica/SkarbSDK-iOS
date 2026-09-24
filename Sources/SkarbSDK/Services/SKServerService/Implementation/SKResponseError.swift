//
//  SKResponseError.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

public extension Error {
    var code: Int { return (self as NSError).code }
    var domain: String { return (self as NSError).domain }
}

public struct SKResponseError: Error {
  
  var isInternetCode: Bool {
    return errorCode == -1009 ||
      errorCode == -1005 ||
      errorCode == -1004 ||
      errorCode == -1003 ||
      errorCode == -1001
  }
  
  let errorCode: Int
  public let message: String

  /// The purchase was not refused: it is waiting for approval (Ask-to-Buy, SCA) and can still
  /// arrive later through StoreKit. Counting it as a failure inflates the failure rate by the
  /// whole Ask-to-Buy volume - StoreKit 1 never completed the purchase call at all in this case.
  public var isPurchasePendingApproval: Bool {
    return errorCode == SKResponseError.purchasePendingApprovalCode
  }

  public static let noResponseCode = 9999
  /// Ask-to-Buy / SCA. `purchasePackage` answers with this rather than leaving the caller
  /// waiting, but it is NOT a refusal - see `isPurchasePendingApproval`.
  public static let purchasePendingApprovalCode = 35
  static let genericRetryMessage = "General response error"

  init(errorCode: Int,
       message: String = SKResponseError.genericRetryMessage) {
    self.errorCode = errorCode
    self.message = message
  }
}
