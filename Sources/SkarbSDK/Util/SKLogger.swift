//
//  SyncLog.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import os

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

  /// Mirror of every logged line into the unified log, in addition to `print`.
  ///
  /// `print` writes to stderr, which Xcode's console shows only while a debugger is attached.
  /// A build installed from TestFlight or the App Store therefore produces no collectable log at
  /// all - which is exactly when a purchase problem is worth looking at. `os_log` goes to the
  /// system log store, so the same lines show up in Console.app and in `log stream` / `log
  /// collect` with nothing attached.
  ///
  /// `OSLog` is iOS 10+, so no availability gate is needed at our deployment target.
  ///
  /// Gated by the same `SkarbSDK.isLoggingEnabled` as `print`, so an integrator who has not asked
  /// for logs sees no change in behaviour.
  ///
  /// Everything is logged at `.default` (notice) or `.error`, never `.info`: `.info` is not
  /// persisted to the log store unless the reader turns on "Include Info Messages", and lines
  /// that only exist while someone remembers a checkbox are not worth having.
  ///
  /// `%{public}@` on purpose - the unified log redacts dynamic strings by default and would
  /// store `<private>` in place of every message.
  private static let osLog = OSLog(subsystem: "com.skarbsdk", category: "sdk")

  private static func mirror(_ level: String, _ message: String, type: OSLogType) {
    guard SkarbSDK.isLoggingEnabled else {
      return
    }
    // Same prefix as the `print` output, so a plain text search for "SkarbSDK" finds these lines
    // in Console.app - filtering by subsystem is exact, but nobody reaches for it first.
    os_log("[SkarbSDK-%{public}@] [%{public}@] %{public}@", log: osLog, type: type, SkarbSDK.version, level, message)
  }

  static func logError(_ message: String, features: [String: Any]?) {
    var features = features ?? [:]
    features[SKLoggerFeatureType.agentName.name] = SkarbSDK.agentName
    features[SKLoggerFeatureType.agentVer.name] = SkarbSDK.version
    features[SKLoggerFeatureType.installId.name] = SkarbSDK.getDeviceId()
    features[SKLoggerFeatureType.proxy.name] = getProxySettings()
    let command = SKCommand(commandType: .logging,
                            status: .pending,
                            data: SKCommand.prepareApplogData(message: message, features: features))
    SKServiceRegistry.commandStore.saveCommand(command)
    if SkarbSDK.isLoggingEnabled {
      print("\(Formatter.milliSec.string(from: Date())) [SkarbSDK-\(SkarbSDK.version)] [ERROR] \(message)")
      mirror("ERROR", message, type: .error)
    }
  }
  
  static func logWarn(_ message: String, features: [String: Any]?) {
    let command = SKCommand(commandType: .logging,
                            status: .pending,
                            data: SKCommand.prepareApplogData(message: message, features: features))
    SKServiceRegistry.commandStore.saveCommand(command)
    if SkarbSDK.isLoggingEnabled {
      print("\(Formatter.milliSec.string(from: Date())) [SkarbSDK-\(SkarbSDK.version)] [WARN] \(message)")
      mirror("WARN", message, type: .default)
    }
  }
  
  static func logInfo(_ message: String) {
    if SkarbSDK.isLoggingEnabled {
      print("\(Formatter.milliSec.string(from: Date())) [SkarbSDK-\(SkarbSDK.version)] [INFO] \(message)")
      mirror("INFO", message, type: .default)
    }
  }
  
  static func logNetwork(_ message: String) {
    if SkarbSDK.isLoggingEnabled {
      print("\(Formatter.milliSec.string(from: Date())) [SkarbSDK-\(SkarbSDK.version)] [NETWORK] \(message)")
      mirror("NETWORK", message, type: .default)
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
