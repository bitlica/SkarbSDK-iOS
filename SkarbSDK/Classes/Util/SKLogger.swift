//
//  SyncLog.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

public class SKLogger {
      
  public static func logError(_ message: String) {
    if isDebug {
      print("[ERROR] \(message)")
    }
  }
  
  public static func logWarn(_ message: String) {
    if isDebug {
      print("[WARN] \(message)")
    }
  }
  
  public static func logInfo(_ message: String) {
    if isDebug {
      print("[INFO] \(message)")
    }
  }
  
  public static func logNetwork(_ message: String) {
    if isDebug {
      print("[NETWORK] \(message)")
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
