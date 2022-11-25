//
//  SKOfferings.swift
//  SkarbSDK
//
//  Created by Artem Hitrik on 19.09.22.
//

import Foundation
import StoreKit

public struct SKOfferings {
  public let offerings: [SKOffering]
  
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

public struct SKOfferPackage {
  public let id: String
  public let description: String
  public let productId: String
  public let storeProduct: SKProduct
  
  init(package: Setupsapi_Package, storeProduct: SKProduct) {
    self.id = package.id
    self.description = package.description_p
    self.productId = package.products.first! //TODO: Will be only one productId
    self.storeProduct = storeProduct
  }
}
