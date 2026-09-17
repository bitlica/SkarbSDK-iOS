//
//  SKStoreKit1Mapping.swift
//  SkarbSDK
//
//  Everything that turns StoreKit 1 objects into the SDK's own models.
//  The StoreKit 2 counterpart is `SKStoreKit2Mapping`; keep the two in sync,
//  because both feed the same backend payload through `SKPurchaseCommandFactory`.
//

import Foundation
import StoreKit

// MARK: - Discount

extension SKDiscountInfo {

  init(skDiscount: SKProductDiscount) {
    price = skDiscount.price as Decimal
    priceLocale = skDiscount.priceLocale

    var resolvedIdentifier: String? = nil
    // Matches the previous behaviour: below iOS 12.2 there is no discount type,
    // and the old code sent `type = 0` (introductory).
    var resolvedKind: SKOfferKind = .introductory
    if #available(iOS 12.2, *) {
      resolvedIdentifier = skDiscount.identifier
      switch skDiscount.type {
        case .introductory:
          resolvedKind = .introductory
        case .subscription:
          resolvedKind = .promotional
        @unknown default:
          resolvedKind = .unknown("\(skDiscount.type.rawValue)")
      }
    }
    identifier = resolvedIdentifier
    kind = resolvedKind

    switch skDiscount.paymentMode {
      case .payAsYouGo:
        paymentMode = .payAsYouGo
      case .payUpFront:
        paymentMode = .payUpFront
      case .freeTrial:
        paymentMode = .freeTrial
      @unknown default:
        paymentMode = .unknown("\(skDiscount.paymentMode.rawValue)")
    }

    period = SKPeriodInfo(unit: skDiscount.subscriptionPeriod.unit,
                          count: skDiscount.subscriptionPeriod.numberOfUnits)
    numberOfPeriods = skDiscount.numberOfPeriods
  }
}

// MARK: - Product

extension SKProductInfo {

  init(skProduct: SKProduct) {
    productId = skProduct.productIdentifier
    if #available(iOS 12.0, *) {
      groupId = skProduct.subscriptionGroupIdentifier ?? ""
    } else {
      groupId = ""
    }
    price = skProduct.price as Decimal
    priceLocale = skProduct.priceLocale
    currencyCode = skProduct.priceLocale.currencyCode
    regionCode = skProduct.priceLocale.regionCode

    if let subscriptionPeriod = skProduct.subscriptionPeriod {
      self.subscriptionPeriod = SKPeriodInfo(unit: subscriptionPeriod.unit,
                                             count: subscriptionPeriod.numberOfUnits)
    } else {
      self.subscriptionPeriod = nil
    }

    if let introductoryPrice = skProduct.introductoryPrice {
      introductoryOffer = SKDiscountInfo(skDiscount: introductoryPrice)
    } else {
      introductoryOffer = nil
    }

    if #available(iOS 12.2, *) {
      promotionalOffers = skProduct.discounts.map { SKDiscountInfo(skDiscount: $0) }
    } else {
      promotionalOffers = []
    }

    storeProduct = skProduct
  }
}

// MARK: - Purchase event

extension SKPurchaseEvent {

  init(skTransaction: SKPaymentTransaction) {
    productId = skTransaction.payment.productIdentifier
    transactionId = skTransaction.transactionIdentifier
    transactionDate = skTransaction.transactionDate
    jws = nil
  }
}
