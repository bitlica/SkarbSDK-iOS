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
  
  private func compareNumeric(_ version1: String, _ version2: String) -> ComparisonResult {
    return version1.compare(version2, options: .numeric)
  }
  
  /// Before testing disable sync service
  func testOverridedCommansDoneStatus() {
    let status = SKCommandType.purchaseV4
    var command = SKCommand(commandType: status, status: .pending, data: nil)
    SKServiceRegistry.commandStore.saveCommand(command)
    command.changeStatus(to: .done)
    SKServiceRegistry.commandStore.saveCommand(command)
    command.changeStatus(to: .pending)
    SKServiceRegistry.commandStore.saveCommand(command)
    
    XCTAssertEqual(SKServiceRegistry.commandStore.getAllCommands(by: status).first?.status, SKCommandStatus.done)
  }
}
