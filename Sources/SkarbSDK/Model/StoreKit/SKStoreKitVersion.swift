//
//  SKStoreKitVersion.swift
//  SkarbSDK
//

import Foundation

/// Which StoreKit API SkarbSDK uses internally.
///
/// The wire format is identical for both: the app receipt stays the transport,
/// so the backend does not need to know which one is active.
public enum SKStoreKitVersion {
  /// StoreKit 1: SKPaymentQueue + SKProductsRequest. Default.
  case v1
  /// StoreKit 2: Transaction.updates + Product.products(for:). Requires iOS 15.
  case v2
}
