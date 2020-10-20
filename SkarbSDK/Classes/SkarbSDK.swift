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
  
  static let agentName: String = "SkarbSDK"
  static let version: String = "0.4.0"
  
  private static var clientId: String = ""
  private static var deviceId: String = ""
  
  public static func initialize(clientId: String,
                                isObservable: Bool,
                                deviceId: String? = nil) {
    
    SkarbSDK.clientId = clientId
    let deviceId = deviceId ?? UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    SkarbSDK.deviceId = deviceId
    
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
    
    if once && SKServiceRegistry.commandStore.hasSendSourceCommand {
      return
    }
    
    let broberData = SKBrokerData(broker: broker.name, features: features)
    SKServiceRegistry.userDefaultsService.setValue(broberData.getData(), forKey: .brokerData)
    
    let sourceCommand = SKCommand(timestamp: Date().nowTimestampInt,
                                  commandType: .source,
                                  status: .pending,
                                  data: SKCommand.prepareAppgateData(),
                                  retryCount: 0)
    SKServiceRegistry.commandStore.saveCommand(sourceCommand)
    
    let attributionRequest = Api_AttribRequest.with {
      let authData = Api_Auth.with {
        $0.key = SkarbSDK.clientId
        $0.bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        $0.agentName = SkarbSDK.agentName
        $0.agentVer = SkarbSDK.version
      }
      $0.auth = authData
      $0.installID = SkarbSDK.deviceId
      $0.broker = broker.name
      if let payloadData = try? JSONSerialization.data(withJSONObject: features, options: .prettyPrinted) {
        $0.payload = payloadData
      }
    }
    SKServiceRegistry.userDefaultsService.setValue(attributionRequest.getData(), forKey: .brokerDataV4)
    let sourceV4Command = SKCommand(timestamp: Date().nowTimestampInt,
                                    commandType: .sourceV4,
                                    status: .pending,
                                    data: attributionRequest.getData() ?? Data(),
                                    retryCount: 0)
    SKServiceRegistry.commandStore.saveCommand(sourceV4Command)
    
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
