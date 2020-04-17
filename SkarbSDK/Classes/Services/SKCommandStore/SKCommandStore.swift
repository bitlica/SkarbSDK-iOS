//
//  SKCommandStore.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 4/8/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
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
    exclusionSerialQueue.sync {
      guard localAppgateCommands.first(where: { $0 == command }) == nil else {
        SKLogger.logInfo("saveAppgateCommand: called but this command is already exist. UpdateCommand: called with command = \(command.description)")
        updateCommand(command)
        return
      }
      localAppgateCommands.append(command)
    }
    saveState()
  }
  
  func updateCommand(_ command: SKCommand) {
    exclusionSerialQueue.sync {
      guard let currentCommand = localAppgateCommands.filter({ $0 == command }).first,
        let index = localAppgateCommands.firstIndex(where: { $0 == currentCommand }) else {
        SKLogger.logInfo("updateCommand called: but there is no such command = \(command.description)")
        return
      }
      localAppgateCommands[index] = command
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
