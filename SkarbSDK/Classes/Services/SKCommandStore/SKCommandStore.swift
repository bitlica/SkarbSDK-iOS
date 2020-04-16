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
  
  private var localAppgateCommands: [SKAppgateCommand]
  
  init() {
    localAppgateCommands = SKServiceRegistry.userDefaultsService.codableArray(forKey: .appgateComands, objectType: SKAppgateCommand.self)
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
  
  func saveAppgateCommand(_ command: SKAppgateCommand) {
    exclusionSerialQueue.sync {
      guard localAppgateCommands.first(where: { $0 == command }) == nil else {
        SKLogger.logInfo("saveAppgateCommand called: but this command is already exist")
        return
      }
      localAppgateCommands.append(command)
    }
  }
  
  func updateCommand(_ command: SKAppgateCommand) {
    exclusionSerialQueue.sync {
      guard let currentCommand = localAppgateCommands.filter({ $0 == command }).first,
        let index = localAppgateCommands.firstIndex(where: { $0 == currentCommand }) else {
        SKLogger.logInfo("updateCommand called: but there is no such command \(command.description)")
        return
      }
      localAppgateCommands[index] = command
    }
  }
  
  func saveState() {
    exclusionSerialQueue.sync {
      let data = localAppgateCommands.map { try? JSONEncoder().encode($0) }
      SKServiceRegistry.userDefaultsService.setValue(data, forKey: .appgateComands)
    }
  }
  
  func getPendingCommands() -> [SKAppgateCommand] {
    var result: [SKAppgateCommand] = []
    exclusionSerialQueue.sync {
      result = localAppgateCommands.filter({ $0.status == .pending })
    }
    return result
  }
}


private extension SKCommandStore {
  func getAllAppgateCommands() -> [SKAppgateCommand] {
    var localAppgateCommands: [SKAppgateCommand] = []
    exclusionSerialQueue.sync {
      localAppgateCommands = self.localAppgateCommands
    }
    return localAppgateCommands
  }
}
