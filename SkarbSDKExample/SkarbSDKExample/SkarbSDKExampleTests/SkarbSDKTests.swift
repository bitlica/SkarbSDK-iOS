//
//  SkarbSDKExampleTests.swift
//  SkarbSDKExampleTests
//
//  Created by Artem Hitrik on 1/21/21.
//  Copyright © 2021 Prodinfire. All rights reserved.
//

import XCTest
import Foundation
@testable import SkarbSDKExample

class SkarbSDKTests: XCTestCase {
  
  private var timer: Timer?
  private let actionSerialQueue = DispatchQueue(label: "com.skarbSDKTest.sync.action", qos: .userInitiated)
  
  func testVersion() throws {
    XCTAssertEqual(compareNumeric("1.0","2.0"), ComparisonResult.orderedAscending)
    XCTAssertEqual(compareNumeric("v2.9","v3.0"), ComparisonResult.orderedAscending)
    XCTAssertEqual(compareNumeric("1.1.5", "2.0.0"), ComparisonResult.orderedAscending)
    XCTAssertEqual(compareNumeric("2.1", "2.0"), ComparisonResult.orderedDescending)
    XCTAssertEqual(compareNumeric("2.0.0", "1.0.1"), ComparisonResult.orderedDescending)
    XCTAssertEqual(compareNumeric("2.4", "2.4"), ComparisonResult.orderedSame)
    XCTAssertEqual(compareNumeric("0.0", "0.1a"), ComparisonResult.orderedAscending)
    XCTAssertEqual(compareNumeric("0.1c", "0.1b"), ComparisonResult.orderedDescending)
    XCTAssertEqual(compareNumeric("2019.4", "2018.5"), ComparisonResult.orderedDescending)
    XCTAssertEqual(compareNumeric("0.4.2", "4.2"), ComparisonResult.orderedAscending)
    XCTAssertEqual(compareNumeric("0.4.0", "0.14.0"), ComparisonResult.orderedAscending)
    XCTAssertEqual(compareNumeric("0.4", "0.14.0"), ComparisonResult.orderedAscending)
    XCTAssertEqual(compareNumeric("4", "0.14.0"), ComparisonResult.orderedDescending)
    XCTAssertEqual(compareNumeric("0.1b", "0.2a"), ComparisonResult.orderedAscending)
  }
  
  func compareNumeric(_ version1: String, _ version2: String) -> ComparisonResult {
    return version1.compare(version2, options: .numeric)
  }
  
  // test async executing commands
  func testExecutingCommands() {
    
    // disable for now
    
//    let commands = SKServiceRegistry.commandStore.getAllCommands(by: .logging)
//    for command in commands {
//      print(command.description)
//    }
//
//    prepapreCommands()
//
//    timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { [weak self] _ in
//      self?.actionSerialQueue.async {
//        self?.syncAllCommands()
//      }
//    })
//
//    let promise = XCTestExpectation(description: "Some description")
//    _ = XCTWaiter().wait(for: [promise], timeout: 10)
  }
  
  private func syncAllCommands() {
    dispatchPrecondition(condition: .notOnQueue(DispatchQueue.main))
    
    let pendingCommands = SKServiceRegistry.commandStore.getPendingCommands()
    for pendingCommand in pendingCommands {
      var command = pendingCommand
      command.changeStatus(to: .inProgress)
      SKServiceRegistry.commandStore.saveCommand(command)
      let delay: TimeInterval = command.getRetryDelay()
      DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay, execute: {
        
        SKLogger.logInfo("Command start executing: \(command.description)")
        
        let delay: TimeInterval = TimeInterval.random(in: 0.3...0.8)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay, execute: {
          if command.retryCount == 19 {
            command.changeStatus(to: .done)
          } else {
            command.incrementRetryCount()
            command.changeStatus(to: .pending)
          }
          SKServiceRegistry.commandStore.saveCommand(command)
        })
      })
    }
  }
  
  private func prepapreCommands() {
    SKServiceRegistry.commandStore.deleteAllCommand(by: .logging)
    let command1 = SKCommand(commandType: .logging, status: .pending, data: "command1".data(using: .utf8))
    let command2 = SKCommand(commandType: .logging, status: .pending, data: "command2".data(using: .utf8))
    let command3 = SKCommand(commandType: .logging, status: .pending, data: "command3".data(using: .utf8))
    let command4 = SKCommand(commandType: .logging, status: .pending, data: "command4".data(using: .utf8))
    let command5 = SKCommand(commandType: .logging, status: .pending, data: "command5".data(using: .utf8))
    let command6 = SKCommand(commandType: .logging, status: .pending, data: "command6".data(using: .utf8))
    let command7 = SKCommand(commandType: .logging, status: .pending, data: "command7".data(using: .utf8))
    let command8 = SKCommand(commandType: .logging, status: .pending, data: "command8".data(using: .utf8))
    let command9 = SKCommand(commandType: .logging, status: .pending, data: "command9".data(using: .utf8))
    let command10 = SKCommand(commandType: .logging, status: .pending, data: "command10".data(using: .utf8))
    
    let commands: [SKCommand] = [command1, command2, command3, command4, command5,
                                 command6, command7, command8, command9, command10]
    for command in commands {
      SKServiceRegistry.commandStore.saveCommand(command)
    }
  }
}
