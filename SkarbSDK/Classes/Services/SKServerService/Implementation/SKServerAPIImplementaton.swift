//
//  ServerAPIImplementation.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import UIKit
import AdSupport

class SKServerAPIImplementaton: SKServerAPI {
  public static let maxNumberOfRequestRetries: Int = 1
  
  private static let serverName = "https://track3.skarb.club"
  
  private let userCallsConcurrentQueue = DispatchQueue(label: "com.skserverAPI.usercalls", qos: .userInitiated, attributes: [.concurrent])
  
  func sendInstall(completion: @escaping (SKResponseError?) -> Void) {
    let requestType = SKRequestType.install
    guard !SKServiceRegistry.userDefaultsService.bool(forKey: .skRequestType(requestType.rawValue)) else {
      SKLogger.logInfo("Send install called, but SDK have already sent install event successful before")
      completion(nil)
      return
    }
    syncAllData(initRequestType: requestType, completion: completion)
  }
  
  func sendTest(name: String, group: String, completion: @escaping (SKResponseError?) -> Void) {
    SKServiceRegistry.userDefaultsService.setJSON(["name": name, "group": group], forKey: .test)
    syncAllData(initRequestType: .test, completion: completion)
  }
  
  func sendSource(broker: SKBroker, features: [AnyHashable: Any], completion: @escaping (SKResponseError?) -> Void) {
    var params: [String: Any] = [:]
    params["broker"] = broker.name
    params["features"] = features
    do {
      let data = try JSONSerialization.data(withJSONObject: params, options: .fragmentsAllowed)
      SKServiceRegistry.userDefaultsService.setData(data, forKey: .broker)
    } catch {
      SKLogger.logError("SKServerAPIImplementaton.sendSource: can't json serialization to Data")
    }
    syncAllData(initRequestType: .broker, completion: completion)
  }
  
  func sendPurchase(productId: String,
                    price: Float?,
                    currency: String?,
                    completion: ((SKResponseError?) -> Void)?) {
    SKServiceRegistry.userDefaultsService.setString(productId, forKey: .productId)
    if let price = price {
      SKServiceRegistry.userDefaultsService.setFloat(price, forKey: .price)
    }
    if let currency = currency {
      SKServiceRegistry.userDefaultsService.setString(currency, forKey: .currency)
    }
    syncAllData(initRequestType: .purchase, completion: completion)
  }
  
  func syncAllData(initRequestType: SKRequestType, completion: ((SKResponseError?) -> Void)?) {
    var params: [String: Any] = [:]
    params["client"] = prepareClientData()
    params["application"] = prepareApplicationData()
    params["device"] = prepareDeviceData()
    if let testJSON = SKServiceRegistry.userDefaultsService.json(forKey: .test) {
      params["test"] = testJSON
    }
    if let brokerData = SKServiceRegistry.userDefaultsService.data(forKey: .broker) {
      do {
        let brokerJSON = try JSONSerialization.jsonObject(with: brokerData, options: [])
        params["source"] = brokerJSON
      } catch {
        SKLogger.logError("SKServerAPIImplementaton.syncAllData: can't json serialization to Data for source")
      }
    }
    if let purchaseJSON = preparePurchaseData() {
      params["purchase"] = purchaseJSON
    }
    
    let urlString = prepareBaseURLString(urlAction: "/appgate")
    guard let url = URL(string: urlString) else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 10
    do {
      let data = try JSONSerialization.data(withJSONObject: params, options: .fragmentsAllowed)
      request.httpBody = data
    } catch {
      SKLogger.logError("executeRequest: can't json serialization to Data")
    }
    
    let skRequest = SKURLRequest(request: request,
                              requestType: initRequestType,
                              params: params,
                              parsingHandler: { result in
                                SKLogger.logNetwork("SKResponse is \(result) for requestType = \(initRequestType)")
                                switch result {
                                  case .success(_):
                                    SKServiceRegistry.userDefaultsService.removeValue(forKey: .requestTypeToSync)
                                    SKServiceRegistry.userDefaultsService.setBool(true, forKey: .skRequestType(initRequestType.rawValue))
                                    completion?(nil)
                                  case .failure(let error):
                                    SKServiceRegistry.userDefaultsService.setString(initRequestType.rawValue, forKey: .requestTypeToSync)
                                    completion?(error)
                                }
    })
    executeRequest(skRequest)
  }
}

private extension SKServerAPIImplementaton {
  func executeRequest(_ skRequest: SKURLRequest) {
    SKLogger.logNetwork("Executing request: \(String(describing: skRequest.request.url?.absoluteString)) with params: \(skRequest.params)")
    
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
  
  func prepareClientData() ->  [String: Any] {
    var params: [String: Any] = [:]
    params["timestamp"] = "\(Int(Date().timeIntervalSince1970 * 1000000))"
    params["client_id"] = SKServiceRegistry.userDefaultsService.string(forKey: .clientId)
    if let env = SKServiceRegistry.userDefaultsService.string(forKey: .env) {
      params["env"] = env
    }
    return params
  }
  
  func prepareApplicationData() -> [String: Any] {
    var params: [String: Any] = [:]
    params["bundle_id"] = Bundle.main.bundleIdentifier
    params["bundle_ver"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    params["device_id"] = SKServiceRegistry.userDefaultsService.string(forKey: .deviceId)
    let installedDate: String
    if let installedDateISO8601 = SKServiceRegistry.userDefaultsService.string(forKey: .installedDateISO8601) {
      installedDate = installedDateISO8601
    } else {
      installedDate = Formatter.iso8601.string(from: Date())
      SKServiceRegistry.userDefaultsService.setString(installedDate, forKey: .installedDateISO8601)
    }
    params["date"] = installedDate
    params["idfa"] = ASIdentifierManager.shared().advertisingIdentifier.uuidString
    
    return params
  }
  
  func prepareDeviceData() -> [String: Any] {
    var params: [String: Any] = [:]
    if let preferredLanguage = Locale.preferredLanguages.first {
      params["locale"] = preferredLanguage
    } else {
      params["locale"] = "unknown"
    }
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    params["device"] = identifier
    params["os_ver"] = UIDevice.current.systemVersion
    
    return params
  }
  
  func prepareTestData(name: String, group: String) -> [String: Any]? {
    var params: [String: Any] = [:]
    params["name"] = name
    params["group"] = group
    return params
  }
  
  func preparePurchaseData() -> [String: Any]? {
    
    guard let productId = SKServiceRegistry.userDefaultsService.string(forKey: .productId) else {
      return nil
    }
    
    guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
      let recieptData = try? Data(contentsOf: appStoreReceiptURL) else {
      return nil
    }
    if recieptData.isEmpty {
      SKLogger.logInfo("PreparePurchaseData() called. But recieptData is empty")
      return nil
    }
    var params: [String: Any] = [:]
    params["product_id"] = productId
    params["price"] = SKServiceRegistry.userDefaultsService.float(forKey: .price)
    params["currency"] = SKServiceRegistry.userDefaultsService.string(forKey: .currency)
    params["receipt"] = recieptData.base64EncodedString()
    
    return params
  }
}
