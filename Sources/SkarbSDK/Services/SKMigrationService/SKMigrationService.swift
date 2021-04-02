//
//  SKMigrationService.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/16/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

struct SKMigrationService {
  
  func doMigrationIfNeeded() {
    
    // Means that user has v3 version and need to store deviceId for V4
    if let initData = SKServiceRegistry.userDefaultsService.codable(forKey: .initData, objectType: SKInitData.self),
       SKServiceRegistry.userDefaultsService.string(forKey: .deviceId) == nil  {
      SKServiceRegistry.userDefaultsService.setValue(initData.deviceId, forKey: .deviceId)
    }
    
    // Need to migrate SKCommand for fetchProducts from old format
    // that has only productId field
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
    
    // Need to delete all events if SDK version is lower than 0.4.7
    // Current version can be parsed from Installapi_DeviceRequest.auth.agentVer
    let needToMigrateVer = "0.4.7"
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
  
  private func compareNumeric(_ version1: String, _ version2: String) -> ComparisonResult {
    return version1.compare(version2, options: .numeric)
  }
}
