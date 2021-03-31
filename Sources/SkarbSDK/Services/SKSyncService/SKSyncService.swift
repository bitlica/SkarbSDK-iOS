//
//  SKSyncService.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/23/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import Reachability

protocol SKSyncService {
  
  var connection: Reachability.Connection? { get }
  
  func syncAllCommands()
}
