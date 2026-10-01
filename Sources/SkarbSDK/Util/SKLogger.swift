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
  case proxy
  
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
      case .proxy:
        return "proxy"
    }
  }
}

class SKLogger {
  
  static func logError(_ message: String, features: [String: Any]?) {
    if SkarbSDK.isAnalyticsEnabled {
      var features = features ?? [:]
      features[SKLoggerFeatureType.agentName.name] = SkarbSDK.agentName
      features[SKLoggerFeatureType.agentVer.name] = SkarbSDK.version
      features[SKLoggerFeatureType.installId.name] = SkarbSDK.getDeviceId()
      features[SKLoggerFeatureType.proxy.name] = getProxySettings()
      saveLogCommand(message: message, features: features)
    }
    if SkarbSDK.isLoggingEnabled {
      print("\(Formatter.milliSec.string(from: Date())) [SkarbSDK-\(SkarbSDK.version)] [ERROR] \(message)")
    }
  }
  
  static func logWarn(_ message: String, features: [String: Any]?) {
    if SkarbSDK.isAnalyticsEnabled {
      saveLogCommand(message: message, features: features)
    }
    if SkarbSDK.isLoggingEnabled {
      print("\(Formatter.milliSec.string(from: Date())) [SkarbSDK-\(SkarbSDK.version)] [WARN] \(message)")
    }
  }
  
  /// Logs are sent to the server with the install id, so callers only queue them with
  /// analytics consent.
  private static func saveLogCommand(message: String, features: [String: Any]?) {
    let command = SKCommand(commandType: .logging,
                            status: .pending,
                            data: SKCommand.prepareApplogData(message: message, features: features))
    SKServiceRegistry.commandStore.saveCommand(command)
  }
  
  static func logInfo(_ message: String) {
    if SkarbSDK.isLoggingEnabled {
      print("\(Formatter.milliSec.string(from: Date())) [SkarbSDK-\(SkarbSDK.version)] [INFO] \(message)")
    }
  }
  
  static func logNetwork(_ message: String) {
    if SkarbSDK.isLoggingEnabled {
      print("\(Formatter.milliSec.string(from: Date())) [SkarbSDK-\(SkarbSDK.version)] [NETWORK] \(message)")
    }
  }
  
  private static func getProxySettings() -> [String:AnyObject]? {
    guard let proxiesSettingsUnmanaged = CFNetworkCopySystemProxySettings() else {
      return nil
    }
    return proxiesSettingsUnmanaged.takeRetainedValue() as? [String:AnyObject]
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
