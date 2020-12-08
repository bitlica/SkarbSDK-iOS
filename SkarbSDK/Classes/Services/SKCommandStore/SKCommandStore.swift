//
//  SKCommandStore.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/8/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

class SKCommandStore {
  
  private let exclusionSerialQueue = DispatchQueue(label: "com.bitlica.skcommandStore.exclusion")
  
  private var localAppgateCommands: [SKCommand]
  
  init() {
    localAppgateCommands = SKServiceRegistry.userDefaultsService.codableArray(forKey: .appgateComands, objectType: SKCommand.self)
  }
  
  var hasInstallCommand: Bool {
    var result = false
    exclusionSerialQueue.sync {
      result = localAppgateCommands.first(where: { $0.commandType == .install }) != nil
    }
    return result
  }

  var hasInstallV4Command: Bool {
    var result = false
    exclusionSerialQueue.sync {
      result = localAppgateCommands.first(where: { $0.commandType == .installV4 }) != nil
    }
    return result
  }
  
  var hasPurhcaseCommand: Bool {
    var result = false
    exclusionSerialQueue.sync {
      result = localAppgateCommands.first(where: { $0.commandType == .purchase }) != nil
    }
    return result
  }
  
  var hasPurhcaseV4Command: Bool {
    var result = false
    exclusionSerialQueue.sync {
      result = localAppgateCommands.first(where: { $0.commandType == .purchaseV4 }) != nil
    }
    return result
  }
  
  var hasAutomaticSearchAdsCommand: Bool {
    var result = false
    exclusionSerialQueue.sync {
      result = localAppgateCommands.first(where: { $0.commandType == .automaticSearchAds }) != nil
    }
    return result
  }
  
  var hasSendSourceCommand: Bool {
    var result = false
    exclusionSerialQueue.sync {
      result = localAppgateCommands.first(where: { $0.commandType == .source }) != nil
    }
    return result
  }
  
  func saveCommand(_ command: SKCommand) {
    SKLogger.logInfo("saveCommand: commandType = \(command.commandType), status = \(command.status)")
    exclusionSerialQueue.sync {
      if let existingCommand = localAppgateCommands.first(where: { $0 == command }),
         let index = localAppgateCommands.firstIndex(where: { $0 == existingCommand }) {
        localAppgateCommands[index] = command
      } else {
        localAppgateCommands.append(command)
      }
    }
    saveState()
  }
  
  func deleteCommand(_ command: SKCommand) {
    SKLogger.logInfo("deleteCommand: commandType = \(command.commandType), status = \(command.status)")
    exclusionSerialQueue.sync {
      localAppgateCommands.removeAll { $0 == command }
    }
    saveState()
  }
  
  func saveState() {
    SKLogger.logInfo("SKCommandStore saveState: called")
    exclusionSerialQueue.sync {
      let data = localAppgateCommands.map { try? JSONEncoder().encode($0) }
      SKServiceRegistry.userDefaultsService.setValue(data, forKey: .appgateComands)
    }
  }
  
  func getPendingCommands() -> [SKCommand] {
    var result: [SKCommand] = []
    exclusionSerialQueue.sync {
      result = localAppgateCommands.filter({ $0.status == .pending })
    }
    return result
  }
  
  /// when user terminate app or go to background some commands might be inProgress
  /// and there is no guarantee that command will be handled by the app
  func markAllInProgressAsPendingAndSave() {
    var result: [SKCommand] = []
    exclusionSerialQueue.sync {
      result = localAppgateCommands.filter({ $0.status == .inProgress })
    }
    
    for command in result {
      var inProgress = command
      inProgress.changeStatus(to: .pending)
      saveCommand(command)
    }
  }
  
  func getNewTransactionIds(_ transactions: [String]) -> [String] {
    var result: [SKCommand] = []
    exclusionSerialQueue.sync {
      result = localAppgateCommands.filter({ $0.commandType == .transactionV4 })
    }
    
    let decoder = JSONDecoder()
    var existing: Set<String> = []
    for command in result {
      if let transaction = try? decoder.decode(Purchaseapi_TransactionsRequest.self, from: command.data) {
        transaction.transactions.forEach { transactionId in
          existing.insert(transactionId)
        }
      }
    }
    
    var newTransactions: Set<String> = []
    for transaction in transactions {
      if !existing.contains(transaction) {
        newTransactions.insert(transaction)
      }
    }
    
    return Array(newTransactions)
  }
  
  func createInstallCommandIfNeeded(clientId: String, deviceId: String) {
    
    guard !SKServiceRegistry.commandStore.hasInstallCommand else {
      return
    }
    
    if SKServiceRegistry.userDefaultsService.codable(forKey: .initData, objectType: SKInitData.self) == nil {
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
      
      let installCommand = SKCommand(commandType: .install,
                                     status: .pending,
                                     data: SKCommand.prepareAppgateData())
      SKServiceRegistry.commandStore.saveCommand(installCommand)
      
      // Logic for V4 - if user has v3 then v4 install command will not be created and executed
      // Need to create v4 install command only for new users for clean tests.
      // V4
      let initDataV4 = Installapi_DeviceRequest(clientId: clientId, deviceId: deviceId)
      let installCommandV4 = SKCommand(commandType: .installV4,
                                       status: .pending,
                                       data: initDataV4.getData())
      SKServiceRegistry.commandStore.saveCommand(installCommandV4)
      
      if SKServiceRegistry.userDefaultsService.string(forKey: .deviceId) == nil {
        SKServiceRegistry.userDefaultsService.setValue(deviceId, forKey: .deviceId)
      }
    }
  }
  
  func createAutomaticSearchAdsCommand(_ enable: Bool) {
    
    guard enable else {
      var automaticSearchAdsCommand: SKCommand? = nil
      exclusionSerialQueue.sync {
        automaticSearchAdsCommand = localAppgateCommands.filter({ $0.commandType == .automaticSearchAds }).first
      }
      if let automaticSearchAdsCommand = automaticSearchAdsCommand {
        deleteCommand(automaticSearchAdsCommand)
      }
      return
    }
    
    guard !hasAutomaticSearchAdsCommand else {
      return
    }
    
    let installCommand = SKCommand(commandType: .automaticSearchAds,
                                   status: .pending,
                                   data: Data())
    SKServiceRegistry.commandStore.saveCommand(installCommand)
  }
}
