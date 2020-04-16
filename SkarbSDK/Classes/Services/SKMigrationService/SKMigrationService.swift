//
//  SKMigrationService.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 4/16/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

struct SKMigrationService {
  
  func doMigrationIfNeeded() {
    
    let version1: Int = 1
    if !SKServiceRegistry.userDefaultsService.bool(forKey: .migrationVersion(version1)) {
      // isntall
      if let installedDateISO8601 = UserDefaults.standard.string(forKey: "sk_installed_date_ISO8601"),
        let clientId = UserDefaults.standard.string(forKey: "sk_client_id"),
        let deviceId = UserDefaults.standard.string(forKey: "sk_device_id") {
        
        let appStoreReceiptURL = Bundle.main.appStoreReceiptURL
        var dataCount: Int = 0
        if let appStoreReceiptURL = appStoreReceiptURL,
          let recieptData = try? Data(contentsOf: appStoreReceiptURL) {
          dataCount = recieptData.count
        }
        let initData = SKInitData(clientId: clientId,
                                  deviceId: deviceId,
                                  installDate: installedDateISO8601,
                                  receiptUrl: appStoreReceiptURL?.absoluteString ?? "",
                                  receiptLen: dataCount)
        SKServiceRegistry.userDefaultsService.setValue(initData.getData(), forKey: .initData)
      }
      
      if UserDefaults.standard.bool(forKey: "sk_request_type_install") {
        let installCommand = SKAppgateCommand(timestamp: Date().nowTimestampInt,
                                              commandType: .install,
                                              status: .done,
                                              data: SKAppgateCommand.prepareData(),
                                              retryCount: 0)
        SKServiceRegistry.commandStore.saveAppgateCommand(installCommand)
      }
      
      // test
      if let testJSON = UserDefaults.standard.object(forKey: "sk_test_key") as? [String: Any],
        let name = testJSON["name"] as? String,
        let group = testJSON["group"] as? String {
        let testData = SKTestData(name: name, group: group)
        SKServiceRegistry.userDefaultsService.setValue(testData.getData(), forKey: .testData)
        
        if UserDefaults.standard.bool(forKey: "sk_request_type_test") {
          let testCommand = SKAppgateCommand(timestamp: Date().nowTimestampInt,
                                             commandType: .test,
                                             status: .done,
                                             data: SKAppgateCommand.prepareData(),
                                             retryCount: 0)
          SKServiceRegistry.commandStore.saveAppgateCommand(testCommand)
        }
      }
      
      //source
      if let brokerJSONData = UserDefaults.standard.object(forKey: "sk_broker_key") as? Data,
        let brokerJSON = try? JSONSerialization.jsonObject(with: brokerJSONData, options: []) as? [String: Any],
        let brocker = brokerJSON?["broker"] as? String,
        let features = brokerJSON?["features"] as? [AnyHashable: Any] {
        
        let brokerData = SKBrokerData(broker: brocker, features: features)
        SKServiceRegistry.userDefaultsService.setValue(brokerData.getData(), forKey: .brokerData)
        
        if UserDefaults.standard.bool(forKey: "sk_request_type_broker") {
          let sourceCommand = SKAppgateCommand(timestamp: Date().nowTimestampInt,
                                               commandType: .source,
                                               status: .done,
                                               data: SKAppgateCommand.prepareData(),
                                               retryCount: 0)
          SKServiceRegistry.commandStore.saveAppgateCommand(sourceCommand)
        }
      }
      
      //purchase
      if let productId = UserDefaults.standard.string(forKey: "sk_product_id"),
        let currency = UserDefaults.standard.string(forKey: "sk_currency_key") {
        let price = UserDefaults.standard.float(forKey: "sk_price_key")
        
        let purchaseData = SKPurchaseData(productId: productId, price: price, currency: currency)
        SKServiceRegistry.userDefaultsService.setValue(purchaseData.getData(), forKey: .purchaseData)
        
        if UserDefaults.standard.bool(forKey: "sk_request_type_purchase") {
          let purchaseCommand = SKAppgateCommand(timestamp: Date().nowTimestampInt,
                                                 commandType: .purchase,
                                                 status: .done,
                                                 data: SKAppgateCommand.prepareData(),
                                                 retryCount: 0)
          SKServiceRegistry.commandStore.saveAppgateCommand(purchaseCommand)
        }
      }
      
      SKServiceRegistry.commandStore.saveState()
      SKServiceRegistry.userDefaultsService.setValue(true, forKey: .migrationVersion(version1))
    }
  }
}
