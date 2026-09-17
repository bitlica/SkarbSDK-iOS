//
//  SKPaymentMode.swift
//  SkarbSDK
//

import Foundation

// MARK: - Wire codes
//
// The backend reads `Priceapi_Discount.mode` / `.type` and `Priceapi_Period.unit` as NUMBERS,
// and those numbers are StoreKit 1 enum ordinals. StoreKit 2 uses String raw values
// ("freeTrial", "introductory", "month"), so the mapping has to be written out by hand -
// `Int32(rawValue)` silently yields nil there and would send 0 for everything.

/// How a discounted period is paid for. Numbering matches `SKProductDiscount.PaymentMode`.
enum SKPaymentMode {
  case payAsYouGo
  case payUpFront
  case freeTrial
  case unknown(String)

  var wireCode: Int32 {
    switch self {
      case .payAsYouGo: return 0
      case .payUpFront: return 1
      case .freeTrial: return 2
      case .unknown: return 0
    }
  }

  var isFreeTrial: Bool {
    if case .freeTrial = self {
      return true
    }
    return false
  }

  /// A discounted intro period the user actually pays for.
  var isPaidIntroductory: Bool {
    switch self {
      case .payUpFront, .payAsYouGo: return true
      case .freeTrial, .unknown: return false
    }
  }
}
