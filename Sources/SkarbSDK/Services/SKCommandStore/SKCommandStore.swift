//
//  SKCommandStore.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/8/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

class SKCommandStore {
  
  /// Commands that belong to one install: each carries the device id it was created with,
  /// and most of them double as a "sent once per install" marker.
  /// Purchase-related types are deliberately not here - they survive a device id reset.
  private static let deviceScopedCommandTypes: Set<SKCommandType> = [
    .installV4, .sourceV4, .testV4, .idfaV4, .fetchIdfa, .automaticSearchAds, .logging
  ]
  
  private let exclusionSerialQueue = DispatchQueue(label: "com.bitlica.skcommandStore.exclusion")
  
  private var localAppgateCommands: [SKCommand]
  
  /// Commands removed by `dropDeviceScopedCommands()`. A request that was in flight
  /// at that moment still calls `saveCommand` on completion, and must not bring its command back.
  /// In memory only: no request outlives the process.
  private var droppedCommands: Set<SKCommand> = []
  
  private let userDefaultsService: SKUserDefaultsService
  private let syncAllCommands: () -> Void
  
  init(userDefaultsService: SKUserDefaultsService = SKServiceRegistry.userDefaultsService,
       syncAllCommands: @escaping () -> Void = { SKServiceRegistry.syncService.syncAllCommands() }) {
    self.userDefaultsService = userDefaultsService
    self.syncAllCommands = syncAllCommands
    localAppgateCommands = userDefaultsService.codableArray(forKey: .appgateComands, objectType: SKCommand.self)
  }
  
  var hasInstallV4Command: Bool {
    var result = false
    exclusionSerialQueue.sync {
      result = localAppgateCommands.first(where: { $0.commandType == .installV4 }) != nil
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
  
  var hasIDFACommand: Bool {
    var result = false
    exclusionSerialQueue.sync {
      result = localAppgateCommands.first(where: { $0.commandType == .idfaV4 }) != nil
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
  
  var hasTestV4Command: Bool {
    var result = false
    exclusionSerialQueue.sync {
      result = localAppgateCommands.first(where: { $0.commandType == .testV4 }) != nil
    }
    return result
  }
  
  func saveCommand(_ command: SKCommand) {
    var isNew: Bool = false
    var isDropped: Bool = false
    exclusionSerialQueue.sync {
      if let existingCommand = localAppgateCommands.first(where: { $0 == command }),
         let index = localAppgateCommands.firstIndex(where: { $0 == existingCommand }) {
        // Case might occurs when one more command was sent after timeout
        // and the previous was successful finished with status done
        // but the new was finished with failure and the status will be pending
        if !(existingCommand.status == .done && command.status == .pending) {
          localAppgateCommands[index] = command
        }
      } else if !droppedCommands.isEmpty, // skips hashing the payload (a receipt, say) on every save
                droppedCommands.contains(command) {
        // Finished after `dropDeviceScopedCommands()` removed it
        isDropped = true
      } else {
        localAppgateCommands.append(command)
        isNew = true
      }
    }
    guard !isDropped else {
      SKLogger.logInfo("Command was dropped by device id reset and is not saved: \(command.description)")
      return
    }
    // if new command was added we want to execute all pending
    // commands ASAP in one transaction, except logging command
    if isNew && command.commandType != .logging {
      resetFireDateAndRetryCountForPendingCommands()
      syncAllCommands()
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
  
  /// Removes every command of `deviceScopedCommandTypes` in any status, and remembers them
  /// so a request still in flight can't re-insert its command via `saveCommand`.
  /// Purchase-related commands are kept as they are.
  func dropDeviceScopedCommands() {
    var droppedCount = 0
    exclusionSerialQueue.sync {
      let isDeviceScoped: (SKCommand) -> Bool = { Self.deviceScopedCommandTypes.contains($0.commandType) }
      let dropped = localAppgateCommands.filter(isDeviceScoped)
      droppedCount = dropped.count
      droppedCommands.formUnion(dropped)
      localAppgateCommands.removeAll(where: isDeviceScoped)
    }
    saveState()
    SKLogger.logInfo("Dropped \(droppedCount) device scoped commands")
  }
  
  func saveState() {
    exclusionSerialQueue.sync {
      let data = localAppgateCommands.map { $0.getData() }.compactMap { $0 }
      userDefaultsService.setValue(data, forKey: .appgateComands)
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
  
  func createInstallCommandIfNeeded(clientId: String) {
//    V4
    if !hasInstallV4Command {
      let nowDate = Date()
      let initDataV4 = Installapi_DeviceRequest(clientId: clientId,
                                                sdkInstallDate: nowDate)
      let installCommandV4 = SKCommand(timestamp: nowDate.nowTimestampMicroSec,
                                       commandType: .installV4,
                                       status: .pending,
                                       data: initDataV4.getData())
      saveCommand(installCommandV4)
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
    saveCommand(searchAdsCommand)
  }
  
  func createIDFACommandIfNeeded(automaticCollectIDFA: Bool) {
    guard automaticCollectIDFA else {
      deleteAllCommand(by: .idfaV4)
      deleteAllCommand(by: .fetchIdfa)
      return
    }
    
    // No need to sent idfa to the server twice
    guard getAllCommands(by: .idfaV4).count == 0 else {
      return
    }
    
    /// Want to delay 3 commands only after the first launch.
    /// After it jsut one time per launch
    let fetchIdfaCommandsCount = getAllCommands(by: .fetchIdfa).count
    if fetchIdfaCommandsCount == 0 {
      let sec5Command: SKCommand = SKCommand(commandType: .fetchIdfa,
                                             status: .pending,
                                             data: "5".data(using: .utf8),
                                             retryCount: 0,
                                             fireDate: Date().addingTimeInterval(5),
                                             fireDateRessetable: false)
      let sec15Command: SKCommand = SKCommand(commandType: .fetchIdfa,
                                             status: .pending,
                                             data: "15".data(using: .utf8),
                                             retryCount: 0,
                                             fireDate: Date().addingTimeInterval(15),
                                             fireDateRessetable: false)
      let sec60Command: SKCommand = SKCommand(commandType: .fetchIdfa,
                                             status: .pending,
                                             data: "60".data(using: .utf8),
                                             retryCount: 0,
                                             fireDate: Date().addingTimeInterval(60),
                                             fireDateRessetable: false)
      saveCommand(sec5Command)
      saveCommand(sec15Command)
      saveCommand(sec60Command)
    } else {
      let fetchIdfaCommand: SKCommand = SKCommand(commandType: .fetchIdfa,
                                                  status: .pending,
                                                  data: nil,
                                                  retryCount: 0,
                                                  fireDate: Date(),
                                                  fireDateRessetable: false)
      saveCommand(fetchIdfaCommand)
    }
  }
  
  func resetFireDateAndRetryCountForPendingCommands() {
    let commands: [SKCommand] = getAllCommands(by: .pending).filter { $0.fireDateRessetable }
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
      SKLogger.logError("Command timeout has been reached. Need to call command one more time",
                        features: [SKLoggerFeatureType.internalValue.name: "Command timeout has been reached. Commads = \(command.description)"])
    }
  }
}
