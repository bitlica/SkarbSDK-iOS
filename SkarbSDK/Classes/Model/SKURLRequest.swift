//
//  SKURLRequest.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

//This is a class, to use reference semantic, to enable remainingRetryCount updates
public class SKURLRequest {

  let request: URLRequest
  let command: SKAppgateCommand
  let completionHandler: (Swift.Result<[String: Any], SKResponseError>) -> Void

  init(request: URLRequest,
       command: SKAppgateCommand,
       parsingHandler: @escaping (Swift.Result<[String: Any], SKResponseError>) -> Void) {

    self.request = request
    self.command = command
    self.completionHandler = parsingHandler
  }
}
