//
//  SKResponseError.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

public struct SKResponseError: Error {
  
  var isInternetCode: Bool {
    return errorCode == -1009 ||
      errorCode == -1005 ||
      errorCode == -1004 ||
      errorCode == -1003 ||
      errorCode == -1001
  }
  
  let errorCode: Int
  let message: String
  let headerFields: [AnyHashable: Any]?
  let body: [AnyHashable: Any]?

  public static let noResponseCode = 9999
  static let genericRetryMessage = "General response error"

  init(errorCode: Int,
       message: String = SKResponseError.genericRetryMessage,
       headerFields: [AnyHashable: Any]?,
       body: [AnyHashable: Any]?) {
    self.errorCode = errorCode
    self.message = message
    self.headerFields = headerFields
    self.body = body
  }

  init(serverStatusCode: Int,
       message: String?,
       headerFields: [AnyHashable: Any]?,
       body: [AnyHashable: Any]?) {
    errorCode = serverStatusCode
    switch serverStatusCode {
      case -1009, -1003, -1001:
        self.message = "No internet connection, unable to upload events"
      case 400..<501:
        self.message = message ?? SKResponseError.genericRetryMessage
      default:
        self.message = message ?? SKResponseError.genericRetryMessage
    }
    self.headerFields = headerFields
    self.body = body
  }
}
