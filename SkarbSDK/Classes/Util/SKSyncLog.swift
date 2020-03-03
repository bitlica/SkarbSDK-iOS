//
//  SyncLog.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

public protocol LogDelegate {

  func logError(_ message: String, _ nsError: NSError)
  func logWarn(_ message: String, _ nsError: NSError)
  func logInfo(_ message: String)
  func logDebug(_ message: String)
  func logDebugNetwork(_ message: String)
}


//meant for app extensions
struct NSLogBasedImplementation: LogDelegate {

  func logError(_ message: String, _ nsError: NSError) {
    NSLog("[ERROR] \(message)")
  }

  func logWarn(_ message: String, _ nsError: NSError) {
    NSLog("[WARN] \(message)")
  }

  func logInfo(_ message: String) {
    NSLog("[INFO] \(message)")
  }

  func logDebug(_ message: String) {
    NSLog("[DEBUG] \(message)")
  }
  
  func logDebugNetwork(_ message: String) {
    NSLog(message)
  }
}


///The same logging API to be used throughout the main app and all app extensions.  App extensions will
///use NSLog-based implementation set during class initialization. The main app in didFinishLaunchingWithOptions
///sets logDelegate to implementation that writes into log files and sends errors and warnings to Crashlytics
///to take autoclosures and avoid string building costs when no logging is needed
public class SKSyncLog {

  static private let allowNetwork: Bool = true

  public static var logDelegate: LogDelegate = NSLogBasedImplementation()

  public static func logError(_ message: String,
                       file: StaticString = #file,
                       function: StaticString = #function) {


    let nsError = prepareNSError(prefix: "ERROR in ", file: file, function: function, message: message)

    logDelegate.logError(message, nsError)
  }

  public static func logWarn(_ message: String,
                      file: StaticString = #file,
                      function: StaticString = #function) {

    let nsError = prepareNSError(prefix: "WARNING in ", file: file, function: function, message: message)

    logDelegate.logWarn(message, nsError)
  }


  public static func logInfo(_ message: String) {
    logDelegate.logInfo(message)
  }

  public static func logDebug(_ message: @autoclosure () -> String) {
    if isDebug {
      logDelegate.logDebug(message())
    }
  }

  public static func logDebugNetwork(_ message: @autoclosure () -> String) {
    if isDebug && allowNetwork {
      logDelegate.logDebugNetwork(message())
    }
  }
}


//MARK: Private
private extension SKSyncLog {

  static var isDebug: Bool {
    var result = false
    #if DEBUG
      result = true
    #endif
    return result
  }
  
  static func prepareNSError(prefix: String, file: StaticString, function: StaticString, message: String) -> NSError {
    let fileString = "\(file)"
    let names = fileString.components(separatedBy: "/")

    let lastElement = names.last ?? fileString

    let fileName: String
    if let swiftRange = lastElement.range(of: ".swift") {
      fileName = String(lastElement[..<swiftRange.lowerBound])
    } else {
      fileName = lastElement
    }

    let errorDomain: String = "\(prefix)\(fileName).\(function)"

    let errorCode: Int = djb2hash(errorDomain)
    let userInfo = ["message": message]

    return NSError(domain: errorDomain, code: errorCode, userInfo: userInfo)
  }

  //we want the same values of hash value, not randomly seeded hashValue since Swift 4.2
  static func djb2hash(_ string: String) -> Int {
    let unicodeScalars = string.unicodeScalars.map { $0.value }
    return unicodeScalars.reduce(5381) {
      ($0 << 5) &+ $0 &+ Int($1)
    }
  }
}
