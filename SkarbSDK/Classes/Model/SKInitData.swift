//
//  SKInitData.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/7/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
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
