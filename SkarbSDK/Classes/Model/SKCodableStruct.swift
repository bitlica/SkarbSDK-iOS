//
//  CodableStruct.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 4/8/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

protocol SKCodableStruct: Codable {
  func getData() -> Data?
}
