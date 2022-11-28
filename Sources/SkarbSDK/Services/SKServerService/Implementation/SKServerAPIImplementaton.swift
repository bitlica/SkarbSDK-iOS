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
import NIOHPACK
import SwiftProtobuf

class SKServerAPIImplementaton: SKServerAPI {
  
  private static let serverName = "https://track3.skarb.club"
  
  private var clientChannel: ClientConnection = {
    let tls = ClientConnection.Configuration.TLS.init(certificateChain: [],
                                                      privateKey: .none,
                                                      trustRoots: .default,
                                                      certificateVerification: .fullVerification,
                                                      hostnameOverride: nil)
    
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let host = "ingest.skarb.work"
    let port = 443
    let configuration = ClientConnection.Configuration(target: .hostAndPort(host, port),
                                                       eventLoopGroup: group,
                                                       tls: tls)
    let clientChannel = ClientConnection(configuration: configuration)
    
    return clientChannel
  }()
  
  func syncCommand(_ command: SKCommand, completion: ((SKResponseError?) -> Void)?) {
    
    if command.commandType.isV4 {
      let callOption = CallOptions(timeLimit: .timeout(.seconds(20)))
      let installService = Installapi_IngesterClient(channel: clientChannel, defaultCallOptions: callOption)
      let purchaseService = Purchaseapi_IngesterClient(channel: clientChannel, defaultCallOptions: callOption)
      let priceService = Priceapi_PricerClient(channel: clientChannel,defaultCallOptions: callOption)
      
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
          call.initialMetadata.whenComplete({ [weak self] result in
            self?.validateGrpcResponseResult(result, commandType: command.commandType.rawValue, retryCount: command.retryCount)
          })
          call.response.whenComplete { [weak self] result in
            self?.handleGrpcResponseResult(result,
                                           commandType: command.commandType,
                                           completion: completion)
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
          call.initialMetadata.whenComplete({ [weak self] result in
            self?.validateGrpcResponseResult(result, commandType: command.commandType.rawValue, retryCount: command.retryCount)
          })
          call.response.whenComplete { [weak self] result in
            self?.handleGrpcResponseResult(result,
                                           commandType: command.commandType,
                                           completion: completion)
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
          call.initialMetadata.whenComplete({ [weak self] result in
            self?.validateGrpcResponseResult(result, commandType: command.commandType.rawValue, retryCount: command.retryCount)
          })
          call.response.whenComplete { [weak self] result in
            self?.handleGrpcResponseResult(result,
                                           commandType: command.commandType,
                                           completion: completion)
          }
        case .purchaseV4:
          guard let purchaseRequest = try? decoder.decode(Purchaseapi_ReceiptRequest.self, from: command.data) else {
            let value = String(data: command.data, encoding: .utf8) ?? "Cannt decode to String"
            SKLogger.logError("SyncCommand called with purchaseV4. Purchaseapi_ReceiptRequest cannt be decoded",
                              features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                         SKLoggerFeatureType.internalValue.name: value])
            return
          }
          let call = purchaseService.setReceipt(purchaseRequest)
          call.initialMetadata.whenComplete({ [weak self] result in
            self?.validateGrpcResponseResult(result, commandType: command.commandType.rawValue, retryCount: command.retryCount)
          })
          call.response.whenComplete { [weak self] result in
            self?.handleGrpcPurchaseResult(result,
                                           commandType: command.commandType,
                                           completion: completion)
          }
        case .transactionV4:
          guard let transactionRequest = try? decoder.decode(Purchaseapi_TransactionsRequest.self, from: command.data) else {
            let value = String(data: command.data, encoding: .utf8) ?? "Cannt decode to String"
            SKLogger.logError("SyncCommand called with transactionV4. Purchaseapi_TransactionsRequest cannt be decoded",
                              features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                         SKLoggerFeatureType.internalValue.name: value])
            return
          }
          let call = purchaseService.setTransactions(transactionRequest)
          call.initialMetadata.whenComplete({ [weak self] result in
            self?.validateGrpcResponseResult(result, commandType: command.commandType.rawValue, retryCount: command.retryCount)
          })
          call.response.whenComplete { [weak self] result in
            self?.handleGrpcResponseResult(result,
                                           commandType: command.commandType,
                                           completion: completion)
          }
        case .priceV4:
          guard let priceRequest = try? decoder.decode(Priceapi_PricesRequest.self, from: command.data) else {
            let value = String(data: command.data, encoding: .utf8) ?? "Cannt decode to String"
            SKLogger.logError("SyncCommand called with priceV4. Priceapi_PricesRequest cannt be decoded",
                              features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                         SKLoggerFeatureType.internalValue.name: value])
            return
          }
          let call = priceService.setPrices(priceRequest)
          call.initialMetadata.whenComplete({ [weak self] result in
            self?.validateGrpcResponseResult(result, commandType: command.commandType.rawValue, retryCount: command.retryCount)
          })
          call.response.whenComplete { [weak self] result in
            self?.handleGrpcResponseResult(result,
                                           commandType: command.commandType,
                                           completion: completion)
          }
        case .idfaV4:
          guard let idfaRequest = try? decoder.decode(Installapi_IDFARequest.self, from: command.data) else {
            let value = String(data: command.data, encoding: .utf8) ?? "Cannt decode to String"
            SKLogger.logError("SyncCommand called with idfaV4. Installapi_IDFARequest cannt be decoded",
                              features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                         SKLoggerFeatureType.internalValue.name: value])
            return
          }
          let call = installService.setIDFA(idfaRequest)
          call.initialMetadata.whenComplete({ [weak self] result in
            self?.validateGrpcResponseResult(result, commandType: command.commandType.rawValue, retryCount: command.retryCount)
          })
          call.response.whenComplete { [weak self] result in
            self?.handleGrpcResponseResult(result,
                                           commandType: command.commandType,
                                           completion: completion)
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
  
  func verifyReceipt(completion: @escaping (Result<SKUserPurchaseInfo, Error>) -> Void) {
    let callOption = CallOptions(timeLimit: .timeout(.seconds(20)))
    let purchaseService = Purchaseapi_IngesterClient(channel: clientChannel, defaultCallOptions: callOption)
    var verifyRequest = Purchaseapi_VerifyReceiptRequest()
    verifyRequest.auth = Auth_Auth.createDefault()
    verifyRequest.installID = SkarbSDK.getDeviceId()
    let appStoreReceiptURL = Bundle.main.appStoreReceiptURL
    if let appStoreReceiptURL = appStoreReceiptURL,
       let recieptData = try? Data(contentsOf: appStoreReceiptURL) {
      verifyRequest.receipt = recieptData
    } else {
      verifyRequest.receipt = Data()
      SKLogger.logError("Create purchase for V4. recieptData is nil",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
    }
    let call = purchaseService.verifyReceipt(verifyRequest)
    call.initialMetadata.whenComplete({ [weak self] result in
      self?.validateGrpcResponseResult(result, commandType: 98, retryCount: 0)
    })
    call.response.whenComplete { result in
      SKLogger.logNetwork("SKResponse is \(result) for commandType = verifyReceipt")
      switch result {
        case .success(let verifyReceiptResponse):
          DispatchQueue.main.async {
            completion(.success(SKUserPurchaseInfo(verifyReceiptResponse: verifyReceiptResponse)))
          }
        case .failure(let error):
          let message = (error as? GRPCStatus)?.message ?? error.localizedDescription
          DispatchQueue.main.async {
            completion(.failure(SKResponseError(errorCode: error.code, message: message)))
          }
      }
    }
  }
  
  func getOfferings(completion: @escaping (Result<Setupsapi_OfferingsResponse, Error>) -> Void) {
    let callOption = CallOptions(timeLimit: .timeout(.seconds(20)))
    let offeringsService = Setupsapi_SetupsClient(channel: clientChannel, defaultCallOptions: callOption)
    
    var offeringsRequest = Setupsapi_OfferingsRequest()
    offeringsRequest.auth = Auth_Auth.createDefault()
    offeringsRequest.installID = SkarbSDK.getDeviceId()
    
    let call = offeringsService.getOfferings(offeringsRequest)
    call.initialMetadata.whenComplete({ [weak self] result in
      self?.validateGrpcResponseResult(result, commandType: 99, retryCount: 0)
    })
    call.response.whenComplete { result in
      SKLogger.logNetwork("SKResponse is \(result) for commandType = verifyReceipt")
      switch result {
        case .success(let offeringsResponse):
          completion(.success(offeringsResponse))
        case .failure(let error):
          let message = (error as? GRPCStatus)?.message ?? error.localizedDescription
          completion(.failure(SKResponseError(errorCode: error.code, message: message)))
      }
    }
  }
}

private extension SKServerAPIImplementaton {
  func executeRequest(_ skRequest: SKURLRequest) {
    SKLogger.logNetwork("Executing request: \(String(describing: skRequest.request.url?.absoluteString))")
    
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
                           message: "Validating response general error. Status code = \(response.statusCode)")
  }
  
  func prepareBaseURLString(command: SKCommand) -> String {
    return SKServerAPIImplementaton.serverName + command.commandType.endpoint
  }
  
  func validateGrpcResponseResult(_ result: Result<HPACKHeaders, Error>,
                                  commandType: Int,
                                  retryCount: Int) {
    switch result {
      case .success(let headers):
        guard let status = headers.first(name: ":status"),
              status != "200" else {
          return
        }
        var message = ""
        for header in headers {
          message.append("\(header.name): \(header.value)\n")
        }
        var features: [String: Any] = [:]
        features[SKLoggerFeatureType.requestType.name] = commandType
        features[SKLoggerFeatureType.retryCount.name] = retryCount
        features[SKLoggerFeatureType.responseStatus.name] = status
        features[SKLoggerFeatureType.connection.name] = SKServiceRegistry.syncService.connection?.description
        SKLogger.logError("GRPC status validation code is not 200", features: features)
      case .failure:
        break
    }
  }
  
  func handleGrpcResponseResult(_ result: Result<Google_Protobuf_Empty, Error>,
                                commandType: SKCommandType,
                                completion: ((SKResponseError?) -> Void)?) {
    SKLogger.logNetwork("SKResponse is \(result) for commandType = \(commandType)")
    switch result {
      case .success:
        completion?(nil)
      case .failure(let error):
        completion?(SKResponseError(errorCode: error.code, message: error.localizedDescription + "\n" + "\(result)"))
    }
  }
  
  func handleGrpcPurchaseResult(_ result: Result<Purchaseapi_ReceiptResponse, Error>,
                                commandType: SKCommandType,
                                completion: ((SKResponseError?) -> Void)?) {
    SKLogger.logNetwork("SKResponse is \(result) for commandType = \(commandType)")
    switch result {
      case .success:
        completion?(nil)
      case .failure(let error):
        completion?(SKResponseError(errorCode: error.code, message: error.localizedDescription + "\n" + "\(result)"))
    }
  }
  
  func handleGrpcVerifyReceiptResult(_ result: Result<Purchaseapi_VerifyReceiptResponse, Error>,
                                     commandType: SKCommandType,
                                     completion: ((SKResponseError?) -> Void)?) {
    SKLogger.logNetwork("SKResponse is \(result) for commandType = \(commandType)")
    switch result {
      case .success:
        completion?(nil)
      case .failure(let error):
        completion?(SKResponseError(errorCode: error.code, message: error.localizedDescription + "\n" + "\(result)"))
    }
  }
}
