//
//  SyncCommand.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 4/3/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

struct SKAppgateCommand: Codable {
  let timestamp: Int
  let commandType: SKCommandAppgateType
  let status: SKCommandStatus
  let data: Data
}
