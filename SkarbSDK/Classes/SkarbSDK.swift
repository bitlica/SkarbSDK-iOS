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
    
    if SKServiceRegistry.userDefaultsService.codable(forKey: .initData, objectType: SKInitData.self) == nil {
      let deviceId = deviceId ?? UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
      let installDate = Formatter.iso8601.string(from: Date())
      let appStoreReceiptURL = Bundle.main.appStoreReceiptURL
      var dataCount: Int = 0
      if let appStoreReceiptURL = appStoreReceiptURL,
        let recieptData = try? Data(contentsOf: appStoreReceiptURL) {
        dataCount = recieptData.count
      }
      
      let initData = SKInitData(clientId: clientId,
                                deviceId: deviceId,
                                installDate: installDate,
                                receiptUrl: appStoreReceiptURL?.absoluteString ?? "",
                                receiptLen: dataCount)
      SKServiceRegistry.userDefaultsService.setValue(initData.getData(), forKey: .initData)
    }
    
    guard !SKServiceRegistry.commandStore.hasInstallCommand else {
      return
    }
    let installCommand = SKCommand(timestamp: Date().nowTimestampInt,
                                   commandType: .install,
                                   status: .pending,
                                   data: SKCommand.prepareAppgateData(),
                                   retryCount: 0)
    SKServiceRegistry.commandStore.saveCommand(installCommand)
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
                                features: [AnyHashable: Any]) {
    let broberData = SKBrokerData(broker: broker.name, features: features)
    SKServiceRegistry.userDefaultsService.setValue(broberData.getData(), forKey: .brokerData)
    
    let sourceCommand = SKCommand(timestamp: Date().nowTimestampInt,
                                  commandType: .source,
                                  status: .pending,
                                  data: SKCommand.prepareAppgateData(),
                                  retryCount: 0)
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
}
