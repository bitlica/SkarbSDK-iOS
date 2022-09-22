//
//  SKOfferings.swift
//  SkarbSDK
//
//  Created by Artem Hitrik on 19.09.22.
//

import Foundation

public struct SKOfferings {
  let offerings: [SKOffering]
  
  init(offeringsResponse: Setupsapi_OfferingsResponse) {
    offerings = offeringsResponse.data.map({ SKOffering(offering: $0) })
  }
}

public struct SKOffering {
  let id: String
  let description: String
  let packages: [SKOfferPackage]
  
  init(offering: Setupsapi_Offering) {
    id = offering.id
    description = offering.description_p
    packages = offering.packages.map({ SKOfferPackage(package: $0) })
  }
}

public struct SKOfferPackage {
  let id: String
  let description: String
  let products: [String]
  
  init(package: Setupsapi_Package) {
    id = package.id
    description = package.description_p
    products = package.products
  }
}
