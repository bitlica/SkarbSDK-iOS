//
//  ServerAPIImplementation.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import GRPC
import NIO

class SKServerAPIImplementaton: SKServerAPI {
  
  private static let serverName = "https://track3.skarb.club"
  
  func syncCommand(_ command: SKCommand, completion: ((SKResponseError?) -> Void)?) {
    
    if command.commandType.isV4 {
      let tls = ClientConnection.Configuration.TLS.init(certificateChain: [], privateKey: .none, trustRoots: .default, certificateVerification: .fullVerification, hostnameOverride: nil)


      let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
      let host = "ingest.skarb.work"
      let port = 443
      let configuration = ClientConnection.Configuration(target: .hostAndPort(host, port),
                                                         eventLoopGroup: group,
                                                         tls: tls)
      let clientConnection = ClientConnection(configuration: configuration)

      let installService = Installapi_IngesterClient(channel: clientConnection)
      let purchaseService = Purchaseapi_IngesterClient(channel: clientConnection)
      let priceService = Priceapi_PricerClient(channel: clientConnection)
      
      let decoder = JSONDecoder()
      
      switch command.commandType {
        case .installV4:
          guard let deviceRequest = try? decoder.decode(Installapi_DeviceRequest.self, from: command.data) else {
            let value = String(data: command.data, encoding: .utf8) ?? "Cannt decode to String"
            SKLogger.logError("SyncCommand called with installV4. Installapi_DeviceRequest cannt be decoded",
                              features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                         SKLoggerFeatureType.internalValue.name: value])
            return
          }
          let call = installService.setDevice(deviceRequest)
          call.response.whenComplete { result in
            SKLogger.logNetwork("SKResponse is \(result) for commandType = \(command.commandType)")
            switch result {
              case .success:
                completion?(nil)
              case .failure(let error):
                completion?(SKResponseError(errorCode: error.code, message: error.localizedDescription))
            }
          }
        case .sourceV4:
          guard let attribRequest = try? decoder.decode(Installapi_AttribRequest.self, from: command.data) else {
            let value = String(data: command.data, encoding: .utf8) ?? "Cannt decode to String"
            SKLogger.logError("SyncCommand called with sourceV4. Installapi_AttribRequest cannt be decoded",
                              features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                         SKLoggerFeatureType.internalValue.name: value])
            return
          }
          let call = installService.setAttribution(attribRequest)
          call.response.whenComplete { result in
            SKLogger.logNetwork("SKResponse is \(result) for commandType = \(command.commandType)")
            switch result {
              case .success:
                completion?(nil)
              case .failure(let error):
                completion?(SKResponseError(errorCode: error.code,  message: error.localizedDescription))
            }
          }
        case .testV4:
          guard let testRequest = try? decoder.decode(Installapi_TestRequest.self, from: command.data) else {
            let value = String(data: command.data, encoding: .utf8) ?? "Cannt decode to String"
            SKLogger.logError("SyncCommand called with testV4. Installapi_TestRequest cannt be decoded",
                              features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                         SKLoggerFeatureType.internalValue.name: value])
            return
          }
          let call = installService.setTest(testRequest)
          call.response.whenComplete { result in
            SKLogger.logNetwork("SKResponse is \(result) for commandType = \(command.commandType)")
            switch result {
              case .success:
                completion?(nil)
              case .failure(let error):
                completion?(SKResponseError(errorCode: error.code, message: error.localizedDescription))
            }
          }
        case .purchaseV4:
          guard let purchaseRequest = try? decoder.decode(Purchaseapi_ReceiptRequest.self, from: command.data) else {
            let value = String(data: command.data, encoding: .utf8) ?? "Cannt decode to String"
            SKLogger.logError("SyncCommand called with testV4. Installapi_TestRequest cannt be decoded",
                              features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                         SKLoggerFeatureType.internalValue.name: value])
            return
          }
          let call = purchaseService.setReceipt(purchaseRequest)
          call.response.whenComplete { result in
            SKLogger.logNetwork("SKResponse is \(result) for commandType = \(command.commandType)")
            switch result {
              case .success:
                completion?(nil)
              case .failure(let error):
                completion?(SKResponseError(errorCode: error.code, message: error.localizedDescription))
            }
          }
        case .transactionV4:
          guard let transactionRequest = try? decoder.decode(Purchaseapi_TransactionsRequest.self, from: command.data) else {
            let value = String(data: command.data, encoding: .utf8) ?? "Cannt decode to String"
            SKLogger.logError("SyncCommand called with testV4. Purchaseapi_TransactionsRequest cannt be decoded",
                              features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                         SKLoggerFeatureType.internalValue.name: value])
            return
          }
          let call = purchaseService.setTransactions(transactionRequest)
          call.response.whenComplete { result in
            SKLogger.logNetwork("SKResponse is \(result) for commandType = \(command.commandType)")
            switch result {
              case .success:
                completion?(nil)
              case .failure(let error):
                completion?(SKResponseError(errorCode: error.code, message: error.localizedDescription))
            }
          }
        case .priceV4:
          guard let priceRequest = try? decoder.decode(Priceapi_PricesRequest.self, from: command.data) else {
            let value = String(data: command.data, encoding: .utf8) ?? "Cannt decode to String"
            SKLogger.logError("SyncCommand called with testV4. Priceapi_PricesRequest cannt be decoded",
                              features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                         SKLoggerFeatureType.internalValue.name: value])
            return
          }
          let call = priceService.setPrices(priceRequest)
          call.response.whenComplete { result in
            SKLogger.logNetwork("SKResponse is \(result) for commandType = \(command.commandType)")
            switch result {
              case .success:
                completion?(nil)
              case .failure(let error):
                completion?(SKResponseError(errorCode: error.code, message: error.localizedDescription))
            }
          }
        default:
          SKLogger.logError("SyncCommand called default. Unpredictable case",
                            features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
        break
      }
    } else {
      let urlString = prepareBaseURLString(command: command)
      guard let url = URL(string: urlString) else { return }
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.timeoutInterval = 10
      request.httpBody = command.data
      
      let skRequest = SKURLRequest(request: request,
                                   command: command,
                                   parsingHandler: { result in
                                    SKLogger.logNetwork("SKResponse is \(result) for commandType = \(command.commandType)")
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
}

private extension SKServerAPIImplementaton {
  func executeRequest(_ skRequest: SKURLRequest) {
    SKLogger.logNetwork("Executing request: \(String(describing: skRequest.request.url?.absoluteString)) with params: \(String(describing: String(data: skRequest.command.data, encoding: .utf8)))")
    
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
            skRequest.completionHandler(.failure(SKResponseError(errorCode: 0)))
          }
        } catch let error as NSError {
          skRequest.completionHandler(.failure(SKResponseError(errorCode: 0,
                                                               message: error.localizedDescription)))
        }
      }
    })
    task.resume()
  }
  
  func validateResponseError(response: URLResponse?, data: Data?, error: Error?) -> SKResponseError? {
        
    if let error = error {
      return SKResponseError(errorCode: error.code,
                             message: error.localizedDescription)
    }
    
    guard let response = response as? HTTPURLResponse else {
      return SKResponseError(errorCode: SKResponseError.noResponseCode,
                             message: "Response empty, error empty for NSURLConnection")
    }
    
    switch response.statusCode {
      case (200..<399):
        return nil
      case 500, 400:
        return SKResponseError(errorCode: response.statusCode)
      default:
        break
    }
    
    return SKResponseError(errorCode: response.statusCode,
                           message: "Validating response general error")
  }
  
  func prepareBaseURLString(command: SKCommand) -> String {
    return SKServerAPIImplementaton.serverName + command.commandType.endpoint
  }
}
