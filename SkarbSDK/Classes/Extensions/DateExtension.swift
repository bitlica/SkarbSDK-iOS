//
//  DateExtension.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 4/8/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import Foundation

extension Date {
  static let nowTimestampInt: Int = Int(Date().timeIntervalSince1970 * 1000000)
}
