//
//  SKBroker.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/19/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

public enum SKBroker {
  case facebook
  case searchads
  case appsflyer
  case custom(String)
  
  var name: String {
    switch self {
      case .facebook:
        return "facebook"
      case .searchads:
        return "searchads"
      case .appsflyer:
        return "appsflyer"
      case .custom(let value):
        return value
    }
  }
}
