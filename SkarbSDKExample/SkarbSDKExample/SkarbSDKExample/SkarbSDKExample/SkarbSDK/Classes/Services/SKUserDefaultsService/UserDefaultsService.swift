//
//  UserDefaultsService.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 1/22/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

class SKUserDefaultsService {
  enum SKKey: String {
    case source = "sk_source_key"
    case test = "sk_test_key"
    case paywall = "sk_paywall_key"
    case price = "sk_price_key"
    case currency = "sk_currency_key"
    case requestTypeToSync = "sk_request_to_sync"
    case installedDateISO8601 = "sk_installed_date_ISO8601"
  }
  
  private let userDefaults: UserDefaults
  init() {
    self.userDefaults = UserDefaults.standard
  }
  
  func setValue(_ value: Bool, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.rawValue)
  }
  
  func setValue(_ value: Int, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.rawValue)
  }
  
  func setValue(_ value: JSONObject, forKey key: SKKey) {
    self.userDefaults.setValue(value, forKey: key.rawValue)
  }
  
  func setValue(_ value: String?, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.rawValue)
  }
  
  func setValue(_ value: Float, forKey key: SKKey) {
    self.userDefaults.set(value, forKey: key.rawValue)
  }
  
  func bool(forKey key: SKKey) -> Bool {
    return self.userDefaults.bool(forKey: key.rawValue)
  }
  
  func int(forKey key: SKKey) -> Int {
    return self.userDefaults.integer(forKey: key.rawValue)
  }
  
  func json(forKey key: SKKey) -> JSONObject? {
    return self.userDefaults.object(forKey: key.rawValue) as? JSONObject
  }
  
  func string(forKey key: SKKey) -> String? {
    return self.userDefaults.object(forKey: key.rawValue) as? String
  }
  
  func float(forKey key: SKKey) -> Float? {
    return self.userDefaults.object(forKey: key.rawValue) as? Float
  }
}
