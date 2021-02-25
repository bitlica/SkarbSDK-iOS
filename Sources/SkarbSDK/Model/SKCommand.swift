//
//  SyncCommand.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/3/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import UIKit
import AdSupport

struct SKCommand: Codable {
  let timestamp: Int
  private(set) var commandType: SKCommandType
  private(set) var status: SKCommandStatus
  let data: Data
  private(set) var retryCount: Int
  
  var description: String {
    return "timestamp=\(timestamp), commandType=\(commandType), status=\(status), retryCount=\(retryCount), data = \(String(describing: String(data: data, encoding: .utf8)))"
  }
  
  mutating func incrementRetryCount() {
    retryCount += 1
  }
  
  mutating func changeStatus(to status: SKCommandStatus) {
    self.status = status
  }
  
  func getRetryDelay() -> TimeInterval {
    switch retryCount {
      case 0:
        return 0
      case 1:
        return 0.1
      case 2:
        return 0.5
      case 3:
        return 1
      case 4:
        return 3
      case 5:
        return 7
      case 6:
        return 14
      case 7:
        return 30
      default:
        return 60
    }
  }
  
  static func prepareAppgateData() -> Data {
    var params: [String: Any] = [:]
    params["client"] = prepareClientData()
    params["application"] = prepareApplicationData()
    params["device"] = prepareDeviceData()
    if let testData = SKServiceRegistry.userDefaultsService.codable(forKey: .testData, objectType: SKTestData.self) {
      params["test"] = testData.getJSON()
    }
    if let brokerData = SKServiceRegistry.userDefaultsService.codable(forKey: .brokerData, objectType: SKBrokerData.self) {
      params["source"] = brokerData.getJSON()
    }
    if let purchaseJSON = preparePurchaseData() {
      params["purchase"] = purchaseJSON
    }
    var data: Data = Data()
    guard JSONSerialization.isValidJSONObject(params) else {
      SKLogger.logError("SKCommand prepareAppgateData: json isValidJSONObject",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.internalValue.name: params.description])
      return data
    }
    do {
      data = try JSONSerialization.data(withJSONObject: params, options: .fragmentsAllowed)
    } catch {
      SKLogger.logError("SKCommand prepareAppgateData: can't json serialization to Data",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.internalValue.name: params.description])
    }
    
    return data
  }
  
  static func prepareApplogData(message: String, features: [String: Any]?) -> Data {
    var params: [String: Any] = [:]
    params["client"] = prepareClientData()
    params["application"] = prepareApplicationData()
    params["message"] = message
    params["context"] = features
    
    var data: Data = Data()
    guard JSONSerialization.isValidJSONObject(params) else {
      SKLogger.logError("SKCommand prepareApplogData: json isValidJSONObject",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.internalValue.name: params.description])
      return data
    }
    do {
      data = try JSONSerialization.data(withJSONObject: params, options: [])
    } catch {
      SKLogger.logError("SKCommand prepareApplogData: can't json serialization to Data",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.internalValue.name: params.description])
    }
    
    return data
  }
  
  private static func prepareClientData() ->  [String: Any] {
    var params: [String: Any] = [:]
    params["timestamp"] = "\(Int(Date().timeIntervalSince1970 * 1000000))"
    let initData = SKServiceRegistry.userDefaultsService.codable(forKey: .initData, objectType: SKInitData.self)
    params["client_id"] = initData?.clientId
    params["agent"] = "SkarbSDK0.3.4"
    return params
  }
  
  private static func prepareApplicationData() -> [String: Any] {
    
    guard let initData = SKServiceRegistry.userDefaultsService.codable(forKey: .initData, objectType: SKInitData.self) else {
      SKLogger.logError("SKCommand prepareApplicationData: called and initData is nil",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
      return [:]
    }
    
    var params: [String: Any] = [:]
    params["bundle_id"] = Bundle.main.bundleIdentifier
    params["bundle_ver"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    params["device_id"] = initData.deviceId
    params["date"] = initData.installDate
    params["idfa"] = ASIdentifierManager.shared().advertisingIdentifier.uuidString
    params["receipt_url"] = initData.receiptUrl
    params["receipt_len"] = initData.receiptLen
    
    return params
  }
  
  private static func prepareDeviceData() -> [String: Any] {
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
  
  private static func prepareTestData(name: String, group: String) -> [String: Any]? {
    var params: [String: Any] = [:]
    params["name"] = name
    params["group"] = group
    return params
  }
  
  private static func preparePurchaseData() -> [String: Any]? {
    
    guard let purchaseData = SKServiceRegistry.userDefaultsService.codable(forKey: .purchaseData, objectType: SKPurchaseData.self) else {
      return nil
    }
    
    guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
      SKLogger.logError("SKCommand preparePurchaseData: called but appStoreReceiptURL == nil",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
      return nil
    }
    
    guard let recieptData = try? Data(contentsOf: appStoreReceiptURL) else {
      SKLogger.logError("SKCommand preparePurchaseData: called but recieptData == nil",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
      return nil
    }
    
    if recieptData.isEmpty {
      SKLogger.logError("SKCommand preparePurchaseData: called but recieptData is empty",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
      return nil
    }
    var params: [String: Any] = [:]
    params["product_id"] = purchaseData.productId
    params["price"] = purchaseData.price
    params["currency"] = purchaseData.currency
    params["receipt"] = recieptData.base64EncodedString()
    
    return params
  }
}


extension SKCommand: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.timestamp == rhs.timestamp &&
           lhs.commandType == rhs.commandType
  }
}
