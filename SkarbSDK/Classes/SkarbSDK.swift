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
    
    SKServiceRegistry.migrationService.doMigrationIfNeeded()
    
    SKServiceRegistry.commandStore.createInstallCommandIfNeeded(clientId: clientId, deviceId: deviceId)
  }
  
  public static func sendTest(name: String,
                              group: String) {
    let testData = SKTestData(name: name, group: group)
    SKServiceRegistry.userDefaultsService.setValue(testData.getData(), forKey: .testData)
    
    let testCommand = SKCommand(timestamp: Date().nowTimestampInt,
                                commandType: .test,
                                status: .pending,
                                data: SKCommand.prepareAppgateData(),
                                retryCount: 0)
    SKServiceRegistry.commandStore.saveCommand(testCommand)
  }
  
  public static func sendSource(broker: SKBroker,
                                features: [AnyHashable: Any],
                                once: Bool = true) {
    let broberData = SKBrokerData(broker: broker.name, features: features)
    SKServiceRegistry.userDefaultsService.setValue(broberData.getData(), forKey: .brokerData)
    
    let sourceCommand = SKCommand(timestamp: Date().nowTimestampInt,
                                  commandType: .source,
                                  status: .pending,
                                  data: SKCommand.prepareAppgateData(),
                                  retryCount: 0)
    if once && SKServiceRegistry.commandStore.hasSendSourceCommand {
      return
    }
    SKServiceRegistry.commandStore.saveCommand(sourceCommand)
  }
  
  public static func sendPurchase(productId: String,
                                  price: Float,
                                  currency: String) {
    let purchaseData = SKPurchaseData(productId: productId,
                                      price: price,
                                      currency: currency)
    SKServiceRegistry.userDefaultsService.setValue(purchaseData.getData(), forKey: .purchaseData)
    
    let purchaseCommand = SKCommand(timestamp: Date().nowTimestampInt,
                                    commandType: .purchase,
                                    status: .pending,
                                    data: SKCommand.prepareAppgateData(),
                                    retryCount: 0)
    SKServiceRegistry.commandStore.saveCommand(purchaseCommand)
  }
  
  public static func getDeviceId() -> String {
    let initData = SKServiceRegistry.userDefaultsService.codable(forKey: .initData, objectType: SKInitData.self)
    if let deviceId = initData?.deviceId {
      return deviceId
    }
    
    SKLogger.logWarn("SkarbSDK getDeviceId: called and deviceId is nill. Use UUID().uuidString",
                     features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
    
    return UUID().uuidString
  }
  
  public static func useAutomaticAppleSearchAdsAttributionCollection(_ enable: Bool) {
    SKServiceRegistry.commandStore.createAutomaticSearchAdsCommand(enable)
  }
}
