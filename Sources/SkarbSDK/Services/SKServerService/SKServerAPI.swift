//
//  ServerAPI.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import UIKit

protocol SKServerAPI {
  func syncCommand(_ command: SKCommand, completion: ((SKResponseError?) -> Void)?)
  func verifyReceipt(completion: @escaping (Result<SKVerifyReceipt, Error>) -> Void)
  func getOfferings(completion: @escaping (Result<SKOfferings, Error>) -> Void)
}
