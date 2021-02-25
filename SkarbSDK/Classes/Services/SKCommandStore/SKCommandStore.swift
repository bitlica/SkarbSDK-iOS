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
  
  func hasSendSourceV4Command(broker: SKBroker) -> Bool {
    var result = false
    let decoder = JSONDecoder()
    exclusionSerialQueue.sync {
      let allSourceCommands = localAppgateCommands.filter { $0.commandType == .sourceV4 }
      for sourceCommand in allSourceCommands {
        if let attribRequest = try? decoder.decode(Installapi_AttribRequest.self, from: sourceCommand.data),
           attribRequest.broker == broker.name {
          result = true
          break
        }
      }
    }
    return result
  }
  
  var hasTestCommand: Bool {
    var result = false
    exclusionSerialQueue.sync {
      result = localAppgateCommands.first(where: { $0.commandType == .test }) != nil
    }
    return result
  }
  
  var hasTestV4Command: Bool {
    var result = false
    exclusionSerialQueue.sync {
      result = localAppgateCommands.first(where: { $0.commandType == .testV4 }) != nil
    }
    return result
  }
  
  func saveCommand(_ command: SKCommand) {
    var isNew: Bool = false
    exclusionSerialQueue.sync {
      if let existingCommand = localAppgateCommands.first(where: { $0 == command }),
         let index = localAppgateCommands.firstIndex(where: { $0 == existingCommand }) {
        // Case might occurs when one more command was sent after timeout
        // and the previous was successful finished with status done
        // but the new was finished with failure and the status will be pending
        if !(existingCommand.status == .done && command.status == .pending) {
          localAppgateCommands[index] = command
        }
      } else {
        localAppgateCommands.append(command)
        isNew = true
      }
    }
    // if new command was added we want to execute all pending
    // commands ASAP in one transaction
    if isNew {
      resetFireDateAndRetryCountForPendingCommands()
      SKServiceRegistry.syncService.syncAllCommands()
    }
    saveState()
    SKLogger.logInfo("Command saved: \(command.description)")
  }
  
  func deleteCommand(_ command: SKCommand) {
    SKLogger.logInfo("deleteCommand: commandType = \(command.commandType), status = \(command.status)")
    exclusionSerialQueue.sync {
      localAppgateCommands.removeAll { $0 == command }
    }
    saveState()
  }
  
  func deleteAllCommand(by commandType: SKCommandType) {
    SKLogger.logInfo("delete all commands: commandType = \(commandType)")
    let deleteCommands = getAllCommands(by: commandType)
    exclusionSerialQueue.sync {
      for command in deleteCommands {
        localAppgateCommands.removeAll { $0 == command }
      }
    }
    saveState()
  }
  
  func saveState() {
    SKLogger.logInfo("SKCommandStore saveState: called")
    exclusionSerialQueue.sync {
      let data = localAppgateCommands.map { $0.getData() }.compactMap { $0 }
      SKServiceRegistry.userDefaultsService.setValue(data, forKey: .appgateComands)
    }
  }
  
  func getCommandsForExecuting() -> [SKCommand] {
    var result: [SKCommand] = []
    exclusionSerialQueue.sync {
      result = localAppgateCommands.filter({ $0.status == .pending && $0.fireDate <= Date() })
    }
    return result
  }
  
  func getAllCommands(by commandType: SKCommandType) -> [SKCommand] {
    var result: [SKCommand] = []
    exclusionSerialQueue.sync {
      result = localAppgateCommands.filter({ $0.commandType == commandType })
    }
    return result
  }
  
  func getAllCommands(by status: SKCommandStatus) -> [SKCommand] {
    var result: [SKCommand] = []
    exclusionSerialQueue.sync {
      result = localAppgateCommands.filter({ $0.status == status })
    }
    return result
  }
  
  func getDeviceRequest() -> Installapi_DeviceRequest? {
    var result: Installapi_DeviceRequest? = nil
    let decoder = JSONDecoder()
    exclusionSerialQueue.sync {
      let allSourceCommands = localAppgateCommands.filter { $0.commandType == .installV4 }
      if allSourceCommands.count > 1 {
        SKLogger.logError("getInstallV4Data has more than one install",
                          features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                     SKLoggerFeatureType.internalValue.name: "getInstallV4Data has more than one install"])
      }
      if let installData = allSourceCommands.first?.data,
         let deviceRequest = try? decoder.decode(Installapi_DeviceRequest.self, from: installData) {
        result = deviceRequest
      }
    }
    return result
  }
  
  func getNewTransactionIds(_ transactions: [String]) -> [String] {
    let currentTransactionCommands = getAllCommands(by: .transactionV4)
    
    let decoder = JSONDecoder()
    var existing: Set<String> = []
    for command in currentTransactionCommands {
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
    
//    V3
    if !SKServiceRegistry.commandStore.hasInstallCommand,
       SKServiceRegistry.userDefaultsService.codable(forKey: .initData, objectType: SKInitData.self) == nil {
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
    }
    
//    V4
    if !SKServiceRegistry.commandStore.hasInstallV4Command {
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
    
    let searchAdsCommand = SKCommand(commandType: .automaticSearchAds,
                                   status: .pending,
                                   data: Data())
    SKServiceRegistry.commandStore.saveCommand(searchAdsCommand)
  }
  
  func resetFireDateAndRetryCountForPendingCommands() {
    let commands: [SKCommand] = getAllCommands(by: .pending)
    for command in commands {
      var editedCommand = command
      editedCommand.updateFireDate(Date())
      editedCommand.resetRetryCount()
      saveCommand(editedCommand)
    }
  }
  
  func checkInProgressCommandsTimeout() {
    let requestTimeout: TimeInterval = 60
    let commands: [SKCommand] = getAllCommands(by: .inProgress)
      .filter { $0.fireDate.addingTimeInterval(requestTimeout) <= Date() }
    for command in commands {
      var editedCommand = command
      editedCommand.updateRetryCountAndFireDate()
      editedCommand.changeStatus(to: .pending)
      saveCommand(editedCommand)
    }
  }
}
