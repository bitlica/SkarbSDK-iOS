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
  private let stateSerialQueue = DispatchQueue(label: "com.skarbSDK.sync.state", qos: .userInitiated)
  private var timer: Timer?
  
  var isSyncNow: Bool {
    var localIsSyncNow: Bool = false
    stateSerialQueue.sync {
      localIsSyncNow = cachedIsSyncNow
    }

    return localIsSyncNow
  }
  
  private var cachedIsSyncNow: Bool = false
  
  init() {
    timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true, block: { [weak self] _ in
      self?.actionSerialQueue.async {
        self?.syncAllCommands()
      }
    })
    
    actionSerialQueue.async {
      self.syncAllCommands()
    }
    
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(self, selector: #selector(willResignActiveNotification), name: UIApplication.willResignActiveNotification, object: nil)
    notificationCenter.addObserver(self, selector: #selector(willEnterForegroundNotification), name: UIApplication.willEnterForegroundNotification, object: nil)
  }
  
  func syncAllCommands() {
    dispatchPrecondition(condition: .notOnQueue(DispatchQueue.main))
    
    SKLogger.logInfo("SKSyncService syncAllCommands called")
    
    guard !isSyncNow else {
        return
    }
    if let fetchAllProductsAndSyncValue = SKServiceRegistry.userDefaultsService.string(forKey: .fetchAllProductsAndSync) {
      self.stateSerialQueue.sync {
        self.cachedIsSyncNow = true
      }
      SKLogger.logInfo("SKSyncService syncAllCommands started sync requestType = \(fetchAllProductsAndSyncValue)")
      DispatchQueue.main.async {
        SKServiceRegistry.storeKitService.requestProductInfoAndSendPurchase(productId: fetchAllProductsAndSyncValue)
      }
    } else if let requestTypeToSync = SKServiceRegistry.userDefaultsService.string(forKey: .requestTypeToSync),
      let requestType = SKRequestType(rawValue: requestTypeToSync) {
      self.stateSerialQueue.sync {
        self.cachedIsSyncNow = true
      }
      SKLogger.logInfo("SKSyncService syncAllCommands started sync requestType = \(requestType)")
      
      SKServiceRegistry.serverAPI.syncAllData(initRequestType: requestType, completion: { [weak self] error in
        self?.stateSerialQueue.sync {
          self?.cachedIsSyncNow = false
        }
        
        if error != nil {
          SKServiceRegistry.userDefaultsService.setString(requestTypeToSync, forKey: .requestTypeToSync)
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
  }
  
  @objc func willEnterForegroundNotification() {
    SKLogger.logInfo("SKSyncService is resumed because app willResignActiveNotification")
    timer?.invalidate()
    timer = nil
    timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true, block: { [weak self] _ in
      self?.actionSerialQueue.async {
        self?.syncAllCommands()
      }
    })
  }
}
