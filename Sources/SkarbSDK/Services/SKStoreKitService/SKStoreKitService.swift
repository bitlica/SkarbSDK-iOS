//
//  SKStoreKitService.swift
//  ios
//
//  Created by Bitlica Inc. on 2/20/20.
//  Copyright © 2020 Ihnat Kandrashou. All rights reserved.
//

import Foundation
import StoreKit

public protocol SKStoreKitDelegate: AnyObject {
  func storeKitUpdatedTransaction(_ updatedTransaction: SKPaymentTransaction)
  func storeKit(shouldAddStorePayment payment: SKPayment,
                for product: SKProduct) -> Bool
}

protocol SKStoreKitService {
  func requestProductInfoAndSendPurchase(command: SKCommand)
  func restorePurchases(completion: @escaping (Result<Bool, Error>) -> Void)
  func purchaseProduct(_ product: SKProduct, completion: @escaping (Result<Bool, Error>) -> Void)
  func purchasePackage(_ package: SKOfferPackage, completion: @escaping (Result<Bool, Error>) -> Void)
  
  func requestProductsInfo(productIds: [String],
                           completion: @escaping (Result<[SKProduct], Error>) -> Void)
  func fetchProduct(by productId: String) -> SKProduct?
  
  var canMakePayments: Bool { get }
  var delegate: SKStoreKitDelegate? { get set }
}
