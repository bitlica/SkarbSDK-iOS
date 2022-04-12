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
import Reachability
import AdSupport
import AppTrackingTransparency
import AdServices

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
  
  var connection: Reachability.Connection? {
    return reachability?.connection
  }
  private let reachability: Reachability?
  
  private var timer: Timer?
  
  init() {
    cachedIsRunning = false
    reachability = try? Reachability()
    reachability?.whenReachable = { [weak self] _ in
      SKLogger.logInfo("Reachability changed to ON")
      SKServiceRegistry.commandStore.resetFireDateAndRetryCountForPendingCommands()
      self?.startSync()
    }
    reachability?.whenUnreachable = { [weak self] _ in
      SKLogger.logInfo("Reachability changed to OFF")
      self?.stopSync()
    }
    try? reachability?.startNotifier()
    
    startSync()
    
    // Need to reset firedate because user just launched the app
    // and need to try execute all pending commands ASAP
    SKServiceRegistry.commandStore.resetFireDateAndRetryCountForPendingCommands()
    
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(self, selector: #selector(willResignActiveNotification), name: UIApplication.willResignActiveNotification, object: nil)
    notificationCenter.addObserver(self, selector: #selector(willEnterForegroundNotification), name: UIApplication.willEnterForegroundNotification, object: nil)
    notificationCenter.addObserver(self, selector: #selector(didBecomeActiveNotification), name: UIApplication.didBecomeActiveNotification, object: nil)
  }
  
  func syncAllCommands() {
    actionSerialQueue.async { [weak self] in
      self?.startSyncAllCommands()
    }
  }
  
  private func startSyncAllCommands() {
    dispatchPrecondition(condition: .notOnQueue(DispatchQueue.main))
    
    SKServiceRegistry.commandStore.checkInProgressCommandsTimeout()
    
    guard connection == .cellular ||
          connection == .wifi else {
      return
    }
    
    let executeCommands = SKServiceRegistry.commandStore.getCommandsForExecuting()
    for executeCommand in executeCommands {
      var command = executeCommand
      command.changeStatus(to: .inProgress)
      command.updateFireDate(Date())
      SKServiceRegistry.commandStore.saveCommand(command)
      
      SKLogger.logInfo("Command start executing: \(command.description)")
      
      switch command.commandType {
        case .install, .source, .test, .purchase, .logging, .installV4, .sourceV4,
            .testV4, .purchaseV4, .transactionV4, .priceV4, .idfaV4, .skanV4:
          SKServiceRegistry.serverAPI.syncCommand(command, completion: { [weak self] error in
            if let error = error {
              var features: [String: Any] = [:]
              features[SKLoggerFeatureType.requestType.name] = command.commandType.rawValue
              features[SKLoggerFeatureType.retryCount.name] = command.retryCount
              features[SKLoggerFeatureType.responseStatus.name] = error.errorCode
              features[SKLoggerFeatureType.connection.name] = self?.connection?.description
              
              command.updateRetryCountAndFireDate()
              command.changeStatus(to: .pending)
              
              // code < 0 means that it's internal error and
              // we don't want to log it to aws
              if error.isInternetCode || error.code < 0 {
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
          if #available(iOS 14.3, *) {
            DispatchQueue.global(qos: .default).async {
              do {
                let token = try AAAttribution.attributionToken()
                DispatchQueue.main.async {
                  SkarbSDK.sendSource(broker: .saaapi, features: ["saatoken": token])
                }
                command.changeStatus(to: .done)
              }
              catch {
                command.updateRetryCountAndFireDate()
                command.changeStatus(to: .pending)
              }
              SKServiceRegistry.commandStore.saveCommand(command)
            }
          }
          else {
            DispatchQueue.main.async {
              ADClient.shared().requestAttributionDetails ({ (attributionJSON, error) in
                guard error == nil else {
                  command.updateRetryCountAndFireDate()
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
        case .fetchIdfa:
          command.changeStatus(to: .done)
          SKServiceRegistry.commandStore.saveCommand(command)
          if #available(iOS 14, *) {
            guard ATTrackingManager.trackingAuthorizationStatus == .authorized else {
              return
            }
          } else if !ASIdentifierManager.shared().isAdvertisingTrackingEnabled {
            return
          }
          let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
          let idfaRequest = Installapi_IDFARequest(idfa: idfa)
          let idfaCommand = SKCommand(commandType: .idfaV4,
                                      status: .pending,
                                      data: idfaRequest.getData())
          SKServiceRegistry.commandStore.saveCommand(idfaCommand)
          
        // also need to set for all other fetchIDFACommands "done" status
        // no need to send twice idfa to the server
          let notDoneIDFACommands = SKServiceRegistry.commandStore.getAllCommands(by: .fetchIdfa).filter { $0.status != .done }
          for idfaCommands in notDoneIDFACommands {
            var editCommand = idfaCommands
            editCommand.changeStatus(to: .done)
            SKServiceRegistry.commandStore.saveCommand(idfaCommand)
          }
      }
    }
  }
}

private extension SKSyncServiceImplementation {
  @objc func willResignActiveNotification() {
    SKLogger.logInfo("SKSyncService is stoppted because app willResignActiveNotification")
    stopSync()
  }
  
  @objc func willEnterForegroundNotification() {
    SKLogger.logInfo("SKSyncService is resumed because app willEnterForegroundNotification")
    startSync()
  }
  
  @objc func didBecomeActiveNotification() {
    SKLogger.logInfo("SKSyncService is resumed because app didBecomeActiveNotification")
    startSync()
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
      self?.syncAllCommands()
    })
  }
  
  private func stopSync() {
    timer?.invalidate()
    timer = nil
    stateSerialQueue.sync {
      cachedIsRunning = false
    }
  }
}
