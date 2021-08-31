//
//  UserDefaultsService.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/22/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

class SKUserDefaultsService {
  enum SKKey {
    case initData
    case brokerData
    case testData
    case purchaseData
    case appgateComands
    case oldSchemaVersion
    case isLoggingEnabled
    case deviceId
    
    var keyName: String {
      switch self {
        case .initData:
          return "sk_init_data_key"
        case .brokerData:
          return "sk_broker_data_key"
        case .testData:
          return "sk_test_data_key"
        case .purchaseData:
          return "sk_purchase_data"
        case .appgateComands:
          return "sk_appgate_commands"
        case .oldSchemaVersion:
          return "sk_old_schema_version"
        case .isLoggingEnabled:
          return "sk_is_logging_enabled_key"
        case .deviceId:
          return "sk_device_id_key"
      }
    }
  }
  
  private let userDefaults: UserDefaults
  init() {
    self.userDefaults = UserDefaults.standard
  }
  
  func removeValue(forKey key: SKKey) {
    self.userDefaults.set(nil, forKey: key.keyName)
  }
  
  func setValue(_ value: Any?, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.keyName)
  }
  
  func bool(forKey key: SKKey) -> Bool {
    return self.userDefaults.bool(forKey: key.keyName)
  }
  
  func int(forKey key: SKKey) -> Int {
    return self.userDefaults.integer(forKey: key.keyName)
  }
  
  func json(forKey key: SKKey) -> [String: Any]? {
    return self.userDefaults.object(forKey: key.keyName) as? [String: Any]
  }
  
  func string(forKey key: SKKey) -> String? {
    return self.userDefaults.object(forKey: key.keyName) as? String
  }
  
  func float(forKey key: SKKey) -> Float? {
    return self.userDefaults.object(forKey: key.keyName) as? Float
  }
  
  func data(forKey key: SKKey) -> Data? {
    return self.userDefaults.object(forKey: key.keyName) as? Data
  }
  
  func codable<T: Decodable>(forKey key: SKKey, objectType: T.Type) -> T? {
    
    let decoder = JSONDecoder()
    
    guard let data = self.userDefaults.object(forKey: key.keyName) as? Data,
      let object = try? decoder.decode(T.self, from: data) else {
        return nil
    }
    
    return object
  }
  
  open func codableArray<T>(forKey key: SKKey, objectType: T.Type) -> [T] where T : Decodable {
    guard let dataArray = self.userDefaults.array(forKey: key.keyName) as? [Data] else {
      return []
    }
    
    let objects = dataArray.map { try? JSONDecoder().decode(objectType, from: $0) }.compactMap { $0 }
    
    return objects
  }
}
