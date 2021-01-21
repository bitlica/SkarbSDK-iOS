//
//  SkarbSDKExampleTests.swift
//  SkarbSDKExampleTests
//
//  Created by Artem Hitrik on 1/21/21.
//  Copyright © 2021 Prodinfire. All rights reserved.
//

import XCTest
import Foundation

class SkarbSDKTests: XCTestCase {
  
  func testExample() throws {
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
}
