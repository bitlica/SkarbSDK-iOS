//
//  SkarbSDK.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/27/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import UIKit
import StoreKit

public class SkarbSDK {
  
  static let agentName: String = "SkarbSDK"
  static let version: String = "0.4.0"
  
  static var clientId: String = ""
  
  public static func initialize(clientId: String,
                                isObservable: Bool,
                                deviceId: String? = nil) {
    
    SkarbSDK.clientId = clientId
    let deviceId = deviceId ?? UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    
    SKServiceRegistry.initialize(isObservable: isObservable)
    
    SKServiceRegistry.migrationService.doMigrationIfNeeded()
    
    SKServiceRegistry.commandStore.createInstallCommandIfNeeded(clientId: clientId, deviceId: deviceId)
  }
  
  public static func sendTest(name: String,
                              group: String) {
    let testData = SKTestData(name: name, group: group)
    SKServiceRegistry.userDefaultsService.setValue(testData.getData(), forKey: .testData)
    
    let testCommand = SKCommand(commandType: .test,
                                status: .pending,
                                data: SKCommand.prepareAppgateData())
    SKServiceRegistry.commandStore.saveCommand(testCommand)
    
    // V4
    guard SKServiceRegistry.commandStore.hasInstallV4Command else {
      return
    }
    let testRequest = Installapi_TestRequest(name: name, group: group)
    let testV4Command = SKCommand(commandType: .testV4,
                                  status: .pending,
                                  data: testRequest.getData())
    SKServiceRegistry.commandStore.saveCommand(testV4Command)
  }
  
  public static func sendSource(broker: SKBroker,
                                features: [AnyHashable: Any],
                                once: Bool = true) {
    
    if once && SKServiceRegistry.commandStore.hasSendSourceCommand {
      return
    }
    
    let broberData = SKBrokerData(broker: broker.name, features: features)
    SKServiceRegistry.userDefaultsService.setValue(broberData.getData(), forKey: .brokerData)
    
    let sourceCommand = SKCommand(commandType: .source,
                                  status: .pending,
                                  data: SKCommand.prepareAppgateData())
    SKServiceRegistry.commandStore.saveCommand(sourceCommand)
    
    // V4
    guard SKServiceRegistry.commandStore.hasInstallV4Command else {
      return
    }
    let attributionRequest = Installapi_AttribRequest(broker: broker.name, features: features)
    let sourceV4Command = SKCommand(commandType: .sourceV4,
                                    status: .pending,
                                    data: attributionRequest.getData())
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
    
    let purchaseCommand = SKCommand(commandType: .purchase,
                                    status: .pending,
                                    data: SKCommand.prepareAppgateData())
    SKServiceRegistry.commandStore.saveCommand(purchaseCommand)
  }
  
  public static func getDeviceId() -> String {
    guard let deviceId = SKServiceRegistry.userDefaultsService.string(forKey: .deviceId) else {
      SKLogger.logError("SkarbSDK: getDeviceId() - deviceId is nil",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.internalValue.name: "deviceId is nil"])
      return UUID().uuidString
    }
    return deviceId
  }
  
  public static func useAutomaticAppleSearchAdsAttributionCollection(_ enable: Bool) {
    SKServiceRegistry.commandStore.createAutomaticSearchAdsCommand(enable)
  }
  
  public static func purhase(product: SKProduct, completion: (Result<SKPaymentTransaction, SKSkarbError>) -> Void) {
    SKServiceRegistry.storeKitService.purhase(product: product, completion: completion)
  }
}
