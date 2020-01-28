//
//  SkarbSDK.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 1/27/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

class SkarbSDK {
  static func initialize(clientId: String) {
    // TODO: Save clientId later
    SKServiceRegistry.initialize()
    SKServiceRegistry.serverAPI.sendInstall(completion: { _ in })
  }
  
  static func sendTest(name: String, group: String, completion: @escaping (SKResponseError?) -> Void) {
    SKServiceRegistry.serverAPI.sendTest(name: name, group: group, completion: completion)
  }
  
  static func sendSource(source: SKSource, features: JSONObject, completion: @escaping (SKResponseError?) -> Void) {
    SKServiceRegistry.serverAPI.sendSource(source: source, features: features, completion: completion)
  }
  
  static func sendPurchase(paywall: String, price: Float, currency: String, completion: @escaping (SKResponseError?) -> Void) {
    SKServiceRegistry.serverAPI.sendPurchase(paywall: paywall, price: price, currency: currency, completion: completion)
  }
}
