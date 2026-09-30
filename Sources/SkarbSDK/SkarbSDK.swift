//
//  SkarbSDK.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/27/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import UIKit
import StoreKit

public extension Notification.Name {
  static let skarbUserPurchaseInfoDidUpdate = Notification.Name("skarbUserPurchaseInfoDidUpdate")
}

public class SkarbSDK {
  
//  MARK: Public
  public static var isLoggingEnabled: Bool = false
  public static var automaticCollectIDFA: Bool = true
  
//  MARK: Private
  static let agentName: String = "SkarbSDK-iOS"
  static let version: String = "0.6.33"
  
  static var clientId: String = ""

  private static var isInitialized: Bool = false
  private static var isAutomaticSearchAdsEnabled: Bool = false
  private static let resetDeviceIdSerialQueue = DispatchQueue(label: "com.skarbSDK.resetDeviceId")
    
  public static func initialize(clientId: String,
                                isObservable: Bool,
                                deviceId: String? = nil) {
    
    SkarbSDK.clientId = clientId
    if let deviceId = deviceId {
      saveDeviceId(deviceId)
    }
    
    // Order is matter:
    // needs to be sure that install command data exists always
    // because some data are used in other commands and should not be nil
    SKServiceRegistry.migrationService.doMigrationIfNeeded()
    SKServiceRegistry.commandStore.createInstallCommandIfNeeded(clientId: clientId)
    SKServiceRegistry.commandStore.createIDFACommandIfNeeded(automaticCollectIDFA: automaticCollectIDFA)
    SKServiceRegistry.initialize(isObservable: isObservable)
    isInitialized = true
    useAutomaticAppleSearchAdsAttributionCollection(true)
  }
  
  //    MARK: Public
  public static func sendTest(name: String,
                              group: String) {
    // V4
    if !SKServiceRegistry.commandStore.hasTestV4Command {
      let testRequest = Installapi_TestRequest(name: name, group: group)
      let testV4Command = SKCommand(commandType: .testV4,
                                    status: .pending,
                                    data: testRequest.getData())
      SKServiceRegistry.commandStore.saveCommand(testV4Command)
    }
  }
  
  /// For brokerUserID use the unique userID for this SKBroker.
  /// For example, for Appsflyer - AppsFlyerLib.shared().getAppsFlyerUID()
  public static func sendSource(broker: SKBroker,
                                features: [AnyHashable: Any],
                                brokerUserID: String?) {
    // V4
    if !SKServiceRegistry.commandStore.hasSendSourceV4Command(broker: broker) {
      let attributionRequest = Installapi_AttribRequest(
        broker: broker.name,
        features: features,
        brokerUserID: brokerUserID
      )
      let sourceV4Command = SKCommand(commandType: .sourceV4,
                                      status: .pending,
                                      data: attributionRequest.getData())
      SKServiceRegistry.commandStore.saveCommand(sourceV4Command)
    }
  }
  
  public static func getDeviceId() -> String {
    guard let deviceId = SKServiceRegistry.userDefaultsService.string(forKey: .deviceId) else {
      let deviceId = UUID().uuidString
      saveDeviceId(deviceId)
      SKLogger.logError("SkarbSDK: getDeviceId() - deviceId is nil",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.internalValue.name: "deviceId is nil"])
      return deviceId
    }
    return deviceId
  }
  
  public static func useAutomaticAppleSearchAdsAttributionCollection(_ enable: Bool) {
    isAutomaticSearchAdsEnabled = enable
    SKServiceRegistry.commandStore.createAutomaticSearchAdsCommand(enable)
  }
  
  /// Switches the SDK to a new device id, so from now on this device is reported as a fresh
  /// install. Intended for the moment the user's data has been erased on their request.
  ///
  /// - Install, source, test, IDFA and Apple Search Ads commands are dropped in any status,
  ///   together with pending logs - they carry the old id. `sendSource`, `sendTest` and
  ///   `sendIDFA` are sent once per install, so call them again if the new install needs them.
  /// - Purchase data is kept: queued purchase, receipt, transaction and price commands are still
  ///   delivered with the device id they were created with, and the cached `SKUserPurchaseInfo`
  ///   stays - it belongs to the store account, not to the install. The next `validateReceipt`
  ///   verifies it for the new id.
  /// - A new install command is queued, plus IDFA and Search Ads ones following
  ///   `automaticCollectIDFA` and `useAutomaticAppleSearchAdsAttributionCollection(_:)`.
  ///   Before `initialize` nothing is queued: the id is only saved, and `initialize` sends
  ///   the install for it.
  /// - If you pass your own `deviceId` to `initialize`, pass the returned one from now on:
  ///   `initialize` stores whatever id it is given.
  ///
  /// Nothing is erased on the server. Can be called on any thread.
  /// - Parameter newDeviceId: the id to switch to. A new UUID is generated when `nil` or blank.
  /// - Returns: the device id in use from now on.
  @discardableResult
  public static func resetDeviceId(newDeviceId: String? = nil) -> String {
    let isBlank = newDeviceId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? false
    if isBlank {
      SKLogger.logError("SkarbSDK: resetDeviceId() - blank deviceId passed, generating a random one",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
    }
    // `getDeviceId` treats only a missing id as missing, so a blank one must never be saved
    let deviceId = (isBlank ? nil : newDeviceId) ?? UUID().uuidString
    
    // Serialized so two resets can't interleave and queue two install commands
    resetDeviceIdSerialQueue.sync {
      resetDeviceScopedData(newDeviceId: deviceId)
    }
    
    SKLogger.logInfo("SkarbSDK: device id was reset. deviceId = \(deviceId), isInitialized = \(isInitialized)")
    return deviceId
  }
  
  public static func sendIDFA(idfa: String?) {
    guard !SKServiceRegistry.commandStore.hasIDFACommand else {
      return
    }
    
    let attributionRequest = Installapi_IDFARequest(idfa: idfa)
    let idfaV4Command = SKCommand(commandType: .idfaV4,
                                  status: .pending,
                                  data: attributionRequest.getData())
    SKServiceRegistry.commandStore.saveCommand(idfaV4Command)
  }
  
  /// Verify receipt for user purchases.
  /// Might be called on the any thread. Callback will be on the main thread
  public static func validateReceipt(with refreshPolicy: SKRefreshPolicy,
                                     retryAttempt: Int = 0,
                                     maxRetryAttempts: Int = 0,
                                     completion: @escaping (Result<SKUserPurchaseInfo, Error>) -> Void) {
    let userPurchasedInfoCacheDate = SKServiceRegistry.userDefaultsService.date(forKey: .userPurchasedInfoCacheDate)
    var components = DateComponents()
    components.day = 6
    
    var isCacheExpired: Bool = true
    if let userPurchasedInfoCacheDate = userPurchasedInfoCacheDate,
       let newExpCacheDate = Calendar.current.date(byAdding: components, to: userPurchasedInfoCacheDate) {
      isCacheExpired = Date() >= newExpCacheDate
    }
    
    if refreshPolicy == .memoryCached,
       let userPurchaseInfo = SKServiceRegistry.userDefaultsService.codable(forKey: .userPurchasedInfo, objectType: SKUserPurchaseInfo.self),
       (userPurchasedInfoCacheDate != nil),
       !isCacheExpired {
      DispatchQueue.main.async {
        completion(.success(userPurchaseInfo))
      }
      return
    }
    
    SKServiceRegistry.serverAPI.verifyReceipt(completion: { result in
      switch result {
      case .success(let updatedUserPurchaseInfo):
        SKServiceRegistry.userDefaultsService.setCodable(object: updatedUserPurchaseInfo, forKey: .userPurchasedInfo)
        SKServiceRegistry.userDefaultsService.setValue(Date(), forKey: .userPurchasedInfoCacheDate)
        NotificationCenter.default.post(name: .skarbUserPurchaseInfoDidUpdate, object: nil)
        completion(.success(updatedUserPurchaseInfo))
      case .failure(let error):
        if retryAttempt < maxRetryAttempts {
          // retry
          let delay = Double(retryAttempt) * 0.15
          DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            validateReceipt(
              with: refreshPolicy,
              retryAttempt: retryAttempt + 1,
              maxRetryAttempts: maxRetryAttempts,
              completion: completion)
          }
        } else {
          completion(.failure(error))
        }
      }
    })
  }
  
  /// Might be called on the any thread. Callback will be on the main thread
  public static func getOfferings(with refreshPolicy: SKRefreshPolicy,
                                  completion: @escaping (Result<SKOfferings, Error>) -> Void) {
    SKServiceRegistry.offeringsManager.getOfferings(with: refreshPolicy,
                                                    completion: completion)
  }

  /// Synchronously checks whether offerings are already cached in memory.
  /// Does not trigger a network fetch. Can be called on any thread.
  public static func isOfferingsAvailable() -> Bool {
    return SKServiceRegistry.offeringsManager.isOfferingsAvailable()
  }

  public static func getCachedUserPurchaseInfoIfAvailable() -> SKUserPurchaseInfo? {
    return SKServiceRegistry.userDefaultsService.codable(
      forKey: .userPurchasedInfo,
      objectType: SKUserPurchaseInfo.self
    )
  }

  //    MARK: Purchasing flow
  /// Restore all purchases
  /// Should be called on the main thread. Callback will be on the main thread
  /// - Note: This may force your users to enter the App Store password so should only be performed on request of
  /// the user. Typically with a button in settings or near your purchase UI.
  public static func restorePurchases(completion: @escaping (Result<SKUserPurchaseInfo, Error>) -> Void) {
    guard SKServiceRegistry.storeKitService != nil else {
      fatalError("SkarbSDK wasn't initialized. Use 'initialize' method before calling 'restorePurchases()'")
    }
    SKServiceRegistry.storeKitService.restorePurchases(completion: { result in
      switch result {
        case .success:
          validateReceipt(with: .always,
                          maxRetryAttempts: 2,
                          completion: completion)
        case .failure(let error):
          completion(.failure(error))
      }
    })
  }
  
  /// Should be called on the main thread. Callback will be on the main thread
  public static func purchasePackage(_ package: SKOfferPackage, completion: @escaping (Result<SKUserPurchaseInfo, Error>) -> Void) {
    guard SKServiceRegistry.storeKitService != nil else {
      fatalError("SkarbSDK wasn't initialized. Use 'initialize' method before calling 'purchasePackage()'")
    }
    guard SKServiceRegistry.storeKitService.canMakePayments else {
      completion(.failure(SKResponseError(errorCode: 0, message: "You don't have permission to make payments.")))
      return
    }
    SKServiceRegistry.storeKitService.purchasePackage(package, completion: { result in
      switch result {
        case .success:
          validateReceipt(with: .always,
                          completion: completion)
        case .failure(let error):
          completion(.failure(error))
      }
    })
  }
  
  //  Indicates whether the user is allowed to make payments.
  public static func canMakePayments() -> Bool {
    guard SKServiceRegistry.storeKitService != nil else {
      fatalError("SkarbSDK wasn't initialized. Use 'initialize' method before calling 'canMakePayments()'")
    }
    return SKServiceRegistry.storeKitService.canMakePayments
  }
  
  public static func setStoreKitDelegate(_ delegate: SKStoreKitDelegate?) {
    guard SKServiceRegistry.storeKitService != nil else {
      fatalError("SkarbSDK wasn't initialized. Use 'initialize' method before calling 'setStoreKitDelegate()'")
    }
    SKServiceRegistry.storeKitService.delegate = delegate
  }
  
  //  MARK: Private
  private static func resetDeviceScopedData(newDeviceId: String) {
    // The id goes first: a command or log created from here on carries the new one,
    // so the drop below can't miss an old-id command created in between.
    saveDeviceId(newDeviceId)
    SKServiceRegistry.commandStore.dropDeviceScopedCommands()
    
    // Not read since V3 was removed, but may still hold analytics data of the old install
    let userDefaultsService = SKServiceRegistry.userDefaultsService
    userDefaultsService.removeValue(forKey: .initData)
    userDefaultsService.removeValue(forKey: .brokerData)
    userDefaultsService.removeValue(forKey: .testData)
    
    // Same order as in `initialize`, without touching the StoreKit service
    if isInitialized {
      SKServiceRegistry.commandStore.createInstallCommandIfNeeded(clientId: clientId)
      SKServiceRegistry.commandStore.createIDFACommandIfNeeded(automaticCollectIDFA: automaticCollectIDFA)
      SKServiceRegistry.commandStore.createAutomaticSearchAdsCommand(isAutomaticSearchAdsEnabled)
    }
  }
  
  private static func saveDeviceId(_ deviceId: String) {
    SKServiceRegistry.userDefaultsService.setValue(deviceId, forKey: .deviceId)
  }
}
