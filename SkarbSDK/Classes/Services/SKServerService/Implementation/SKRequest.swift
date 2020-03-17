//
//  SKRequest.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

enum SKRequestType: String {
  case install = "sk_request_type_install"
  case test = "sk_request_type_test"
  case broker = "sk_request_type_broker"
  case purchase = "sk_request_type_purchase"
}

//This is a class, to use reference semantic, to enable remainingRetryCount updates
public class SKRequest {

  let request: URLRequest
  let requestType: SKRequestType
  let params: [String: Any]
  let parsingHandler: (Result<[String: Any], SKResponseError>) -> Void

  private(set) var remainingRetryCount: Int

  init(request: URLRequest,
       requestType: SKRequestType,
       params: [String: Any],
       retryCount: Int = SKServerAPIImplementaton.maxNumberOfRequestRetries,
       parsingHandler: @escaping (Result<[String: Any], SKResponseError>) -> Void) {

    self.request = request
    self.requestType = requestType
    self.params = params
    self.remainingRetryCount = retryCount
    self.parsingHandler = parsingHandler
  }

  public func decrementRemainingRetryCount() {
    remainingRetryCount -= 1
  }
}
