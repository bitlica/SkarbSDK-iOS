//
//  SKStoreKitService.swift
//  ios
//
//  Created by Bitlica Inc. on 2/20/20.
//  Copyright © 2020 Ihnat Kandrashou. All rights reserved.
//

import Foundation
import StoreKit

protocol SKStoreKitService {
  func requestProductInfoAndSendPurchase(command: SKCommand)
  func restorePurchases(compltion: @escaping (Result<Bool, Error>) -> Void)
  func purchaseProduct(_ product: SKProduct, completion: @escaping (Result<Bool, Error>) -> Void)
  func purchasePackage(_ package: SKOfferPackage, completion: @escaping (Result<Bool, Error>) -> Void)
  
  var canMakePayments: Bool { get }
}
