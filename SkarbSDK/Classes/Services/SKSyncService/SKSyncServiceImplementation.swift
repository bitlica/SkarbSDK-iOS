//
//  SKSyncServiceImplementation.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/23/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import UIKit
import iAd

class SKSyncServiceImplementation: SKSyncService {
  
  private let actionSerialQueue = DispatchQueue(label: "com.skarbSDK.sync.action", qos: .userInitiated)
  private let stateSerialQueue = DispatchQueue(label: "com.skarbSDK.sync.state", qos: .userInitiated)
  
  private var cachedIsRunning: Bool
  private var isRunning: Bool {
    var localIsRunning = false
    stateSerialQueue.sync {
      localIsRunning = cachedIsRunning
    }
    return localIsRunning
  }
  private var cachedIsFirstSync: Bool
  private var isFirstSync: Bool {
    var localIsFirstSync = false
    stateSerialQueue.sync {
      localIsFirstSync = cachedIsFirstSync
    }
    return localIsFirstSync
  }
  
  private var timer: Timer?
  
  init() {
    cachedIsRunning = false
    cachedIsFirstSync = true
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] _ in
      self?.actionSerialQueue.async {
        self?.syncAllCommands()
      }
    })
    
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(self, selector: #selector(willResignActiveNotification), name: UIApplication.willResignActiveNotification, object: nil)
    notificationCenter.addObserver(self, selector: #selector(willEnterForegroundNotification), name: UIApplication.willEnterForegroundNotification, object: nil)
    notificationCenter.addObserver(self, selector: #selector(willTerminateNotification), name: UIApplication.willTerminateNotification, object: nil)
    notificationCenter.addObserver(self, selector: #selector(didBecomeActiveNotification), name: UIApplication.didBecomeActiveNotification, object: nil)
  }
  
  func syncAllCommands() {
    dispatchPrecondition(condition: .notOnQueue(DispatchQueue.main))
    
    let pendingCommands = SKServiceRegistry.commandStore.getPendingCommands()
    for pendingCommand in pendingCommands {
      var command = pendingCommand
      command.changeStatus(to: .inProgress)
      SKServiceRegistry.commandStore.saveCommand(command)
      var delay: TimeInterval = command.getRetryDelay()
      if isFirstSync {
        delay = 0
        stateSerialQueue.sync {
          cachedIsFirstSync = false
        }
      }
      DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay, execute: {
        
        SKLogger.logInfo("Command start executing: \(command.description)")
        
        switch command.commandType {
          case .install, .source, .test, .purchase, .logging, .installV4, .sourceV4, .testV4, .purchaseV4, .transactionV4, .priceV4:
            SKServiceRegistry.serverAPI.syncCommand(command, completion: { error in
              if let error = error {
                var features: [String: Any] = [:]
                features[SKLoggerFeatureType.requestType.name] = command.commandType.rawValue
                features[SKLoggerFeatureType.retryCount.name] = command.retryCount
                features[SKLoggerFeatureType.responseStatus.name] = error.errorCode
                
                command.incrementRetryCount()
                command.changeStatus(to: .pending)
                
                if error.isInternetCode {
                  SKLogger.logInfo("Sync command finished \(command.commandType) with code = \(error.errorCode), message = \(error.message)")
                } else {
                  //send error to server
                  SKLogger.logError("Sync command finished \(command.commandType) with code = \(error.errorCode), message = \(error.message)", features: features)
                }
              } else {
                command.changeStatus(to: .done)
              }
              SKServiceRegistry.commandStore.saveCommand(command)
            })
          case .fetchProducts:
            DispatchQueue.main.async {
              SKServiceRegistry.storeKitService.requestProductInfoAndSendPurchase(command: command)
            }
          case .automaticSearchAds:
            DispatchQueue.main.async {
              ADClient.shared().requestAttributionDetails({ (attributionJSON, error) in
                guard error == nil else {
                  command.incrementRetryCount()
                  command.changeStatus(to: .pending)
                  SKServiceRegistry.commandStore.saveCommand(command)
                  return
                }
                
                if let attributionJSON = attributionJSON {
                  SkarbSDK.sendSource(broker: .searchads, features: attributionJSON)
                }
                command.changeStatus(to: .done)
                SKServiceRegistry.commandStore.saveCommand(command)
              })
            }
        }
      })
    }
  }
}

private extension SKSyncServiceImplementation {
  @objc func willResignActiveNotification() {
    SKLogger.logInfo("SKSyncService is stoppted because app willResignActiveNotification")
    timer?.invalidate()
    timer = nil
    SKServiceRegistry.commandStore.markAllInProgressAsPendingAndSave()
    stateSerialQueue.sync {
      cachedIsRunning = false
    }
  }
  
  @objc func willEnterForegroundNotification() {
    SKLogger.logInfo("SKSyncService is resumed because app willEnterForegroundNotification")
    startSync()
  }
  
  @objc func didBecomeActiveNotification() {
    SKLogger.logInfo("SKSyncService is resumed because app didBecomeActiveNotification")
    startSync()
  }
  
  @objc func willTerminateNotification() {
    SKLogger.logInfo("SKSyncService app willTerminateNotification")
    SKServiceRegistry.commandStore.markAllInProgressAsPendingAndSave()
    stateSerialQueue.sync {
      cachedIsRunning = false
    }
  }
  
  private func startSync() {
    guard !isRunning else {
      return
    }
    stateSerialQueue.sync {
      cachedIsRunning = true
    }
    timer?.invalidate()
    timer = nil
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] _ in
      self?.actionSerialQueue.async {
        self?.syncAllCommands()
      }
    })
  }
}
