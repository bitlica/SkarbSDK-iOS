//
//  DateExtension.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 4/8/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

extension Date {
  var nowTimestampInt: Int {
    return Int(self.timeIntervalSince1970 * 1000000)
  }
}
