//
//  SKPurchaseEvent.swift
//  SkarbSDK
//

import Foundation

/// One observed purchase, decoupled from the StoreKit version that reported it.
/// This is what `SKPurchaseCommandFactory` consumes, so both implementations
/// produce byte-identical backend payloads.
///
/// Mapped from `SKPaymentTransaction` in `SKStoreKit1Mapping`,
/// from `StoreKit.Transaction` in `SKStoreKit2Mapping`.
struct SKPurchaseEvent {
  let productId: String
  /// Optional to match StoreKit 1, where `transactionIdentifier` can be nil and
  /// such transactions were dropped from the reported id list.
  let transactionId: String?
  let transactionDate: Date?
  /// StoreKit 2 signed transaction (JWS). Captured now, not sent yet: no proto field
  /// carries it. Wiring it up later is one line in the command factory.
  let jws: String?
}
