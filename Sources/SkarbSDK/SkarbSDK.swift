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
  
  static let agentName: String = "SkarbSDK-iOS"
  static let version: String = "0.6.1"
  
  static var clientId: String = ""
  public static var isLoggingEnabled: Bool = false
  public static var automaticCollectIDFA: Bool = true
  
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
  
  /// Verify receipt for user purchases.
  /// Might be called on the any thread. Callback will be on the main thread
  public static func validateReceipt(completion: @escaping (Result<SKVerifyReceipt, Error>) -> Void) {
    SKServiceRegistry.serverAPI.verifyReceipt(completion: completion)
  }
  
  /// Might be called on the any thread. Callback will be on the main thread
  public static func getOfferings(completion: @escaping (Result<SKOfferings, Error>) -> Void) {
    SKServiceRegistry.serverAPI.getOfferings(completion: completion)
  }
  
  //    MARK: Purchasing flow
  /// Restore all purchases
  /// Should be called on the main thread. Callback will be on the main thread
  /// - Note: This may force your users to enter the App Store password so should only be performed on request of
  /// the user. Typically with a button in settings or near your purchase UI.
  public static func restorePurchases(completion: @escaping (Result<SKVerifyReceipt, Error>) -> Void) {
    SKServiceRegistry.storeKitService.restorePurchases(compltion: { result in
      switch result {
        case .success:
          validateReceipt(completion: completion)
        case .failure(let error):
          completion(.failure(error))
      }
    })
  }
  
  /// Should be called on the main thread. Callback will be on the main thread
  public static func purchaseProduct(_ product: SKProduct, completion: @escaping (Result<SKVerifyReceipt, Error>) -> Void) {
    guard SKServiceRegistry.storeKitService.canMakePayments else {
      completion(.failure(SKResponseError(errorCode: 0, message: "You don't have permission to make payments.")))
      return
    }
    SKServiceRegistry.storeKitService.purchaseProduct(product, completion: { result in
      switch result {
        case .success:
          validateReceipt(completion: completion)
        case .failure(let error):
          completion(.failure(error))
      }
    })
  }
  
  /// Should be called on the main thread. Callback will be on the main thread
  public static func purchasePackage(_ package: SKOfferPackage, completion: @escaping (Result<SKVerifyReceipt, Error>) -> Void) {
    guard SKServiceRegistry.storeKitService.canMakePayments else {
      completion(.failure(SKResponseError(errorCode: 0, message: "You don't have permission to make payments.")))
      return
    }
    SKServiceRegistry.storeKitService.purchasePackage(package, completion: { result in
      switch result {
        case .success:
          validateReceipt(completion: completion)
        case .failure(let error):
          completion(.failure(error))
      }
    })
  }
  
  //  Indicates whether the user is allowed to make payments.
  public static func canMakePayments() -> Bool {
    return SKServiceRegistry.storeKitService.canMakePayments
  }
  
  //  MARK: Private
  private static func saveDeviceId(_ deviceId: String) {
    SKServiceRegistry.userDefaultsService.setValue(deviceId, forKey: .deviceId)
  }
}
