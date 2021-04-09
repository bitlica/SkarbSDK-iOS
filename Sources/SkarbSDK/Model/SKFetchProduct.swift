//
//  SKFetchProduct.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 1/18/21.
//  Copyright © 2021 Prodinfire. All rights reserved.
//

import Foundation

struct SKFetchProduct: SKCodableStruct, Equatable, Hashable {
  let productId: String
  let transactionDate: Date?
  let transactionId: String?
  
  init(productId: String, transactionDate: Date?, transactionId: String?) {
    self.productId = productId
    self.transactionDate = transactionDate
    self.transactionId = transactionId
  }
  
  func getData() -> Data? {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      return encoded
    }
    
    return nil
  }
}
