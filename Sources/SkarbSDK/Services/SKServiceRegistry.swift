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

  /// Version actually in use, after the availability check. Read by
  /// `SkarbSDK.effectiveStoreKitVersion`.
  static var activeStoreKitVersion: SKStoreKitVersion = .v1

  /// The single seam where the StoreKit version is chosen.
  static func initialize(isObservable: Bool, storeKitVersion: SKStoreKitVersion) {
    _ = syncService

    if storeKitVersion == .v2 {
      if #available(iOS 15.0, *) {
        activeStoreKitVersion = .v2
        storeKitService = SKStoreKit2ServiceImplementation(isObservable: isObservable)
        return
      }
      SKLogger.logInfo("SkarbSDK: useStoreKitVersion(.v2) was requested but StoreKit 2 needs iOS 15. Falling back to StoreKit 1.")
    }

    activeStoreKitVersion = .v1
    storeKitService = SKStoreKitServiceImplementation(isObservable: isObservable)
  }
}
