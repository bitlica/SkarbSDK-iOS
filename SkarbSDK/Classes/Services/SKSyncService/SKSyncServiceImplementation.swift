//
//  SKSyncServiceImplementation.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/23/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import UIKit

class SKSyncServiceImplementation: SKSyncService {
  
  private let actionSerialQueue = DispatchQueue(label: "com.skarbSDK.sync.action", qos: .userInitiated)
  private var timer: Timer?
  
  init() {
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] _ in
      self?.actionSerialQueue.async {
        self?.syncAllCommands()
      }
    })
    
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(self, selector: #selector(willResignActiveNotification), name: UIApplication.willResignActiveNotification, object: nil)
    notificationCenter.addObserver(self, selector: #selector(willEnterForegroundNotification), name: UIApplication.willEnterForegroundNotification, object: nil)
    notificationCenter.addObserver(self, selector: #selector(willTerminateNotification), name: UIApplication.willTerminateNotification, object: nil)
  }
  
  func syncAllCommands() {
    dispatchPrecondition(condition: .notOnQueue(DispatchQueue.main))
    
    if let fetchAllProductsAndSyncValue = SKServiceRegistry.userDefaultsService.string(forKey: .fetchAllProductsAndSync) {
      SKLogger.logInfo("SKSyncService syncAllCommands: called started getting all SKProduct")
      DispatchQueue.main.async {
        SKServiceRegistry.storeKitService.requestProductInfoAndSendPurchase(productId: fetchAllProductsAndSyncValue)
      }
    }
    
    let pendingCommands = SKServiceRegistry.commandStore.getPendingCommands()
    for pendingCommand in pendingCommands {
      DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + pendingCommand.getRetryDelay(), execute: {
        var command = pendingCommand
        command.changeStatus(to: .inProgress)
        SKServiceRegistry.commandStore.updateCommand(command)
        SKServiceRegistry.serverAPI.syncCommand(command, completion: { error in
          if let error = error {
            command.changeStatus(to: .pending)
            SKLogger.logError("Sync command finished with error = \(error.message)")
          } else {
            command.changeStatus(to: .done)
          }
          SKServiceRegistry.commandStore.updateCommand(command)
        })
      })
    }
  }
}

private extension SKSyncServiceImplementation {
  @objc func willResignActiveNotification() {
    SKLogger.logInfo("SKSyncService is stoppted because app willResignActiveNotification")
    timer?.invalidate()
    timer = nil
    SKServiceRegistry.commandStore.saveState()
  }
  
  @objc func willEnterForegroundNotification() {
    SKLogger.logInfo("SKSyncService is resumed because app willResignActiveNotification")
    timer?.invalidate()
    timer = nil
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] _ in
      self?.actionSerialQueue.async {
        self?.syncAllCommands()
      }
    })
  }
  
  @objc func willTerminateNotification() {
    SKLogger.logInfo("SKSyncService app willTerminateNotification")
    SKServiceRegistry.commandStore.saveState()
  }
}
