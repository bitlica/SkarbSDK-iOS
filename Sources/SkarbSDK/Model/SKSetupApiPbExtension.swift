//
//  SKSetupApiPbExtension.swift
//  SkarbSDK
//
//  Created by Artem Hitrik on 24.11.22.
//

import Foundation


extension Setupsapi_OfferingsResponse {
  var allProductIds: [String] {
    var productIds: [String] = []
    for offering in data {
      for package in offering.packages {
        productIds.append(package.products.first!)
      }
    }
    return productIds
  }
}
