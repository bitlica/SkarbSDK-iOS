//
//  SKTestData.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/7/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

struct SKTestData: SKCodableStruct {
  let name: String
  let group: String
  
  func getJSON() -> [String: Any] {
    return ["name": name,
            "group": group]
  }
  
  func getData() -> Data? {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      return encoded
    }
    
    return nil
  }
}
