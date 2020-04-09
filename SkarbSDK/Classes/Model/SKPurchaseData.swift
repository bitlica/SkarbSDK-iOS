//
//  SKPurchaseData.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 4/7/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

struct SKPurchaseData: SKCodableStruct {
  let productId: String
  let price: Float?
  let currency: String?
  let date: String
  
  func getData() -> Data? {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      return encoded
    }
    
    return nil
  }
}
