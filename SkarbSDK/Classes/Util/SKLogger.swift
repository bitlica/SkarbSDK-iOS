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
    NSLog("[ERROR] \(message)")
  }
  
  public static func logWarn(_ message: String) {
    NSLog("[WARN] \(message)")
  }
  
  public static func logInfo(_ message: String) {
    NSLog("[INFO] \(message)")
  }
  
  public static func logDebug(_ message: String) {
    if isDebug {
      NSLog("[DEBUG] \(message)")
    }
  }
  
  public static func logDebugNetwork(_ message: String) {
    if isDebug {
      NSLog("[NETWORK] \(message)")
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
