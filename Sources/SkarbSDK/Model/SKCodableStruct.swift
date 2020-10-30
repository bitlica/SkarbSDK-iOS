//
//  CodableStruct.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/8/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

protocol SKCodableStruct: Codable {
  func getData() -> Data?
}
