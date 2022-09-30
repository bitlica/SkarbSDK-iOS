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
  
  func doMigrationIfNeeded() {
    
    let oldSchemaVersion = SKServiceRegistry.userDefaultsService.int(forKey: .oldSchemaVersion)
    if oldSchemaVersion < 1 {
      migrateFetchingProducts()
      migrateInstallCommand()
    }
    
    SKServiceRegistry.userDefaultsService.setValue(SKMigrationService.schemaVersion,
                                                   forKey: .oldSchemaVersion)
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
  
  /// Need to add sdkInitDate for old users
  private func migrateInstallCommand() {
    let commands = SKServiceRegistry.commandStore.getAllCommands(by: .installV4)
    let decoder = JSONDecoder()
    for command in commands {
      if let deviceRequest = try? decoder.decode(Installapi_DeviceRequest.self, from: command.data) {
        var updatedDeviceRequest = deviceRequest
        updatedDeviceRequest.installID = SkarbSDK.getDeviceId()
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
