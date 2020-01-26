//
//  Utils.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 1/19/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

public var isDebug: Bool {
  var result = false
  #if DEBUG
    result = true
  #endif
  return result
}
