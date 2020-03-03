//
//  SkarbSDK.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 1/27/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

class SkarbSDK {
  public static func initialize(clientId: String, isObservable: Bool, isDebug: Bool) {
    SKServiceRegistry.initialize(isObservable: isObservable)
    SKServiceRegistry.userDefaultsService.setValue(clientId, forKey: .clientId)
    SKServiceRegistry.userDefaultsService.setValue(isDebug, forKey: .env)
    SKServiceRegistry.serverAPI.sendInstall(completion: { _ in })
  }
  
  public static func sendTest(name: String,
                       group: String,
                       completion: @escaping (SKResponseError?) -> Void) {
    SKServiceRegistry.serverAPI.sendTest(name: name, group: group, completion: completion)
  }
  
  public static func sendSource(source: SKSource,
                         features: [String: Any],
                         completion: @escaping (SKResponseError?) -> Void) {
    SKServiceRegistry.serverAPI.sendSource(source: source, features: features, completion: completion)
  }
  
  public static func sendPurchase(productId: String,
                           price: Float? = nil,
                           currency: String? = nil,
                           completion: ((SKResponseError?) -> Void)? = nil) {
    SKServiceRegistry.serverAPI.sendPurchase(productId: productId,
                                             price: price,
                                             currency: currency,
                                             completion: completion)
  }
}