//
//  SKTestData.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 4/7/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
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
