//
//  SKStoreKitService.swift
//  ios
//
//  Created by Artem Hitrik on 2/20/20.
//  Copyright © 2020 Ihnat Kandrashou. All rights reserved.
//

import Foundation
import StoreKit

protocol SKStoreKitService {
  func requestProductInfoAndSendPurchase(productId: String)
}
