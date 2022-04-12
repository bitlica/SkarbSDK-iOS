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
  
  static let agentName: String = "SkarbSDK-iOS"
  static let version: String = "0.5.5"
  
  static var clientId: String = ""
  public static var isLoggingEnabled: Bool = false
  public static var automaticCollectIDFA: Bool = true
  
  public static func initialize(clientId: String,
                                isObservable: Bool,
                                deviceId: String? = nil) {
    
    SkarbSDK.clientId = clientId
    let deviceId = deviceId ?? generateDeviceId()
    
    // Order is matter:
    // needs to be sure that install command data exists always
    // because some data are used in other commands and should not be nil
    SKServiceRegistry.migrationService.doMigrationIfNeeded(deviceId: deviceId)
    SKServiceRegistry.commandStore.createInstallCommandIfNeeded(clientId: clientId, deviceId: deviceId)
    SKServiceRegistry.commandStore.createIDFACommandIfNeeded(automaticCollectIDFA: automaticCollectIDFA)
    SKServiceRegistry.commandStore.createSKANCommandIfNeeded()
    SKServiceRegistry.initialize(isObservable: isObservable)
  }
  
  public static func sendTest(name: String,
                              group: String) {
    //    V3
    if !SKServiceRegistry.commandStore.hasTestCommand {
      let testData = SKTestData(name: name, group: group)
      SKServiceRegistry.userDefaultsService.setValue(testData.getData(), forKey: .testData)
      
      let testCommand = SKCommand(commandType: .test,
                                  status: .pending,
                                  data: SKCommand.prepareAppgateData())
      SKServiceRegistry.commandStore.saveCommand(testCommand)
    }
    
    // V4
    if !SKServiceRegistry.commandStore.hasTestV4Command {
      let testRequest = Installapi_TestRequest(name: name, group: group)
      let testV4Command = SKCommand(commandType: .testV4,
                                    status: .pending,
                                    data: testRequest.getData())
      SKServiceRegistry.commandStore.saveCommand(testV4Command)
    }
  }
  
  public static func sendSource(broker: SKBroker,
                                features: [AnyHashable: Any]) {
    //    V3
    if !SKServiceRegistry.commandStore.hasSendSourceCommand {
      let broberData = SKBrokerData(broker: broker.name, features: features)
      SKServiceRegistry.userDefaultsService.setValue(broberData.getData(), forKey: .brokerData)
      
      let sourceCommand = SKCommand(commandType: .source,
                                    status: .pending,
                                    data: SKCommand.prepareAppgateData())
      SKServiceRegistry.commandStore.saveCommand(sourceCommand)
    }
    
    // V4
    if !SKServiceRegistry.commandStore.hasSendSourceV4Command(broker: broker) {
      let attributionRequest = Installapi_AttribRequest(broker: broker.name, features: features)
      let sourceV4Command = SKCommand(commandType: .sourceV4,
                                      status: .pending,
                                      data: attributionRequest.getData())
      SKServiceRegistry.commandStore.saveCommand(sourceV4Command)
    }
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
    
    let purchaseCommand = SKCommand(commandType: .purchase,
                                    status: .pending,
                                    data: SKCommand.prepareAppgateData())
    SKServiceRegistry.commandStore.saveCommand(purchaseCommand)
  }
  
  public static func getDeviceId() -> String {
    guard let deviceId = SKServiceRegistry.userDefaultsService.string(forKey: .deviceId) else {
      let deviceId = generateDeviceId()
      SKServiceRegistry.userDefaultsService.setValue(deviceId, forKey: .deviceId)
      SKLogger.logError("SkarbSDK: getDeviceId() - deviceId is nil",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.internalValue.name: "deviceId is nil"])
      return deviceId
    }
    return deviceId
  }
  
  public static func useAutomaticAppleSearchAdsAttributionCollection(_ enable: Bool) {
    SKServiceRegistry.commandStore.createAutomaticSearchAdsCommand(enable)
  }
  
  public static func sendIDFA(idfa: String?) {
    guard !SKServiceRegistry.commandStore.hasIDFACommand else {
      return
    }
    
    let attributionRequest = Installapi_IDFARequest(idfa: idfa)
    let idfaV4Command = SKCommand(commandType: .idfaV4,
                                  status: .pending,
                                  data: attributionRequest.getData())
    SKServiceRegistry.commandStore.saveCommand(idfaV4Command)
  }
  
//  MARK: Private
  private static func generateDeviceId() -> String {
    return UUID().uuidString
  }
}
