//
//  SKProductInfo.swift
//  SkarbSDK
//

import Foundation
import StoreKit

/// Product metadata, decoupled from the StoreKit version that produced it.
/// Everything the SDK and `SKOfferPackage` need is stored, not computed lazily
/// off a live `SKProduct`.
///
/// Mapped from `SKProduct` in `SKStoreKit1Mapping`, from `Product` in `SKStoreKit2Mapping`.
struct SKProductInfo {
  let productId: String
  let groupId: String
  let price: Decimal
  let priceLocale: Locale
  let currencyCode: String?
  let regionCode: String?
  let subscriptionPeriod: SKPeriodInfo?
  let introductoryOffer: SKDiscountInfo?
  let promotionalOffers: [SKDiscountInfo]
  /// Non-nil only on the StoreKit 1 path. Needed to build an `SKPayment`.
  let storeProduct: SKProduct?
}
