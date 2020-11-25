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
  
  static var clientId: String = ""
  static var deviceId: String = ""
  
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
    
    // V4
    guard !SKServiceRegistry.commandStore.hasInstallV4Command else {
      return
    }
    
//    TODO: Add later
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
    
    // V4
    guard SKServiceRegistry.commandStore.hasInstallV4Command else {
      return
    }
    let attributionRequest = Apiinstall_AttribRequest(broker: broker.name, features: features)
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
    
    guard !SKServiceRegistry.commandStore.hasPurhcaseCommand else {
      return
    }
    
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
    return deviceId
  }
  
  public static func useAutomaticAppleSearchAdsAttributionCollection(_ enable: Bool) {
    SKServiceRegistry.commandStore.createAutomaticSearchAdsCommand(enable)
  }
}
