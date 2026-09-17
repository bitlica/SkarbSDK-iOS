//
//  SKPeriodInfo.swift
//  SkarbSDK
//

import Foundation
import StoreKit

/// A subscription or discount duration, decoupled from the StoreKit version that reported it.
struct SKPeriodInfo {
  let unit: SKProduct.PeriodUnit
  let count: Int

  /// StoreKit 2 can express the same subscription duration in a different unit than StoreKit 1:
  /// a weekly subscription comes back as 7 days instead of 1 week. The backend reads
  /// `Priceapi_Period.unit` as a StoreKit 1 ordinal, and `SKOfferPackage`'s per-week / per-month
  /// price math switches on the unit, so both would diverge between v1 and v2.
  ///
  /// App Store Connect only offers 1 week, 1/2/3/6 months and 1 year, so these are the only
  /// equivalences that can legitimately occur.
  static func normalized(unit: SKProduct.PeriodUnit, count: Int) -> (unit: SKProduct.PeriodUnit, count: Int) {
    guard unit == .day, count > 0 else {
      return (unit, count)
    }
    switch count {
      case 365:
        return (.year, 1)
      case 30:
        return (.month, 1)
      default:
        if count % 7 == 0 {
          return (.week, count / 7)
        }
        return (unit, count)
    }
  }
}
