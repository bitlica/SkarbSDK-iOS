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

public class SkarbSDK {
  
//  MARK: Public
  public static var isLoggingEnabled: Bool = false
  public static var automaticCollectIDFA: Bool = true
  
//  MARK: Private
  static let agentName: String = "SkarbSDK-iOS"
  static let version: String = "0.6.16"
  
  static var clientId: String = ""
  
//  TODO: Separate manager?
//  Callback main thread?
  static var cachedUserPurchaseInfo: SKUserPurchaseInfo? = nil
  
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
    SKServiceRegistry.commandStore.createAutomaticSearchAdsCommand(enable)
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
  
  public static func sendAppsflyerId(_ appsflyerId: String) {
    guard !SKServiceRegistry.commandStore.hasSetAppsflyerIdCommand else {
      return
    }
    
    let attributionRequest = Installapi_AttribRequest(
      broker: SKBroker.appsflyer.name,
      features: nil,
      brokerUserID: appsflyerId
    )
    let sourceV4Command = SKCommand(commandType: .sourceV4,
                                    status: .pending,
                                    data: attributionRequest.getData())
    SKServiceRegistry.commandStore.saveCommand(sourceV4Command)
  }
  
  /// Verify receipt for user purchases.
  /// Might be called on the any thread. Callback will be on the main thread
  public static func validateReceipt(with refreshPolicy: SKRefreshPolicy,
                                     completion: @escaping (Result<SKUserPurchaseInfo, Error>) -> Void) {
    if refreshPolicy == .memoryCached,
       let userPurchaseInfo = cachedUserPurchaseInfo {
      DispatchQueue.main.async {
        completion(.success(userPurchaseInfo))
      }
      return
    }
    
    SKServiceRegistry.serverAPI.verifyReceipt(completion: { result in
      switch result {
        case .success(let updatedUserPurchaseInfo):
          cachedUserPurchaseInfo = updatedUserPurchaseInfo
          completion(.success(updatedUserPurchaseInfo))
        case .failure(let error):
          completion(.failure(error))
      }
    })
  }
  
  /// Might be called on the any thread. Callback will be on the main thread
  public static func getOfferings(with refreshPolicy: SKRefreshPolicy,
                                  completion: @escaping (Result<SKOfferings, Error>) -> Void) {
    SKServiceRegistry.offeringsManager.getOfferings(with: refreshPolicy,
                                                    completion: completion)
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
  private static func saveDeviceId(_ deviceId: String) {
    SKServiceRegistry.userDefaultsService.setValue(deviceId, forKey: .deviceId)
  }
}
