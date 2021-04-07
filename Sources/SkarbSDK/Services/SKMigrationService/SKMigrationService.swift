//
//  SKMigrationService.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/16/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import SwiftProtobuf

struct SKMigrationService {
  
  static let schemaVersion: Int = 1
  
  func doMigrationIfNeeded(deviceId: String) {
    
    let oldSchemaVersion = SKServiceRegistry.userDefaultsService.int(forKey: .oldSchemaVersion)
    if oldSchemaVersion < 1 {
      migrateV2ToV3()
      migrateDeviceId(deviceId: deviceId)
      migrateFetchingProducts()
      deleteV4CommandsIfNeeded(needToMigrateVer: "0.4.10")
      migrateInstallCommand()
    }
    
    SKServiceRegistry.userDefaultsService.setValue(SKMigrationService.schemaVersion,
                                                   forKey: .oldSchemaVersion)
  }
  
  private func migrateV2ToV3() {
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
      let installCommand = SKCommand(commandType: .install,
                                     status: .done,
                                     data: SKCommand.prepareAppgateData())
      SKServiceRegistry.commandStore.saveCommand(installCommand)
    }
    
    // test
    if let testJSON = UserDefaults.standard.object(forKey: "sk_test_key") as? [String: Any],
      let name = testJSON["name"] as? String,
      let group = testJSON["group"] as? String {
      let testData = SKTestData(name: name, group: group)
      SKServiceRegistry.userDefaultsService.setValue(testData.getData(), forKey: .testData)
      
      if UserDefaults.standard.bool(forKey: "sk_request_type_test") {
        let testCommand = SKCommand(commandType: .test,
                                    status: .done,
                                    data: SKCommand.prepareAppgateData())
        SKServiceRegistry.commandStore.saveCommand(testCommand)
      }
    }
    
    //source
    if let brokerJSONData = UserDefaults.standard.object(forKey: "sk_broker_key") as? Data,
      let brokerJSON = try? JSONSerialization.jsonObject(with: brokerJSONData, options: []) as? [String: Any],
      let brocker = brokerJSON["broker"] as? String,
      let features = brokerJSON["features"] as? [AnyHashable: Any] {
      
      let brokerData = SKBrokerData(broker: brocker, features: features)
      SKServiceRegistry.userDefaultsService.setValue(brokerData.getData(), forKey: .brokerData)
      
      if UserDefaults.standard.bool(forKey: "sk_request_type_broker") {
        let sourceCommand = SKCommand(commandType: .source,
                                      status: .done,
                                      data: SKCommand.prepareAppgateData())
        SKServiceRegistry.commandStore.saveCommand(sourceCommand)
      }
    }
    
    //purchase
    if let productId = UserDefaults.standard.string(forKey: "sk_product_id"),
      let currency = UserDefaults.standard.string(forKey: "sk_currency_key") {
      let price = UserDefaults.standard.float(forKey: "sk_price_key")
      
      let purchaseData = SKPurchaseData(productId: productId, price: price, currency: currency)
      SKServiceRegistry.userDefaultsService.setValue(purchaseData.getData(), forKey: .purchaseData)
      
      if UserDefaults.standard.bool(forKey: "sk_request_type_purchase") {
        let purchaseCommand = SKCommand(commandType: .purchase,
                                        status: .done,
                                        data: SKCommand.prepareAppgateData())
        SKServiceRegistry.commandStore.saveCommand(purchaseCommand)
      }
    }
    
    SKServiceRegistry.commandStore.saveState()
  }
  
  
  /// Means that user has v3 version and need to store deviceId for V4
  private func migrateDeviceId(deviceId: String) {
    if let initData = SKServiceRegistry.userDefaultsService.codable(forKey: .initData, objectType: SKInitData.self),
       SKServiceRegistry.userDefaultsService.string(forKey: .deviceId) == nil  {
      SKServiceRegistry.userDefaultsService.setValue(initData.deviceId, forKey: .deviceId)
    } else {
      if SKServiceRegistry.userDefaultsService.string(forKey: .deviceId) == nil {
        SKServiceRegistry.userDefaultsService.setValue(deviceId, forKey: .deviceId)
      }
    }
  }
  
  /// Need to migrate SKCommand for fetchProducts from old format
  /// that has only productId field
  private func migrateFetchingProducts() {
    let fetchProductsCommands = SKServiceRegistry.commandStore.getAllCommands(by: .fetchProducts)
    if !fetchProductsCommands.isEmpty {
      let decoder = JSONDecoder()
      for command in fetchProductsCommands {
        if (try? decoder.decode(Array<SKFetchProduct>.self, from: command.data)) != nil {
          continue
        }
        guard let productIds = String(data: command.data, encoding: .utf8) else {
          continue
        }
        var fetchProducts: [SKFetchProduct] = []
        var editedCommand = command
        
        for productId in productIds.components(separatedBy: ",") {
          let fetchProduct = SKFetchProduct(productId: productId, transactionDate: nil, transactionId: nil)
          fetchProducts.append(fetchProduct)
        }
        let encoder = JSONEncoder()
        if let fetchProductsData = try? encoder.encode(fetchProducts) {
          editedCommand.updateData(fetchProductsData)
          SKServiceRegistry.commandStore.saveCommand(editedCommand)
        }
      }
    }
  }
  
  /// Need to delete all events if SDK version is lower needToMigrateVer
  /// Current version can be parsed from Installapi_DeviceRequest.auth.agentVer
  private func deleteV4CommandsIfNeeded(needToMigrateVer: String) {
    let decoder = JSONDecoder()
    if let installCommand = SKServiceRegistry.commandStore.getAllCommands(by: .installV4).first,
       let deviceRequest = try? decoder.decode(Installapi_DeviceRequest.self, from: installCommand.data),
       compareNumeric(deviceRequest.auth.agentVer, needToMigrateVer) == .orderedAscending {
      SKServiceRegistry.commandStore.deleteAllCommand(by: .installV4)
      SKServiceRegistry.commandStore.deleteAllCommand(by: .sourceV4)
      SKServiceRegistry.commandStore.deleteAllCommand(by: .testV4)
      SKServiceRegistry.commandStore.deleteAllCommand(by: .purchaseV4)
      SKServiceRegistry.commandStore.deleteAllCommand(by: .transactionV4)
      SKServiceRegistry.commandStore.deleteAllCommand(by: .priceV4)
    }
  }
  
  /// Need to add sdkInitDate for old users
  private func migrateInstallCommand() {
    let commands = SKServiceRegistry.commandStore.getAllCommands(by: .installV4)
    let decoder = JSONDecoder()
    for command in commands {
      if let deviceRequest = try? decoder.decode(Installapi_DeviceRequest.self, from: command.data) {
        var updatedDeviceRequest = deviceRequest
        updatedDeviceRequest.sdkInitDate = SwiftProtobuf.Google_Protobuf_Timestamp(timeIntervalSince1970: TimeInterval(command.timestamp / 1000000)) // command.timestamp - micsoSec
        var updatedCommand = command
        if let updatedData = updatedDeviceRequest.getData() {
          updatedCommand.updateData(updatedData)
          SKServiceRegistry.commandStore.deleteCommand(command)
          SKServiceRegistry.commandStore.saveCommand(updatedCommand)
        }
      }
    }
  }
  
  private func compareNumeric(_ version1: String, _ version2: String) -> ComparisonResult {
    return version1.compare(version2, options: .numeric)
  }
}
