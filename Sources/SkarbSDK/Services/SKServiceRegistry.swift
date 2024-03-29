//
//  ServiceRegistry.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/21/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

class SKServiceRegistry {
  static let serverAPI: SKServerAPI = SKServerAPIImplementaton()
  static let userDefaultsService: SKUserDefaultsService = SKUserDefaultsService()
  static let syncService: SKSyncService = SKSyncServiceImplementation()
  public static var storeKitService: SKStoreKitService!
  static let commandStore: SKCommandStore = SKCommandStore()
  static let migrationService: SKMigrationService = SKMigrationService()
  static let offeringsManager: SKOfferingsManager = SKOfferingsManagerImplementation()
  
  static func initialize(isObservable: Bool) {
    _ = syncService
    storeKitService = SKStoreKitServiceImplementation(isObservable: isObservable)
  }
}
