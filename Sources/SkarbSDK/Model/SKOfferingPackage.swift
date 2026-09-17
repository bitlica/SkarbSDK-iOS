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

/// Introductory offer of a package, as a value type, so host apps never need to reach
/// through to `SKProduct.introductoryPrice`.
public struct SKIntroductoryOffer {
  public let price: Decimal
  public let priceLocale: Locale
  public let identifier: String?
  public let periodUnit: SKProduct.PeriodUnit
  public let periodDuration: Int
  public let numberOfPeriods: Int
  /// True for a free trial, false for a paid introductory period.
  public let isFreeTrial: Bool
}

public struct SKOfferPackage {
  public let id: String
  public let description: String
  public let productId: String
  public let purchaseType: PurchaseType

  /// The raw StoreKit 1 product.
  ///
  /// - Warning: `nil` when SkarbSDK runs on StoreKit 2, where `SKProduct` does not exist.
  /// Everything this used to be reached through for is exposed directly on the package:
  /// `priceLocale`, `period`, `numberOfUnits`, `discountPeriod`, `discountPeriodDuration`.
  public let storeProduct: SKProduct?

  /// Product metadata, independent of the StoreKit version that produced it.
  let productInfo: SKProductInfo

  init(package: Setupsapi_Package, productInfo: SKProductInfo) {
    self.id = package.id
    self.description = package.description_p
    self.productId = package.productID
    self.purchaseType = PurchaseType.initWith(string: package.purchaseType)
    self.productInfo = productInfo
    self.storeProduct = productInfo.storeProduct
  }

  public var isTrial: Bool {
    guard let intro = productInfo.introductoryOffer else {
      return false
    }
    return intro.paymentMode.isFreeTrial
  }

  public var isIntroPriceOrPeriod: Bool {
    guard let intro = productInfo.introductoryOffer else {
      return false
    }
    return intro.paymentMode.isPaidIntroductory
  }

  public var isSubscription: Bool {
    return productInfo.subscriptionPeriod != nil
  }

  public var period: SKProduct.PeriodUnit? {
    return productInfo.subscriptionPeriod?.unit
  }

  /// Same value as `period`, under a name that cannot be shadowed by a host app's own
  /// `period` extension on this type.
  public var subscriptionPeriodUnit: SKProduct.PeriodUnit? {
    return productInfo.subscriptionPeriod?.unit
  }

  public var introductoryOffer: SKIntroductoryOffer? {
    guard let intro = productInfo.introductoryOffer else {
      return nil
    }
    return SKIntroductoryOffer(price: intro.price,
                               priceLocale: intro.priceLocale,
                               identifier: intro.identifier,
                               periodUnit: intro.period.unit,
                               periodDuration: intro.period.count,
                               numberOfPeriods: intro.numberOfPeriods,
                               isFreeTrial: intro.paymentMode.isFreeTrial)
  }

  /// Locale the price is formatted in. On StoreKit 1 this is `SKProduct.priceLocale`,
  /// on StoreKit 2 it is `Product.priceFormatStyle.locale`.
  public var priceLocale: Locale {
    return productInfo.priceLocale
  }

  public var trialPeriodDuration: Int? {
    isTrial ? productInfo.introductoryOffer?.period.count : nil
  }

  public var trialExpirationDateFromToday: Date? {
    guard isTrial,
    let discountPeriodDuration = discountPeriodDuration,
          let discountPeriod = discountPeriod else {
      return nil
    }

    let days: Int
    switch discountPeriod {
    case .day:
      days = 1
    case .week:
      days = 7
    case .month:
      days = 30
    case .year:
      days = 365
    @unknown default:
      days = 0
    }

    let calendar = Calendar.current
    let today = Date()
    guard let trialExpDate = calendar.date(
      byAdding: .day,
      value: days * discountPeriodDuration,
      to: today
    ) else {
      return nil
    }

    return trialExpDate
  }

  public var discountPeriodDuration: Int? {
    productInfo.introductoryOffer?.period.count
  }

  public var discountPeriod: SKProduct.PeriodUnit? {
    productInfo.introductoryOffer?.period.unit
  }

  public var numberOfUnits: Int? {
    return productInfo.subscriptionPeriod?.count
  }

  public var price: Decimal {
    return productInfo.price
  }

  public var currencyCode: String? {
    return productInfo.currencyCode
  }

  public var localizedPriceString: String {
    return priceAsString(locale: productInfo.priceLocale,
                         price: NSDecimalNumber(decimal: productInfo.price)) ?? ""
  }

  public var localizedIntroductoryPriceString: String? {
    guard let intro = productInfo.introductoryOffer else {
      return nil
    }

    return priceAsString(locale: intro.priceLocale,
                         price: NSDecimalNumber(decimal: intro.price))
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

    return priceAsString(locale: productInfo.priceLocale,
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

    return priceAsString(locale: productInfo.priceLocale,
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

    return priceAsString(locale: productInfo.priceLocale,
                         price: NSDecimalNumber(decimal: price))
  }

  public func localizedPriceWithMultiplier(_ multiplier: Double) -> String {
    let base = NSDecimalNumber(decimal: productInfo.price).doubleValue
    return priceAsString(locale: productInfo.priceLocale,
                         price: NSDecimalNumber(value: base * multiplier)) ?? ""
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
