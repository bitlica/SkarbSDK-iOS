//
//  SKOfferings.swift
//  SkarbSDK
//
//  Created by Artem Hitrik on 19.09.22.
//

import Foundation

public struct SKOfferings {
  public let offerings: [SKOffering]
  
  init(offeringsResponse: Setupsapi_OfferingsResponse) {
    offerings = offeringsResponse.data.map({ SKOffering(offering: $0) })
  }
}

public struct SKOffering {
  public let id: String
  public let description: String
  public let packages: [SKOfferPackage]
  
  init(offering: Setupsapi_Offering) {
    id = offering.id
    description = offering.description_p
    packages = offering.packages.map({ SKOfferPackage(package: $0) })
  }
}

public struct SKOfferPackage {
  public let id: String
  public let description: String
  public let products: [String]
  
  init(package: Setupsapi_Package) {
    id = package.id
    description = package.description_p
    products = package.products
  }
}
