//
//  SKStoreKitDelegate.swift
//  SkarbSDK
//

import Foundation
import StoreKit

/// StoreKit 1 only.
///
/// Not called when SkarbSDK runs on StoreKit 2: `SKPaymentTransaction` does not exist
/// there. Adopt `SKStoreKitObserver` instead - it works for both versions.
public protocol SKStoreKitDelegate: AnyObject {
  func storeKitUpdatedTransaction(_ updatedTransaction: SKPaymentTransaction)
  func storeKit(shouldAddStorePayment payment: SKPayment,
                for product: SKProduct) -> Bool
}
