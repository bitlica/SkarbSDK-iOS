//
//  SKOfferingPackage.swift
//  SkarbSDK
//
//  Created by Artem Hitrik on 29.11.22.
//

import Foundation
import StoreKit

public enum PurchaseType {
  case weekly
  case monthly
  case yearly
  case consumable
  case nonConsumable
  case unknown
  
  static func initWith(string: String) -> PurchaseType {
    switch string {
    case "weekly": return .weekly
    case "monthly": return .monthly
    case "yearly": return .yearly
    case "consumable": return .consumable
    case "non-consumable": return .nonConsumable
    default: return .unknown
    }
  }
}

public struct SKOfferPackage {
  public let id: String
  public let description: String
  public let productId: String
  public let purchaseType: PurchaseType
  public let storeProduct: SKProduct
  
  init(package: Setupsapi_Package, storeProduct: SKProduct) {
    self.id = package.id
    self.description = package.description_p
    self.productId = package.productID
    self.purchaseType = PurchaseType.initWith(string: package.purchaseType)
    self.storeProduct = storeProduct
  }
  
  public var isTrial: Bool {
    guard let intro = storeProduct.introductoryPrice else {
      return false
    }
    return intro.paymentMode == SKProductDiscount.PaymentMode.freeTrial
  }
  
  public var isIntroPriceOrPeriod: Bool {
    guard let intro = storeProduct.introductoryPrice else {
      return false
    }
    switch intro.paymentMode {
    case .freeTrial:
      return false
    case .payUpFront, .payAsYouGo:
      return true
    @unknown default:
      return false
    }
  }
  
  public var isSubscription: Bool {
    return storeProduct.subscriptionPeriod != nil
  }
  
  public var period: SKProduct.PeriodUnit? {
    return storeProduct.subscriptionPeriod?.unit
  }
  
  public var trialPeriodDuration: Int? {
    isTrial ? storeProduct.introductoryPrice?.subscriptionPeriod.numberOfUnits : nil
  }
  
  public var discountPeriodDuration: Int? {
    storeProduct.introductoryPrice?.subscriptionPeriod.numberOfUnits
  }
  
  public var discountPeriod: SKProduct.PeriodUnit? {
    storeProduct.introductoryPrice?.subscriptionPeriod.unit
  }
  
  public var numberOfUnits: Int? {
    return storeProduct.subscriptionPeriod?.numberOfUnits
  }
  
  public var price: Decimal {
    return storeProduct.price as Decimal
  }
  
  public var currencyCode: String? {
    return storeProduct.priceLocale.currencyCode
  }
  
  public var localizedPriceString: String {
    return priceAsString(locale: storeProduct.priceLocale,
                         price: storeProduct.price) ?? ""
  }
  
  public var localizedIntroductoryPriceString: String? {
      guard #available(iOS 12.2, *),
            let intro = storeProduct.introductoryPrice
      else {
          return nil
      }

    return priceAsString(locale: intro.priceLocale,
                         price: intro.price)
  }
  
  public var monthlyLocalizedPriceString: String? {
    let monthFactor: Decimal? = {
      switch period {
      case .day: return 1 / 30
      case .week: return 1 / 4
      case .month: return 1
      case .year: return 12
      case .none, .some(_):
        return nil
      }
    }()
    guard let numberOfUnits,
          let monthFactor else {
      return nil
    }
    
    let periodsPerMonth: Decimal = monthFactor * Decimal(numberOfUnits)

    let price = (price as NSDecimalNumber)
      .dividing(by: periodsPerMonth as NSDecimalNumber,
                withBehavior: Self.roundingBehavior) as Decimal
    
    return priceAsString(locale: storeProduct.priceLocale,
                         price: NSDecimalNumber(decimal: price))
  }
  
  public var weeklyLocalizedPriceString: String? {
    let weeklyFactor: Decimal? = {
      switch period {
      case .day: return 1 / 7
      case .week: return 1
      case .month: return 1 * 30 / 7
      case .year: return 52
      case .none, .some(_):
        return nil
      }
    }()
    guard let numberOfUnits,
          let weeklyFactor else {
      return nil
    }
    
    let periodsPerWeek: Decimal = weeklyFactor * Decimal(numberOfUnits)

    let price = (price as NSDecimalNumber)
      .dividing(by: periodsPerWeek as NSDecimalNumber,
                withBehavior: Self.roundingBehavior) as Decimal
    
    return priceAsString(locale: storeProduct.priceLocale,
                         price: NSDecimalNumber(decimal: price))
  }
  
  public var dailyLocalizedPriceString: String? {
    let dayFactor: Decimal? = {
      switch period {
      case .day: return 1
      case .week: return 7
      case .month: return 30
      case .year: return 365
      case .none, .some(_):
        return nil
      }
    }()
    guard let numberOfUnits,
          let dayFactor else {
      return nil
    }
    
    let periodsPerDay: Decimal = dayFactor * Decimal(numberOfUnits)

    let price = (price as NSDecimalNumber)
      .dividing(by: periodsPerDay as NSDecimalNumber,
                withBehavior: Self.roundingBehavior) as Decimal
    
    return priceAsString(locale: storeProduct.priceLocale,
                         price: NSDecimalNumber(decimal: price))
  }
  
  public func localizedPriceWithMultiplier(_ multiplier: Double) -> String {
    return priceAsString(locale: storeProduct.priceLocale,
                         price: NSDecimalNumber(value: storeProduct.price.doubleValue * multiplier)) ?? ""
  }

  // MARK: Private
  
  private static let roundingBehavior = NSDecimalNumberHandler(
      roundingMode: .down,
      scale: 2,
      raiseOnExactness: false,
      raiseOnOverflow: false,
      raiseOnUnderflow: false,
      raiseOnDivideByZero: false
  )
  
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
