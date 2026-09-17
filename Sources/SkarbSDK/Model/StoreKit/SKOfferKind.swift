//
//  SKOfferKind.swift
//  SkarbSDK
//

import Foundation

/// What kind of offer this is. Numbering matches `SKProductDiscount.Type`,
/// where StoreKit 1 calls a promotional offer `.subscription`.
///
/// See `SKPaymentMode` for why these numbers are written out by hand instead of
/// being taken from a StoreKit raw value.
enum SKOfferKind {
  case introductory
  case promotional
  /// iOS 18+, StoreKit 2 only. Has no StoreKit 1 counterpart.
  case winBack
  case unknown(String)

  var wireCode: Int32 {
    switch self {
      case .introductory: return 0
      case .promotional: return 1
      // OPEN QUESTION for the backend: win-back offers have no StoreKit 1 code.
      // Reported as `promotional` until a code is assigned, so they are at least
      // not confused with introductory offers.
      case .winBack: return 1
      case .unknown: return 0
    }
  }
}
