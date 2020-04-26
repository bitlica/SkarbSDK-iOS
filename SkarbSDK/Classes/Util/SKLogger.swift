//
//  SyncLog.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

enum SKLoggerFeatureType: String {
  case requestType
  case retryCount
  case responseHeaders
  case responseBody
  case responseStatus
  case purchase
  case internalError
}

class SKLogger {
      
  static func logError(_ message: String, features: [AnyHashable: Any]?) {
    let command = SKCommand(timestamp: Date().nowTimestampInt,
                            commandType: .logging,
                            status: .pending,
                            data: SKCommand.prepareApplogData(message: message, features: features),
                            retryCount: 0)
    SKServiceRegistry.commandStore.saveCommand(command)
    if isDebug {
      print("\(Formatter.milliSec.string(from: Date())) [ERROR] \(message)")
    }
  }
  
  static func logWarn(_ message: String, features: [AnyHashable: Any]?) {
    let command = SKCommand(timestamp: Date().nowTimestampInt,
                            commandType: .logging,
                            status: .pending,
                            data: SKCommand.prepareApplogData(message: message, features: features),
                            retryCount: 0)
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
