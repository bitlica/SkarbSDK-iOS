//
//  SKAuthApiPbExtension.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 1/21/21.
//  Copyright © 2021 Prodinfire. All rights reserved.
//

import SwiftProtobuf
import Foundation

extension Auth_Auth: SKCodableStruct {
  
  static func createDefault() -> Auth_Auth {
    let authData = Auth_Auth.with {
      $0.key = SkarbSDK.clientId
      $0.bundleID = Bundle.main.bundleIdentifier ?? "unknown"
      $0.agentName = SkarbSDK.agentName
      $0.agentVer = SkarbSDK.version
      $0.timestamp = SwiftProtobuf.Google_Protobuf_Timestamp(date: Date())
    }
    
    return authData
  }
  
  init(from decoder: Swift.Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let key = try container.decode(String.self, forKey: .key)
    let bundleID = try container.decode(String.self, forKey: .bundleID)
    let agentName = try container.decode(String.self, forKey: .agentName)
    let agentVer = try container.decode(String.self, forKey: .agentVer)
    self = Auth_Auth.with({
      $0.key = key
      $0.bundleID = bundleID
      $0.agentName = agentName
      $0.agentVer = agentVer
      $0.timestamp = SwiftProtobuf.Google_Protobuf_Timestamp(date: Date())
    })
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(key, forKey: .key)
    try container.encode(bundleID, forKey: .bundleID)
    try container.encode(agentName, forKey: .agentName)
    try container.encode(agentVer, forKey: .agentVer)
    // no need to encode timestamp because we need to have always is now
    // when sends request to the server 
  }
  
  func getData() -> Data? {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      return encoded
    }
    
    return nil
  }
  
  enum CodingKeys: String, CodingKey {
    case key
    case bundleID
    case agentName
    case agentVer
  }
}
