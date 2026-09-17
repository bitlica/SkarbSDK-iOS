//
//  SKStoreKit2Mapping.swift
//  SkarbSDK
//
//  Everything that turns StoreKit 2 objects into the SDK's own models.
//  The StoreKit 1 counterpart is `SKStoreKit1Mapping`; keep the two in sync,
//  because both feed the same backend payload through `SKPurchaseCommandFactory`.
//

import Foundation
import StoreKit

// MARK: - Period

@available(iOS 15.0, *)
extension SKPeriodInfo {

  init(subscriptionPeriod: Product.SubscriptionPeriod) {
    var resolvedUnit: SKProduct.PeriodUnit = .day
    switch subscriptionPeriod.unit {
      case .day:
        resolvedUnit = .day
      case .week:
        resolvedUnit = .week
      case .month:
        resolvedUnit = .month
      case .year:
        resolvedUnit = .year
      @unknown default:
        SKLogger.logError("SKPeriodInfo: unknown StoreKit 2 period unit \(subscriptionPeriod.unit). Falling back to .day",
                          features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                     SKLoggerFeatureType.internalValue.name: "\(subscriptionPeriod.unit)"])
    }

    let normalized = SKPeriodInfo.normalized(unit: resolvedUnit, count: subscriptionPeriod.value)
    if normalized.unit != resolvedUnit || normalized.count != subscriptionPeriod.value {
      SKLogger.logInfo("SKPeriodInfo: normalized StoreKit 2 period \(resolvedUnit.rawValue)/\(subscriptionPeriod.value) to \(normalized.unit.rawValue)/\(normalized.count) to match StoreKit 1")
    }
    unit = normalized.unit
    count = normalized.count
  }
}

// MARK: - Discount

@available(iOS 15.0, *)
extension SKDiscountInfo {

  init(subscriptionOffer offer: Product.SubscriptionOffer, priceLocale: Locale) {
    price = offer.price
    self.priceLocale = priceLocale
    identifier = offer.id

    // `OfferType` and `PaymentMode` are RawRepresentable structs, not enums, so this is
    // `==` rather than an exhaustive switch. `.winBack` is matched by raw value because
    // the static member itself is iOS 18+ and we still build for lower targets.
    if offer.type == .introductory {
      kind = .introductory
    } else if offer.type == .promotional {
      kind = .promotional
    } else if offer.type.rawValue == "winBack" {
      kind = .winBack
    } else {
      kind = .unknown(offer.type.rawValue)
    }

    if offer.paymentMode == .payAsYouGo {
      paymentMode = .payAsYouGo
    } else if offer.paymentMode == .payUpFront {
      paymentMode = .payUpFront
    } else if offer.paymentMode == .freeTrial {
      paymentMode = .freeTrial
    } else {
      paymentMode = .unknown(offer.paymentMode.rawValue)
    }

    period = SKPeriodInfo(subscriptionPeriod: offer.period)
    numberOfPeriods = offer.periodCount
  }
}

// MARK: - Product

@available(iOS 15.0, *)
extension SKProductInfo {

  init(product: Product) {
    productId = product.id
    groupId = product.subscription?.subscriptionGroupID ?? ""
    price = product.price

    let formatStyle = product.priceFormatStyle
    priceLocale = formatStyle.locale
    currencyCode = formatStyle.currencyCode
    regionCode = formatStyle.locale.regionCode

    if let subscription = product.subscription {
      subscriptionPeriod = SKPeriodInfo(subscriptionPeriod: subscription.subscriptionPeriod)
      if let introductoryOffer = subscription.introductoryOffer {
        self.introductoryOffer = SKDiscountInfo(subscriptionOffer: introductoryOffer,
                                                priceLocale: formatStyle.locale)
      } else {
        self.introductoryOffer = nil
      }
      promotionalOffers = subscription.promotionalOffers.map {
        SKDiscountInfo(subscriptionOffer: $0, priceLocale: formatStyle.locale)
      }
    } else {
      subscriptionPeriod = nil
      introductoryOffer = nil
      promotionalOffers = []
    }

    storeProduct = nil
  }
}

// MARK: - Purchase event

@available(iOS 15.0, *)
extension SKPurchaseEvent {

  init(transaction: StoreKit.Transaction, jws: String?) {
    productId = transaction.productID
    // `Transaction.id` is UInt64 and always present, unlike StoreKit 1's optional.
    transactionId = String(transaction.id)
    transactionDate = transaction.purchaseDate
    self.jws = jws
  }
}
