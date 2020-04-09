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
    case broker
    case test
    case purchaseData
    
    case appgateComands
    
    case requestTypeToSync
    case fetchAllProductsAndSync
    case purchaseSentBySwizzling
    case skRequestType(String)
    
    var keyName: String {
      switch self {
        case .initData:
          return "sk_init_data"
        case .broker:
          return "sk_broker_key"
        case .test:
          return "sk_test_key"
        case .purchaseData:
          return "sk_purchase_data"
        
        case .appgateComands:
          return "sk_appgate_commands"
        
        case .requestTypeToSync:
          return "sk_request_to_sync"
        case .fetchAllProductsAndSync:
          return "sk_fetch_all_products_and_sync"
        case .purchaseSentBySwizzling:
          return "sk_purchase_sent_by_swizzling"
        case .skRequestType(let name):
          return name
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
  
  func setBool(_ value: Bool, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.keyName)
  }
  
  func setInt(_ value: Int, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.keyName)
  }
  
  func setJSON(_ value: [String: Any], forKey key: SKKey) {
    self.userDefaults.setValue(value, forKey: key.keyName)
  }
  
  func setString(_ value: String, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.keyName)
  }
  
  func setFloat(_ value: Float, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.keyName)
  }
  
  func setData(_ value: Data?, forKey key: SKKey) {
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
}
