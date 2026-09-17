//
//  SKStoreKitService.swift
//  SkarbSDK
//
//  Created by Bitlica Inc. on 4/9/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

/// Implemented twice: `SKStoreKitServiceImplementation` (StoreKit 1) and
/// `SKStoreKit2ServiceImplementation` (StoreKit 2). The implementation is chosen once,
/// in `SKServiceRegistry.initialize(isObservable:storeKitVersion:)`.
///
/// Note that no StoreKit type appears here - products are `SKProductInfo`, so the rest
/// of the SDK cannot tell which version is running.
protocol SKStoreKitService {
  func requestProductInfoAndSendPurchase(command: SKCommand)
  func restorePurchases(completion: @escaping (Result<Bool, Error>) -> Void)
  func purchasePackage(_ package: SKOfferPackage, completion: @escaping (Result<Bool, Error>) -> Void)

  func requestProductsInfo(productIds: [String],
                           completion: @escaping (Result<[SKProductInfo], Error>) -> Void)
  func fetchProduct(by productId: String) -> SKProductInfo?

  /// StoreKit 2 signed transactions the device can prove right now, for `verifyReceipt`.
  /// Always empty on StoreKit 1, which has no such thing.
  func collectSignedTransactions(completion: @escaping ([String]) -> Void)

  var canMakePayments: Bool { get }
  var delegate: SKStoreKitDelegate? { get set }
  var observer: SKStoreKitObserver? { get set }
}
