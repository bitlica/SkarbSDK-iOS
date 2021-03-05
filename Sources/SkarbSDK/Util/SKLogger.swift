//
//  SyncLog.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

enum SKLoggerFeatureType {
  case requestType
  case retryCount
  case responseHeaders
  case responseBody
  case responseStatus
  case purchase
  case internalError
  case internalValue
  case agentName
  case agentVer
  case installId
  case connection
  
  var name: String {
    switch self {
      case .requestType:
        return "requestType"
      case .retryCount:
        return "retryCount"
      case .responseHeaders:
        return "responseHeaders"
      case .responseBody:
        return "responseBody"
      case .responseStatus:
        return "responseStatus"
      case .purchase:
        return "purchase"
      case .internalError:
        return "internalError"
      case .internalValue:
        return "internalValue"
      case .agentName:
        return "agentName"
      case .agentVer:
        return "agentVer"
      case .installId:
        return "installId"
      case .connection:
        return "connection"
    }
  }
}

class SKLogger {
  
  static func logError(_ message: String, features: [String: Any]?) {
    var features = features ?? [:]
    features[SKLoggerFeatureType.agentName.name] = SkarbSDK.agentName
    features[SKLoggerFeatureType.agentVer.name] = SkarbSDK.version
    features[SKLoggerFeatureType.installId.name] = SkarbSDK.getDeviceId()
    let command = SKCommand(commandType: .logging,
                            status: .pending,
                            data: SKCommand.prepareApplogData(message: message, features: features))
    SKServiceRegistry.commandStore.saveCommand(command)
    if isDebug {
      print("\(Formatter.milliSec.string(from: Date())) [ERROR] \(message)")
    }
  }
  
  static func logWarn(_ message: String, features: [String: Any]?) {
    let command = SKCommand(commandType: .logging,
                            status: .pending,
                            data: SKCommand.prepareApplogData(message: message, features: features))
    SKServiceRegistry.commandStore.saveCommand(command)
    if isDebug {
      print("\(Formatter.milliSec.string(from: Date())) [WARN] \(message)")
    }
  }
  
  static func logInfo(_ message: String) {
    if isDebug {
      print("\(Formatter.milliSec.string(from: Date())) [INFO] \(message)")
    }
  }
  
  static func logNetwork(_ message: String) {
    if isDebug {
      print("\(Formatter.milliSec.string(from: Date())) [NETWORK] \(message)")
    }
  }
}


//MARK: Private
private extension SKLogger {
  
  static var isDebug: Bool {
    var result = false
    #if DEBUG
    result = true
    #endif
    return result
  }
}
