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

struct SKCommand {
  let timestamp: Int
  private(set) var commandType: SKCommandType
  private(set) var status: SKCommandStatus
  private(set) var data: Data
  private(set) var retryCount: Int
  private(set) var fireDate: Date
  
  init(timestamp: Int = Date().nowTimestampInt,
       commandType: SKCommandType,
       status: SKCommandStatus,
       data: Data?,
       retryCount: Int = 0,
       fireDate: Date = Date()) {
    self.timestamp = timestamp
    self.commandType = commandType
    self.status = status
    self.data = data ?? Data()
    self.retryCount = retryCount
    self.fireDate = fireDate
  }
  
  var description: String {
    return "timestamp=\(timestamp), commandType=\(commandType), status=\(status), retryCount=\(retryCount), fireDate=\(fireDate)"
  }
  
  mutating func resetRetryCount() {
    retryCount = 0
  }
  
  mutating func updateRetryCountAndFireDate() {
    retryCount += 1
    updateFireDate(Date().addingTimeInterval(getRetryDelay()))
  }
  
  mutating func changeStatus(to status: SKCommandStatus) {
    self.status = status
  }
  
  mutating func updateData(_ data: Data) {
    self.data = data
  }
  
  mutating func updateFireDate(_ date: Date) {
    self.fireDate = date
  }
  
  private func getRetryDelay() -> TimeInterval {
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
        return 25
      default:
        return 40
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
      SKLogger.logError("SKCommand prepareAppgateData: json isValidJSONObject", features: nil)
      return data
    }
    do {
      data = try JSONSerialization.data(withJSONObject: params, options: .fragmentsAllowed)
    } catch {
      SKLogger.logError("SKCommand prepareAppgateData: can't json serialization to Data", features: nil)
    }
    
    return data
  }
  
  static func prepareApplogData(message: String, features: [String: Any]?) -> Data {
    var params: [String: Any] = [:]
    params["client"] = prepareClientData()
    params["message"] = message
    params["context"] = features
    
    var data: Data = Data()
    guard JSONSerialization.isValidJSONObject(params) else {
      SKLogger.logInfo("SKCommand prepareApplogData: json isValidJSONObject")
      return data
    }
    do {
      data = try JSONSerialization.data(withJSONObject: params, options: [])
    } catch {
      SKLogger.logInfo("SKCommand prepareApplogData: can't json serialization to Data")
    }
    
    return data
  }
  
  private static func prepareClientData() ->  [String: Any] {
    var params: [String: Any] = [:]
    params["timestamp"] = "\(Int(Date().timeIntervalSince1970 * 1000000))"
    let initData = SKServiceRegistry.userDefaultsService.codable(forKey: .initData, objectType: SKInitData.self)
    params["client_id"] = initData?.clientId
    params["agent"] = "SkarbSDK0.3.6"
    return params
  }
  
  private static func prepareApplicationData() -> [String: Any] {
    
    guard let initData = SKServiceRegistry.userDefaultsService.codable(forKey: .initData, objectType: SKInitData.self) else {
      var features: [String: Any] = [:]
      features[SKLoggerFeatureType.agentName.name] = SkarbSDK.agentName
      features[SKLoggerFeatureType.agentVer.name] = SkarbSDK.version
      let message = "SKCommand prepareApplicationData: called and initData is nil"
      let command = SKCommand(commandType: .logging,
                              status: .pending,
                              data: SKCommand.prepareApplogData(message: message, features: features))
      SKServiceRegistry.commandStore.saveCommand(command)
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

extension SKCommand: SKCodableStruct {
  init(from decoder: Swift.Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let timestamp = try container.decode(Int.self, forKey: .timestamp)
    let commandType = try container.decode(SKCommandType.self, forKey: .commandType)
    let status = try container.decode(SKCommandStatus.self, forKey: .status)
    let data = try container.decode(Data.self, forKey: .data)
    let retryCount = try container.decode(Int.self, forKey: .retryCount)
    let fireDate = try container.decode(Date.self, forKey: .fireDate)
    self = SKCommand(timestamp: timestamp,
                     commandType: commandType,
                     status: status,
                     data: data,
                     retryCount: retryCount,
                     fireDate: fireDate)
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(timestamp, forKey: .timestamp)
    try container.encode(commandType, forKey: .commandType)
    try container.encode(status, forKey: .status)
    try container.encode(data, forKey: .data)
    try container.encode(retryCount, forKey: .retryCount)
    try container.encode(fireDate, forKey: .fireDate)
  }
  
  func getData() -> Data? {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      return encoded
    }
    
    return nil
  }
  
  enum CodingKeys: String, CodingKey {
    case timestamp
    case commandType
    case status
    case data
    case retryCount
    case fireDate
  }
}

extension SKCommand: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.timestamp == rhs.timestamp &&
           lhs.commandType == rhs.commandType &&
           lhs.data == rhs.data
  }
}
