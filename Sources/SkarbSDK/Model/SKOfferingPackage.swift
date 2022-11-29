//
//  SKOfferingPackage.swift
//  SkarbSDK
//
//  Created by Artem Hitrik on 29.11.22.
//

import Foundation
import StoreKit

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
  
  var period: SKProduct.PeriodUnit? {
    return storeProduct.subscriptionPeriod?.unit
  }
  
  var numberOfUnits: Int? {
    return storeProduct.subscriptionPeriod?.numberOfUnits
  }
  
  var price: Decimal {
    return storeProduct.price as Decimal
  }
  
  var currencyCode: String? {
    return storeProduct.priceLocale.currencyCode
  }
  
  var localizedPriceString: String {
    return priceAsString(locale: storeProduct.priceLocale,
                         price: storeProduct.price) ?? ""
  }
  
  var localizedIntroductoryPriceString: String? {
      guard #available(iOS 12.2, *),
            let intro = storeProduct.introductoryPrice
      else {
          return nil
      }

    return priceAsString(locale: intro.priceLocale,
                         price: intro.price)
  }

  // MARK: Private
  private func priceAsString(locale: Locale,
                     price: NSDecimalNumber) -> String? {
    let formatter = NumberFormatter()
    formatter.formatterBehavior = .behavior10_4
    formatter.numberStyle = .currency
    formatter.minimumFractionDigits = 0
    formatter.locale = locale
    return formatter.string(from: price)
  }
}
