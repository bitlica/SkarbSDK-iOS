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

  public static let noResponseCode = 9999
  static let genericRetryMessage = "General response error"

  init(errorCode: Int,
       message: String = SKResponseError.genericRetryMessage) {
    self.errorCode = errorCode
    self.message = message
  }
}
