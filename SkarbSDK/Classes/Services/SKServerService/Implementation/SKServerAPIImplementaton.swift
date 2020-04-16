//
//  ServerAPIImplementation.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import UIKit

class SKServerAPIImplementaton: SKServerAPI {
  
  private static let serverName = "https://track3.skarb.club"
  
  func syncCommand(_ command: SKAppgateCommand, completion: ((SKResponseError?) -> Void)?) {
    
    let urlString = prepareBaseURLString(urlAction: "/appgate")
    guard let url = URL(string: urlString) else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 10
    request.httpBody = command.data
    
    let skRequest = SKURLRequest(request: request,
                                 command: command,
                                 parsingHandler: { result in
                                  SKLogger.logNetwork("SKResponse is \(result) for requestType = \(command.commandType)")
                                  switch result {
                                    case .success(_):
                                      completion?(nil)
                                    case .failure(let error):
                                      completion?(error)
                                  }
    })
    executeRequest(skRequest)
  }
}

private extension SKServerAPIImplementaton {
  func executeRequest(_ skRequest: SKURLRequest) {
    SKLogger.logNetwork("Executing request: \(String(describing: skRequest.request.url?.absoluteString)) with params: \(String(data: skRequest.command.data, encoding: .utf8))")
    
    let task = URLSession.shared.dataTask(with: skRequest.request, completionHandler: { [weak self] (data, response, error) in
      
      SKLogger.logNetwork("Finished request: \(String(describing: skRequest.request.url?.absoluteString))")
      
      guard let self = self else {
        return
      }
      
      if let error = self.validateResponseError(response: response, data: data, error: error) {
        skRequest.completionHandler(.failure(error))
      } else {
        guard let data = data else {
          return
        }
        do {
          if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            skRequest.completionHandler(.success(json))
          } else {
            skRequest.completionHandler(.failure(SKResponseError(serverStatusCode: 0, message: nil)))
          }
        } catch let error as NSError {
          skRequest.completionHandler(.failure(SKResponseError(serverStatusCode: 0, message: error.localizedDescription)))
        }
      }
    })
    task.resume()
  }
  
  func validateResponseError(response: URLResponse?, data: Data?, error: Error?) -> SKResponseError? {
    
    if let error = error {
      return SKResponseError(serverStatusCode: error._code, message: error.localizedDescription)
    }
    
    guard let response = response as? HTTPURLResponse else {
      return SKResponseError(errorCode: SKResponseError.noResponseCode, message: "Response empty, error empty for NSURLConnection")
    }
    
    switch response.statusCode {
      case (200..<399):
        return nil
      case 500, 400:
        guard let data = data else {
          return SKResponseError(serverStatusCode: response.statusCode, message: nil)
        }
        
        do {
          if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let errorMessage = json["error"] as? String {
            return SKResponseError(serverStatusCode: response.statusCode, message: errorMessage)
          }
        } catch let error as NSError {
          return SKResponseError(serverStatusCode: error.code, message: error.localizedDescription)
      }
      default:
        break
    }
    
    return SKResponseError(serverStatusCode: response.statusCode, message: "Validating response general error")
  }
  
  func prepareBaseURLString(urlAction: String) -> String {
    return SKServerAPIImplementaton.serverName + urlAction
  }
}
