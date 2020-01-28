//
//  SKRequest.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 1/19/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

enum SKRequestType: String {
  case install
  case test
  case source
  case purchase
  
  var storingName: String {
    switch self {
      case .install:
        return "sk_request_type_install"
      case .test:
        return "sk_request_type_test"
      case .source:
        return "sk_request_type_source"
      case .purchase:
        return "sk_request_type_purchase"
    }
  }
}

//This is a class, to use reference semantic, to enable remainingRetryCount updates
public class SKRequest {

  let request: URLRequest
  let requestType: SKRequestType
  let params: JSONObject
  let parsingHandler: (Result<JSONObject, SKResponseError>) -> Void

  private(set) var remainingRetryCount: Int

  init(request: URLRequest,
       requestType: SKRequestType,
       params: JSONObject,
       retryCount: Int = SKServerAPIImplementaton.maxNumberOfRequestRetries,
       parsingHandler: @escaping (Result<JSONObject, SKResponseError>) -> Void) {

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
