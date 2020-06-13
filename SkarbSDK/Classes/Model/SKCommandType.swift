//
//  CommandType.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/3/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

enum SKCommandType: Int {
  case install
  case source
  case test
  case purchase
  case fetchProducts
  case logging
  case automaticSearchAds
  
  // applicable only for server commands
  var endpoint: String {
    switch self {
      case .install, .source, .test, .purchase:
        return"/appgate"
      case .logging:
        return"/applog"
      case .fetchProducts, .automaticSearchAds:
        return ""
    }
  }
}

extension SKCommandType: Codable {
  
  enum Key: CodingKey {
    case rawValue
  }
  
  enum CodingError: Error {
    case unknownValue
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: Key.self)
    let rawValue = try container.decode(Int.self, forKey: .rawValue)
    switch rawValue {
      case 0:
        self = .install
      case 1:
        self = .source
      case 2:
        self = .test
      case 3:
        self = .purchase
      case 4:
        self = .fetchProducts
      case 5:
        self = .logging
      case 6:
        self = .automaticSearchAds
      default:
        throw CodingError.unknownValue
    }
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: Key.self)
    switch self {
      case .install:
        try container.encode(0, forKey: .rawValue)
      case .source:
        try container.encode(1, forKey: .rawValue)
      case .test:
        try container.encode(2, forKey: .rawValue)
      case .purchase:
        try container.encode(3, forKey: .rawValue)
      case .fetchProducts:
        try container.encode(4, forKey: .rawValue)
      case .logging:
        try container.encode(5, forKey: .rawValue)
      case .automaticSearchAds:
        try container.encode(6, forKey: .rawValue)
    }
  }
}
