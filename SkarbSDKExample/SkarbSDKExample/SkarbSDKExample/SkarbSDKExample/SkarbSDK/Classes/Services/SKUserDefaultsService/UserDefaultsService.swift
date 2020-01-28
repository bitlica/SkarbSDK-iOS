//
//  UserDefaultsService.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 1/22/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

class SKUserDefaultsService {
  enum SKKey {
    case source
    case test
    case paywall
    case price
    case currency
    case requestTypeToSync
    case installedDateISO8601
    case skRequestType(String)
    
    var keyName: String {
      switch self {
        case .source:
          return "sk_source_key"
        case .test:
          return "sk_test_key"
        case .paywall:
          return "sk_paywall_key"
        case .price:
          return "sk_price_key"
        case .currency:
          return "sk_currency_key"
        case .requestTypeToSync:
          return "sk_request_to_sync"
        case .installedDateISO8601:
          return "sk_installed_date_ISO8601"
        case .skRequestType(let name):
          return name
      }
    }
  }
  
  private let userDefaults: UserDefaults
  init() {
    self.userDefaults = UserDefaults.standard
  }
  
  func setValue(_ value: Bool, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.keyName)
  }
  
  func setValue(_ value: Int, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.keyName)
  }
  
  func setValue(_ value: JSONObject, forKey key: SKKey) {
    self.userDefaults.setValue(value, forKey: key.keyName)
  }
  
  func setValue(_ value: String?, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.keyName)
  }
  
  func setValue(_ value: Float, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.keyName)
  }
  
  func bool(forKey key: SKKey) -> Bool {
    return self.userDefaults.bool(forKey: key.keyName)
  }
  
  func int(forKey key: SKKey) -> Int {
    return self.userDefaults.integer(forKey: key.keyName)
  }
  
  func json(forKey key: SKKey) -> JSONObject? {
    return self.userDefaults.object(forKey: key.keyName) as? JSONObject
  }
  
  func string(forKey key: SKKey) -> String? {
    return self.userDefaults.object(forKey: key.keyName) as? String
  }
  
  func float(forKey key: SKKey) -> Float? {
    return self.userDefaults.object(forKey: key.keyName) as? Float
  }
}
