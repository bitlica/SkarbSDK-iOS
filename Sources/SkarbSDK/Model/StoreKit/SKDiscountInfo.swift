//
//  SKDiscountInfo.swift
//  SkarbSDK
//

import Foundation

/// An introductory, promotional or win-back offer, decoupled from the StoreKit version
/// that reported it. `kind` and `paymentMode` carry the numeric wire codes.
struct SKDiscountInfo {
  let price: Decimal
  let priceLocale: Locale
  let identifier: String?
  let kind: SKOfferKind
  let paymentMode: SKPaymentMode
  let period: SKPeriodInfo
  let numberOfPeriods: Int
}
