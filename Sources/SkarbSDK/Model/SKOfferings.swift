//
//  SKOfferings.swift
//  SkarbSDK
//
//  Created by Artem Hitrik on 19.09.22.
//

import Foundation

public struct SKOfferings {
  public let offerings: [SKOffering]
  public var allOfferingPackages: [SKOfferPackage] {
    return offerings.flatMap { $0.packages }
  }
  
  init(offerings: [SKOffering]) {
    self.offerings = offerings
  }
}

public struct SKOffering {
  public let id: String
  public let description: String
  public let packages: [SKOfferPackage]
  
  init(id: String, description: String, packages: [SKOfferPackage]) {
    self.id = id
    self.description = description
    self.packages = packages
  }
}
