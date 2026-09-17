//
//  SKStoreKitObserver.swift
//  SkarbSDK
//
//  Version-neutral replacement for `SKStoreKitDelegate`, plus the two public types
//  it hands over. Called from both StoreKit implementations.
//

import Foundation

/// State of a purchase, without leaking a StoreKit type.
public enum SKPurchaseState {
  case purchasing
  case deferred
  case purchased
  case failed(Error)
}

/// Lets the host app finish a transaction itself when SkarbSDK was initialized with
/// `isObservable == true`.
///
/// The StoreKit object is wrapped so that no StoreKit 2 type appears in a public
/// signature - otherwise every public symbol would need `@available(iOS 15, *)`, which
/// would break integrators below iOS 15.
public struct SKTransactionHandle {

  private let finishAction: () -> Void
  /// Product this transaction belongs to, for logging on the host side.
  public let productId: String

  init(productId: String, finishAction: @escaping () -> Void) {
    self.productId = productId
    self.finishAction = finishAction
  }

  public func finish() {
    finishAction()
  }
}

/// - Note: every callback is delivered on the **main thread**, on both StoreKit versions, so it
/// is safe to touch UI directly. Neither the StoreKit 1 payment queue nor `Transaction.updates`
/// promises a thread of its own, so SkarbSDK dispatches.
public protocol SKStoreKitObserver: AnyObject {
  /// Called once per purchase state change. A single purchase produces exactly one `.purchased`,
  /// even though StoreKit 2 delivers the transaction through two channels.
  func skarbPurchaseStateDidChange(_ state: SKPurchaseState, productId: String)
  /// Return true to let a purchase promoted in the App Store proceed. Defaults to false.
  func skarbShouldAddStorePayment(productId: String) -> Bool
  /// Called only when SkarbSDK was initialized with `isObservable == true`.
  /// The host is then responsible for calling `handle.finish()`.
  func skarbTransactionNeedsFinish(_ handle: SKTransactionHandle)
}

public extension SKStoreKitObserver {

  func skarbShouldAddStorePayment(productId: String) -> Bool {
    return false
  }

  func skarbTransactionNeedsFinish(_ handle: SKTransactionHandle) {
    // No-op by default: most integrators let SkarbSDK finish transactions.
  }
}
