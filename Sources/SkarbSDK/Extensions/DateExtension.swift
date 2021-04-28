//
//  DateExtension.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/8/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

extension Date {
  var nowTimestampMicroSec: Int {
    return Int(self.timeIntervalSince1970 * 1000000)
  }
}
