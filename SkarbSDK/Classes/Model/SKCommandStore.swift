//
//  SKCommandStore.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 4/8/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

struct SKCommandStore {
  
  static func saveAppgateCommand(_ command: SKAppgateCommand) {
    
    
    
    let jsonEncoder = JSONEncoder()
    do {
      let commandData = try jsonEncoder.encode(command)
      SKServiceRegistry.userDefaultsService.setData(commandData, forKey: .appgateComands)
    }
    catch {
      SKLogger.logError("saveAppgateCommand: jsonEncoder.encode: with error \(error.localizedDescription)")
    }
  }
}
