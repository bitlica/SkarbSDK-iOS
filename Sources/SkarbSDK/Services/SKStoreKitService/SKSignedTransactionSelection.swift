//
//  SKSignedTransactionSelection.swift
//  SkarbSDK
//

import Foundation

/// One transaction as far as `signed_transactions` is concerned.
///
/// Deliberately free of StoreKit types: `StoreKit.Transaction` has no public initializer, so
/// selection logic that touches it directly cannot be tested. Everything the choice depends on
/// is copied in here, and the choice itself lives in `SKSignedTransactionSelection`.
struct SKSignedTransactionCandidate: Equatable {
  let transactionId: String
  let productId: String
  /// `Product.ProductType.rawValue` - "Consumable", "Auto-Renewable Subscription", and so on.
  let productType: String
  let purchaseDate: Date
  /// nil for products that do not expire.
  let expirationDate: Date?
  /// Non-nil once Apple has revoked the purchase.
  let revocationDate: Date?
  let jws: String

  static let consumableType = "Consumable"
}

/// Decides what goes into `signed_transactions` and in what order.
enum SKSignedTransactionSelection {

  /// Should this transaction be sent at all.
  ///
  /// Two kinds are worth the bytes:
  ///
  /// - **consumables**, because they are the only thing the backend cannot resolve on its own: a
  ///   StoreKit 2 app receipt never carries a consumable, so there is no `in_app` entry to key
  ///   on. Measured 14.09.2026 - seven receipts pulled off a device, zero consumables in any.
  /// - **entitlements that are live right now**, which is the question `verifyReceipt` is asked.
  ///
  /// Everything else is expired subscriptions and past renewals, history the backend already
  /// holds and re-reads from the receipt. Sending all of it grew one call to 372 KB on a test
  /// device (69 transactions) without adding information.
  ///
  /// Revoked purchases are dropped whatever their type: they prove nothing, and the backend
  /// learned about the refund from Apple.
  static func shouldSend(_ candidate: SKSignedTransactionCandidate, now: Date) -> Bool {
    guard candidate.revocationDate == nil else {
      return false
    }
    if candidate.productType == SKSignedTransactionCandidate.consumableType {
      return true
    }
    return (candidate.expirationDate ?? .distantFuture) > now
  }

  /// Filters, orders newest first, and applies the per-request cap.
  ///
  /// The order is set here rather than inherited from `Transaction.all`: Apple documents no
  /// ordering for it, and when the cap bites it has to drop the OLDEST - transactions the
  /// backend processed long ago - rather than the purchase made a second ago.
  static func prepare(_ candidates: [SKSignedTransactionCandidate],
                      now: Date,
                      limit: Int = Purchaseapi_ReceiptRequest.maxSignedTransactions) -> [SKSignedTransactionCandidate] {
    let kept = candidates
      .filter { shouldSend($0, now: now) }
      .sorted { $0.purchaseDate > $1.purchaseDate }
    guard kept.count > limit else {
      return kept
    }
    return Array(kept.prefix(limit))
  }
}
