//
//  SkarbSDK.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/27/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import UIKit

public class SkarbSDK {
  public static func initialize(clientId: String,
                                isObservable: Bool,
                                deviceId: String? = nil) {
    SKServiceRegistry.initialize(isObservable: isObservable)
    
    let deviceId = deviceId ?? UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    let appStoreReceiptURL = Bundle.main.appStoreReceiptURL
    var dataCount: Int = 0
      if let appStoreReceiptURL = appStoreReceiptURL,
         let recieptData = try? Data(contentsOf: appStoreReceiptURL) {
        dataCount = recieptData.count
    }
    
    let initData = SKInitData(clientId: clientId,
                              deviceId: deviceId,
                              installDate: Formatter.iso8601.string(from: Date()),
                              receiptUrl: appStoreReceiptURL?.absoluteString ?? "",
                              receiptLen: dataCount)
    SKServiceRegistry.userDefaultsService.setData(initData.getData(), forKey: .initData)
    SKServiceRegistry.serverAPI.sendInstall(completion: { _ in })
  }
  
  public static func sendTest(name: String,
                              group: String,
                              completion: @escaping (SKResponseError?) -> Void) {
    SKServiceRegistry.serverAPI.sendTest(name: name, group: group, completion: completion)
  }
  
  public static func sendSource(broker: SKBroker,
                                features: [AnyHashable: Any],
                                completion: @escaping (SKResponseError?) -> Void) {
    SKServiceRegistry.serverAPI.sendSource(broker: broker, features: features, completion: completion)
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
  
  public static func getDeviceId() -> String {
    let initData = SKServiceRegistry.userDefaultsService.codable(forKey: .initData, objectType: SKInitData.self)
    if let deviceId = initData?.deviceId {
      return deviceId
    }
    
    SKLogger.logWarn("SkarbSDK getDeviceId: called and deviceId is nill. Use UUID().uuidString")
    
    return UUID().uuidString
  }
}
