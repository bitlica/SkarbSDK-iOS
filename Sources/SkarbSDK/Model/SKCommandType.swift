//
//  CommandType.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/3/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

enum SKCommandType: Int {
//  Was removed from 0.6.1 version. V3 is not used anymore
//  case install
//  case source
//  case test
//  case purchase
  case fetchProducts
  case logging
  case automaticSearchAds
  
  case installV4
  case sourceV4
  case testV4
  case purchaseV4
  case transactionV4
  case priceV4
  case idfaV4
  case fetchIdfa
  case setReceipt
  case setAppsflyerId
  
  // applicable only for server commands
  var endpoint: String {
    switch self {
    case .logging:
      return"/applog"
    case .fetchProducts, .automaticSearchAds:
      return ""
    case .installV4, .sourceV4, .testV4, .purchaseV4, .transactionV4, .priceV4, .idfaV4, .fetchIdfa, .setReceipt, .setAppsflyerId:
      return ""
    }
  }
  
  var isV4: Bool {
    switch self {
    case .logging, .fetchProducts, .automaticSearchAds, .fetchIdfa:
      return false
    case .installV4, .sourceV4, .testV4, .purchaseV4, .transactionV4, .priceV4, .idfaV4, .setReceipt, .setAppsflyerId:
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
    case 13:
      self = .idfaV4
    case 14:
      self = .fetchIdfa
    case 15:
      self = .setReceipt
    case 16:
      self = .setAppsflyerId
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
    case .idfaV4:
      try container.encode(13, forKey: .rawValue)
    case .fetchIdfa:
      try container.encode(14, forKey: .rawValue)
    case .setReceipt:
      try container.encode(15, forKey: .rawValue)
    case .setAppsflyerId:
      try container.encode(16, forKey: .rawValue)
    }
  }
}
