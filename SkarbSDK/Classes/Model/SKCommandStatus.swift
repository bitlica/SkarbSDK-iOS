//
//  SKCommandStatus.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 4/8/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

enum SKCommandStatus {
  case pending
  case done
  case canceled
}

extension SKCommandStatus: Codable {
  
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
        self = .pending
      case 1:
        self = .done
      case 2:
        self = .canceled
      default:
        throw CodingError.unknownValue
    }
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: Key.self)
    switch self {
      case .pending:
        try container.encode(0, forKey: .rawValue)
      case .done:
        try container.encode(1, forKey: .rawValue)
      case .canceled:
        try container.encode(2, forKey: .rawValue)
    }
  }
}
