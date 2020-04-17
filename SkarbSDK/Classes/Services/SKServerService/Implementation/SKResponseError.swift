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
      errorCode == -1003 ||
      errorCode == -1001
  }
  
  let errorCode: Int
  let message: String

  public static let noResponseCode = 9999
  static let genericRetryMessage = "General response error"

  init(errorCode: Int, message: String = SKResponseError.genericRetryMessage) {
    self.errorCode = errorCode
    self.message = message
  }

  init(serverStatusCode: Int, message: String?) {
    errorCode = serverStatusCode
    switch serverStatusCode {
      case -1009, -1003, -1001:
        self.message = "No internet connection, unable to upload events"
      case 400..<501:
        self.message = message ?? SKResponseError.genericRetryMessage
      default:
        self.message = message ?? SKResponseError.genericRetryMessage
    }
  }
}
