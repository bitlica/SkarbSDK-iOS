//
//  CommandType.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/3/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

enum SKCommandType: Int {
//  v3. Out of dated
//  case install = 0
//  case source = 1
//  case test = 2
//  case purchase = 3
  case fetchProducts = 4
  case logging = 5
  case automaticSearchAds = 6
  
  case installV4 = 7
  case sourceV4 = 8
  case testV4 = 9
  case purchaseV4 = 10
  case transactionV4 = 11
  case priceV4 = 12
  
  // applicable only for server commands
  var endpoint: String {
    switch self {
      case .logging:
        return"/applog"
      case .fetchProducts, .automaticSearchAds, .installV4, .sourceV4, .testV4,
           .purchaseV4, .transactionV4, .priceV4:
        return ""
    }
  }
  
  var isV4: Bool {
    switch self {
      case .logging, .fetchProducts, .automaticSearchAds:
        return false
      case .installV4, .sourceV4, .testV4, .purchaseV4, .transactionV4, .priceV4:
        return true
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
      case 4:
        self = .fetchProducts
      case 5:
        self = .logging
      case 6:
        self = .automaticSearchAds
      case 7:
        self = .installV4
      case 8:
        self = .sourceV4
      case 9:
        self = .testV4
      case 10:
        self = .purchaseV4
      case 11:
        self = .transactionV4
      case 12:
        self = .priceV4
      default:
        throw CodingError.unknownValue
    }
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: Key.self)
    switch self {
      case .fetchProducts:
        try container.encode(4, forKey: .rawValue)
      case .logging:
        try container.encode(5, forKey: .rawValue)
      case .automaticSearchAds:
        try container.encode(6, forKey: .rawValue)
      case .installV4:
        try container.encode(7, forKey: .rawValue)
      case .sourceV4:
        try container.encode(8, forKey: .rawValue)
      case .testV4:
        try container.encode(9, forKey: .rawValue)
      case .purchaseV4:
        try container.encode(10, forKey: .rawValue)
      case .transactionV4:
        try container.encode(11, forKey: .rawValue)
      case .priceV4:
        try container.encode(12, forKey: .rawValue)
    }
  }
}
