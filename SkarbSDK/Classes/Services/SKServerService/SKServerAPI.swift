//
//  ServerAPI.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import UIKit

protocol SKServerAPI {
  func sendInstall(completion: @escaping (SKResponseError?) -> Void)
  func sendTest(name: String, group: String, completion: @escaping (SKResponseError?) -> Void)
  func sendSource(broker: SKBroker, features: [String: Any], completion: @escaping (SKResponseError?) -> Void)
  func sendPurchase(productId: String,
                    price: Float?,
                    currency: String?,
                    completion: ((SKResponseError?) -> Void)?)
  func syncAllData(initRequestType: SKRequestType, completion: ((SKResponseError?) -> Void)?)
}
