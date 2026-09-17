//
//  SKSignedTransactionSelectionTests.swift
//  SkarbSDKTests
//

import XCTest
@testable import SkarbSDK

/// Covers what goes into `signed_transactions` and in what order.
///
/// This logic was rewritten three times in a day and got the cap direction wrong once, which is
/// exactly the kind of thing worth pinning down: the failure mode is silent - a request that is
/// merely too big, or one missing the purchase the user just made.
final class SKSignedTransactionSelectionTests: XCTestCase {

  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  private func candidate(id: String,
                         type: String = "Auto-Renewable Subscription",
                         purchased: TimeInterval = 0,
                         expires: TimeInterval? = nil,
                         revoked: TimeInterval? = nil,
                         jws: String = "jws") -> SKSignedTransactionCandidate {
    return SKSignedTransactionCandidate(transactionId: id,
                                        productId: "product.\(id)",
                                        productType: type,
                                        purchaseDate: now.addingTimeInterval(purchased),
                                        expirationDate: expires.map { now.addingTimeInterval($0) },
                                        revocationDate: revoked.map { now.addingTimeInterval($0) },
                                        jws: jws)
  }

  // MARK: shouldSend

  func testConsumableIsAlwaysSent() {
    // The whole point of the field: a consumable is absent from the app receipt, so nothing else
    // can prove it. It has no expiry, so the liveness rule must not be what lets it through.
    let consumable = candidate(id: "1", type: SKSignedTransactionCandidate.consumableType)
    XCTAssertTrue(SKSignedTransactionSelection.shouldSend(consumable, now: now))
  }

  func testLiveSubscriptionIsSent() {
    let live = candidate(id: "2", expires: 60)
    XCTAssertTrue(SKSignedTransactionSelection.shouldSend(live, now: now))
  }

  func testExpiredSubscriptionIsNotSent() {
    // History the backend re-reads from the receipt - sending it is what grew one call to 372 KB.
    let expired = candidate(id: "3", expires: -60)
    XCTAssertFalse(SKSignedTransactionSelection.shouldSend(expired, now: now))
  }

  func testSubscriptionExpiringExactlyNowIsNotSent() {
    // Boundary: `> now`, not `>=`. An entitlement that ends at this instant is not live.
    let edge = candidate(id: "4", expires: 0)
    XCTAssertFalse(SKSignedTransactionSelection.shouldSend(edge, now: now))
  }

  func testNonExpiringProductIsSent() {
    // A non-consumable has no expirationDate and must not be treated as expired.
    let nonConsumable = candidate(id: "5", type: "Non-Consumable", expires: nil)
    XCTAssertTrue(SKSignedTransactionSelection.shouldSend(nonConsumable, now: now))
  }

  func testRevokedIsNeverSent() {
    // Revocation wins over both rules, including for a consumable.
    let revokedConsumable = candidate(id: "6",
                                      type: SKSignedTransactionCandidate.consumableType,
                                      revoked: -10)
    let revokedLive = candidate(id: "7", expires: 60, revoked: -10)
    XCTAssertFalse(SKSignedTransactionSelection.shouldSend(revokedConsumable, now: now))
    XCTAssertFalse(SKSignedTransactionSelection.shouldSend(revokedLive, now: now))
  }

  // MARK: prepare

  func testNewestFirst() {
    // `Transaction.all` happens to arrive newest-first but Apple documents no order, so the
    // ordering has to come from here.
    let oldest = candidate(id: "old", type: SKSignedTransactionCandidate.consumableType, purchased: -300)
    let newest = candidate(id: "new", type: SKSignedTransactionCandidate.consumableType, purchased: -10)
    let middle = candidate(id: "mid", type: SKSignedTransactionCandidate.consumableType, purchased: -100)

    let prepared = SKSignedTransactionSelection.prepare([oldest, newest, middle], now: now)

    XCTAssertEqual(prepared.map { $0.transactionId }, ["new", "mid", "old"])
  }

  func testCapDropsTheOldestNotTheNewest() {
    // The direction that was wrong once: truncating the wrong end silently discards the purchase
    // the user just made, which is the only one that matters.
    let candidates = (0..<10).map {
      candidate(id: "\($0)",
                type: SKSignedTransactionCandidate.consumableType,
                purchased: TimeInterval(-$0 * 60))
    }

    let prepared = SKSignedTransactionSelection.prepare(candidates, now: now, limit: 3)

    XCTAssertEqual(prepared.count, 3)
    XCTAssertEqual(prepared.map { $0.transactionId }, ["0", "1", "2"])
  }

  func testCapIsAppliedAfterFiltering() {
    // Expired ones must not consume slots: filter first, then cap.
    let expired = (0..<5).map { candidate(id: "expired\($0)", purchased: -1, expires: -60) }
    let consumables = (0..<3).map {
      candidate(id: "kept\($0)",
                type: SKSignedTransactionCandidate.consumableType,
                purchased: TimeInterval(-$0))
    }

    let prepared = SKSignedTransactionSelection.prepare(expired + consumables, now: now, limit: 3)

    XCTAssertEqual(prepared.map { $0.transactionId }, ["kept0", "kept1", "kept2"])
  }

  func testEmptyHistoryProducesEmptyList() {
    // A user who never bought anything: the field must be absent, not a list of blanks.
    XCTAssertTrue(SKSignedTransactionSelection.prepare([], now: now).isEmpty)
  }

  func testEverythingFilteredOutProducesEmptyList() {
    let onlyExpired = (0..<3).map { candidate(id: "\($0)", expires: -1) }
    XCTAssertTrue(SKSignedTransactionSelection.prepare(onlyExpired, now: now).isEmpty)
  }

  func testDefaultLimitMatchesTheBackendContract() {
    // 200 per request, agreed with the backend and enforced in one place.
    XCTAssertEqual(Purchaseapi_ReceiptRequest.maxSignedTransactions, 200)
  }
}
