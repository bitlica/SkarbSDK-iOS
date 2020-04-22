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
  
  var hasPurhcaseCommand: Bool {
    var result = false
    exclusionSerialQueue.sync {
      result = localAppgateCommands.first(where: { $0.commandType == .purchase }) != nil
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
  
  /// when user termonate app or go to background some commands might be inProgress
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
}


private extension SKCommandStore {
  func getAllAppgateCommands() -> [SKCommand] {
    var localAppgateCommands: [SKCommand] = []
    exclusionSerialQueue.sync {
      localAppgateCommands = self.localAppgateCommands
    }
    return localAppgateCommands
  }
}
