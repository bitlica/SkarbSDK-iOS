//
//  SKCommandStatus.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/8/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

enum SKCommandStatus {
  case pending // just added to store
  case done // when command was finished successful
  case canceled // might be canceled if we have the same command type in pending status
  case inProgress // if command is processing on the server side
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
      case 3:
        self = .inProgress
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
      case .inProgress:
        try container.encode(3, forKey: .rawValue)
    }
  }
}
