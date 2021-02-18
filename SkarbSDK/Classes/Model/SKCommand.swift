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
  private(set) var data: Data
  private(set) var retryCount: Int
  
  init(commandType: SKCommandType,
       status: SKCommandStatus,
       data: Data?,
       retryCount: Int = 0) {
    self.timestamp = Date().nowTimestampMicroSec
    self.commandType = commandType
    self.status = status
    self.data = data ?? Data()
    self.retryCount = retryCount
  }
  
  var description: String {
    return "timestamp=\(timestamp), commandType=\(commandType), status=\(status), retryCount=\(retryCount), data = \(String(describing: String(data: data, encoding: .utf8)))"
  }
  
  mutating func incrementRetryCount() {
    retryCount += 1
  }
  
  mutating func changeStatus(to status: SKCommandStatus) {
    self.status = status
  }
  
  mutating func updateData(_ data: Data) {
    self.data = data
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
    params["timestamp"] = "\(Date().nowTimestampMicroSec)"
    let initData = SKServiceRegistry.userDefaultsService.codable(forKey: .initData, objectType: SKInitData.self)
    params["client_id"] = initData?.clientId
    params["agent"] = SkarbSDK.agentName + SkarbSDK.version
    return params
  }
}


extension SKCommand: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.timestamp == rhs.timestamp &&
           lhs.commandType == rhs.commandType &&
           lhs.data == rhs.data
  }
}
