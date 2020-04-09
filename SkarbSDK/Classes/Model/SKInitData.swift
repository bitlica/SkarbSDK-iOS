//
//  SKInitData.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 4/7/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

struct SKInitData: SKCodableStruct {
  let clientId: String
  let deviceId: String
  var installDate: String
  let receiptUrl: String
  let receiptLen: Int
  
  func getData() -> Data? {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      return encoded
    }
    
    return nil
  }
}
