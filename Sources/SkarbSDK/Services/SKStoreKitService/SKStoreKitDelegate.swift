//
//  SKStoreKitDelegate.swift
//  SkarbSDK
//

import Foundation
import StoreKit

/// `storeKitUpdatedTransaction` fires on StoreKit 1 only; `storeKit(shouldAddStorePayment:for:)`
/// fires on both and is why this protocol is still here - the observer's version of it carries
/// only a `productId`, while a promoted purchase needs the `SKPayment` object itself.
/// Transaction updates are deliberately not forwarded under StoreKit 2: the queue's object there
/// is a partial view, with the identifier but no Apple signature. Use `SKStoreKitObserver`.
public protocol SKStoreKitDelegate: AnyObject {
  func storeKitUpdatedTransaction(_ updatedTransaction: SKPaymentTransaction)
  func storeKit(shouldAddStorePayment payment: SKPayment,
                for product: SKProduct) -> Bool
}
