//
//  SKPurchaseCommandFactoryTests.swift
//  SkarbSDKTests
//

import XCTest
import StoreKit
@testable import SkarbSDK

/// Every decision `SKPurchaseCommandFactory` makes before it touches the command store. The
/// builders themselves write to `SKServiceRegistry.commandStore`, which reaches UserDefaults and
/// kicks the sync service, so only the decisions can be exercised off-device.
final class SKPurchaseCommandFactoryTests: XCTestCase {

  private let subscriptionId = "test.sub.3ac9"
  private let consumableId = "test.pack.7f21"
  private let jws = "jws-stub-4c8e1a"
  private let january = Date(timeIntervalSince1970: 1_700_000_000)

  // MARK: shouldSendReceipt

  /// A subscription with an intro offer whose purchase carries no signature - the StoreKit 1
  /// case. The receipt is skipped, as it always was: the system rewrites it after the purchase
  /// and the next call picks the purchase up from there.
  func testSubscriptionWithIntroOfferSkipsTheReceiptWhenThereIsNoSignature() {
    let events = [event(productId: subscriptionId, transactionId: "1")]

    XCTAssertFalse(SKPurchaseCommandFactory.shouldSendReceipt(productId: subscriptionId,
                                                              events: events,
                                                              product: productInfo(subscriptionId, hasIntroOffer: true)))
  }

  /// The same product on StoreKit 2. Nothing rewrites the receipt there, and `transactionV4` has
  /// no field for a signed transaction - so skipping `setReceipt` would drop the only proof of
  /// the purchase. The intro-offer rule has to yield.
  func testSignedTransactionForcesTheReceiptEvenWithAnIntroOffer() {
    let events = [event(productId: subscriptionId, transactionId: "1", jws: jws)]

    XCTAssertTrue(SKPurchaseCommandFactory.shouldSendReceipt(productId: subscriptionId,
                                                             events: events,
                                                             product: productInfo(subscriptionId, hasIntroOffer: true)))
  }

  func testSubscriptionWithoutAnIntroOfferAlwaysSendsTheReceipt() {
    let events = [event(productId: subscriptionId, transactionId: "1")]

    XCTAssertTrue(SKPurchaseCommandFactory.shouldSendReceipt(productId: subscriptionId,
                                                             events: events,
                                                             product: productInfo(subscriptionId, hasIntroOffer: false)))
  }

  func testProductWithoutMetadataAlwaysSendsTheReceipt() {
    // Unchanged from StoreKit 1: without metadata the purchase might be a one-time one, and
    // losing those is worse than sending a receipt that was not needed.
    let events = [event(productId: consumableId, transactionId: "1")]

    XCTAssertTrue(SKPurchaseCommandFactory.shouldSendReceipt(productId: consumableId,
                                                             events: events,
                                                             product: nil))
  }

  func testAnotherProductsSignatureDoesNotForceThisProductsReceipt() {
    // One command can carry several purchases. The rule is per product, not per batch.
    let events = [
      event(productId: subscriptionId, transactionId: "1"),
      event(productId: consumableId, transactionId: "2", jws: jws)
    ]

    XCTAssertFalse(SKPurchaseCommandFactory.shouldSendReceipt(productId: subscriptionId,
                                                              events: events,
                                                              product: productInfo(subscriptionId, hasIntroOffer: true)))
  }

  func testOneSignedPurchaseOutOfSeveralForTheSameProductForcesTheReceipt() {
    // A renewal reported without a signature next to the purchase that has one: the signature
    // still has to travel, so the whole product sends its receipt.
    let events = [
      event(productId: subscriptionId, transactionId: "1"),
      event(productId: subscriptionId, transactionId: "2", jws: jws)
    ]

    XCTAssertTrue(SKPurchaseCommandFactory.shouldSendReceipt(productId: subscriptionId,
                                                             events: events,
                                                             product: productInfo(subscriptionId, hasIntroOffer: true)))
  }

  func testProductWithAnIntroOfferAndNoEventsAtAllSkipsTheReceipt() {
    XCTAssertFalse(SKPurchaseCommandFactory.shouldSendReceipt(productId: subscriptionId,
                                                              events: [],
                                                              product: productInfo(subscriptionId, hasIntroOffer: true)))
  }

  // MARK: unreportedEvents

  func testPurchasesTheBackendHasNotSeenAreAllKept() {
    let events = [
      event(productId: subscriptionId, transactionId: "1"),
      event(productId: consumableId, transactionId: "2")
    ]

    let kept = SKPurchaseCommandFactory.unreportedEvents(events, newTransactionIds: ["1", "2"])

    XCTAssertEqual(kept.map { $0.transactionId }, ["1", "2"])
  }

  func testAlreadyReportedPurchasesAreDroppedAndTheRestKeepTheirOrder() {
    // The gap this closed: before it, `setReceipt` / `priceV4` / `fetchProducts` were rebuilt
    // for a purchase that had already been queued, while only `transactionV4` was protected.
    let events = [
      event(productId: subscriptionId, transactionId: "1"),
      event(productId: consumableId, transactionId: "2"),
      event(productId: consumableId, transactionId: "3")
    ]

    let kept = SKPurchaseCommandFactory.unreportedEvents(events, newTransactionIds: ["3"])

    XCTAssertEqual(kept.map { $0.transactionId }, ["3"])
  }

  func testNothingIsKeptWhenTheBackendAlreadyHasEveryPurchase() {
    let events = [
      event(productId: subscriptionId, transactionId: "1"),
      event(productId: consumableId, transactionId: "2")
    ]

    XCTAssertTrue(SKPurchaseCommandFactory.unreportedEvents(events, newTransactionIds: []).isEmpty)
  }

  func testPurchasesWithoutATransactionIdAreNeverFilteredOut() {
    // StoreKit 1 can report a purchase with no identifier at all, and those were always let
    // through - dropping them would silently lose purchases that have nothing to dedup against.
    let events = [
      event(productId: subscriptionId, transactionId: nil),
      event(productId: consumableId, transactionId: nil)
    ]

    let kept = SKPurchaseCommandFactory.unreportedEvents(events, newTransactionIds: [])

    XCTAssertEqual(kept.map { $0.productId }, [subscriptionId, consumableId])
  }

  func testNothingComesOutOfAnEmptyBatch() {
    XCTAssertTrue(SKPurchaseCommandFactory.unreportedEvents([], newTransactionIds: ["1"]).isEmpty)
  }

  func testAnIdentifierlessPurchaseSurvivesAlongsideADroppedOne() {
    let events = [
      event(productId: subscriptionId, transactionId: "1"),
      event(productId: consumableId, transactionId: nil)
    ]

    let kept = SKPurchaseCommandFactory.unreportedEvents(events, newTransactionIds: [])

    XCTAssertEqual(kept.count, 1)
    XCTAssertEqual(kept.first?.productId, consumableId)
  }

  func testTheSameTransactionReportedTwiceIsKeptOrDroppedTogether() {
    // Both channels can hand over the same id in one batch. Whatever happens, they agree.
    let events = [
      event(productId: subscriptionId, transactionId: "1"),
      event(productId: subscriptionId, transactionId: "1", jws: jws)
    ]

    XCTAssertEqual(SKPurchaseCommandFactory.unreportedEvents(events, newTransactionIds: ["1"]).count, 2)
    XCTAssertEqual(SKPurchaseCommandFactory.unreportedEvents(events, newTransactionIds: []).count, 0)
  }

  /// `newEvents` is the wrapper that asks the command store which ids are new. It short-circuits
  /// before that read when nothing in the batch has an id, which is the one case it can be
  /// exercised in without a store.
  func testNewEventsSkipsTheStoreEntirelyWhenNoPurchaseHasAnId() {
    let events = [
      event(productId: subscriptionId, transactionId: nil),
      event(productId: consumableId, transactionId: nil)
    ]

    XCTAssertEqual(SKPurchaseCommandFactory.newEvents(events).count, 2)
  }

  // MARK: fetchProducts

  func testEachPurchasedProductGetsOneFetchProduct() {
    let events = [
      event(productId: subscriptionId, transactionId: "1", date: january),
      event(productId: consumableId, transactionId: "2", date: january)
    ]

    let fetched = SKPurchaseCommandFactory.fetchProducts(for: events)

    XCTAssertEqual(fetched.count, 2)
    XCTAssertEqual(Set(fetched.map { $0.productId }), [subscriptionId, consumableId])
  }

  func testSeveralPurchasesOfOneProductCollapseToItsNewest() {
    // The command carries one transaction per product, and it has to be the latest one -
    // a renewal must not be reported under the id of the purchase that preceded it.
    let events = [
      event(productId: subscriptionId, transactionId: "old", date: january),
      event(productId: subscriptionId, transactionId: "new", date: january.addingTimeInterval(60)),
      event(productId: subscriptionId, transactionId: "middle", date: january.addingTimeInterval(30))
    ]

    let fetched = SKPurchaseCommandFactory.fetchProducts(for: events)

    XCTAssertEqual(fetched.count, 1)
    XCTAssertEqual(fetched.first?.transactionId, "new")
    XCTAssertEqual(fetched.first?.transactionDate, january.addingTimeInterval(60))
  }

  func testAPurchaseWithADateBeatsOneWithout() {
    // An unknown date must not pass for the most recent purchase.
    let events = [
      event(productId: subscriptionId, transactionId: "dated", date: january),
      event(productId: subscriptionId, transactionId: "undated", date: nil)
    ]

    XCTAssertEqual(SKPurchaseCommandFactory.fetchProducts(for: events).first?.transactionId, "dated")
  }

  func testPurchasesWithoutDatesStillProduceAFetchProduct() {
    let events = [
      event(productId: subscriptionId, transactionId: "1", date: nil),
      event(productId: subscriptionId, transactionId: "2", date: nil)
    ]

    let fetched = SKPurchaseCommandFactory.fetchProducts(for: events)

    XCTAssertEqual(fetched.count, 1)
    XCTAssertNil(fetched.first?.transactionDate)
  }

  func testAPurchaseWithoutAnIdStillProducesAFetchProduct() {
    // `fetchProducts` is what resolves the product metadata, and that is worth having even for a
    // StoreKit 1 transaction that came without an identifier.
    let events = [event(productId: consumableId, transactionId: nil, date: january)]

    let fetched = SKPurchaseCommandFactory.fetchProducts(for: events)

    XCTAssertEqual(fetched.count, 1)
    XCTAssertEqual(fetched.first?.productId, consumableId)
    XCTAssertNil(fetched.first?.transactionId)
  }

  func testPurchasesSharingADateStillCollapseToOneFetchProduct() {
    // `sorted` is not guaranteed stable, so which of two equally dated purchases wins is not
    // pinned here - only that exactly one comes out and it is one of the two.
    let events = [
      event(productId: subscriptionId, transactionId: "a", date: january),
      event(productId: subscriptionId, transactionId: "b", date: january)
    ]

    let fetched = SKPurchaseCommandFactory.fetchProducts(for: events)

    XCTAssertEqual(fetched.count, 1)
    XCTAssertTrue(["a", "b"].contains(fetched.first?.transactionId ?? ""))
  }

  func testNoPurchasesProduceNoFetchProducts() {
    XCTAssertTrue(SKPurchaseCommandFactory.fetchProducts(for: []).isEmpty)
  }

  // MARK: priceProducts

  func testPriceProductsAreBuiltFromTheFetchedMetadata() {
    let fetchProducts = [SKFetchProduct(productId: subscriptionId,
                                        transactionDate: january,
                                        transactionId: "5500000000001")]

    let result = SKPurchaseCommandFactory.priceProducts(for: fetchProducts,
                                                        products: [productInfo(subscriptionId, hasIntroOffer: true)])

    XCTAssertTrue(result.missingProductIds.isEmpty)
    XCTAssertEqual(result.products.count, 1)
    XCTAssertEqual(result.products.first?.productID, subscriptionId)
    XCTAssertEqual(result.products.first?.transaction, "5500000000001")
    XCTAssertEqual(result.products.first?.tranDate.seconds, 1_700_000_000)
    XCTAssertEqual(result.products.first?.price, 9.99)
  }

  func testAProductWhoseMetadataNeverArrivedIsReportedAsMissing() {
    // The App Store answers a fetch without the products it does not know, and that used to be
    // logged from inside the building loop - where an error log queues a command of its own.
    let fetchProducts = [
      SKFetchProduct(productId: subscriptionId, transactionDate: january, transactionId: "1"),
      SKFetchProduct(productId: consumableId, transactionDate: january, transactionId: "2")
    ]

    let result = SKPurchaseCommandFactory.priceProducts(for: fetchProducts,
                                                        products: [productInfo(subscriptionId, hasIntroOffer: false)])

    XCTAssertEqual(result.products.map { $0.productID }, [subscriptionId])
    XCTAssertEqual(result.missingProductIds, [consumableId])
  }

  func testNoMetadataAtAllProducesNoPricePayload() {
    // What makes `createPriceCommand` return without queueing anything.
    let fetchProducts = [SKFetchProduct(productId: subscriptionId, transactionDate: january, transactionId: "1")]

    let result = SKPurchaseCommandFactory.priceProducts(for: fetchProducts, products: [])

    XCTAssertTrue(result.products.isEmpty)
    XCTAssertEqual(result.missingProductIds, [subscriptionId])
  }

  func testMetadataNobodyAskedForIsIgnored() {
    // The fetch answers with every product in one response, including ones this command is not
    // about. Only what was actually fetched may end up in `priceV4`.
    let fetchProducts = [SKFetchProduct(productId: subscriptionId, transactionDate: january, transactionId: "1")]

    let result = SKPurchaseCommandFactory.priceProducts(for: fetchProducts,
                                                        products: [productInfo(subscriptionId, hasIntroOffer: true),
                                                                   productInfo(consumableId, hasIntroOffer: false)])

    XCTAssertEqual(result.products.map { $0.productID }, [subscriptionId])
  }

  func testTheSameProductFetchedTwiceIsPricedTwice() {
    // `fetchProducts(for:)` never produces a duplicate, but a command decoded from the queue can
    // carry one. Documented rather than defended against: the backend sees two identical prices.
    let fetchProducts = [
      SKFetchProduct(productId: subscriptionId, transactionDate: january, transactionId: "1"),
      SKFetchProduct(productId: subscriptionId, transactionDate: january, transactionId: "1")
    ]

    let result = SKPurchaseCommandFactory.priceProducts(for: fetchProducts,
                                                        products: [productInfo(subscriptionId, hasIntroOffer: true)])

    XCTAssertEqual(result.products.count, 2)
  }

  func testNoFetchProductsProduceNothingAtAll() {
    let result = SKPurchaseCommandFactory.priceProducts(for: [],
                                                        products: [productInfo(subscriptionId, hasIntroOffer: true)])

    XCTAssertTrue(result.products.isEmpty)
    XCTAssertTrue(result.missingProductIds.isEmpty)
  }

  func testAPurchaseWithoutATransactionIdKeepsAnEmptyIdOnTheWire() {
    let fetchProducts = [SKFetchProduct(productId: subscriptionId, transactionDate: nil, transactionId: nil)]

    let result = SKPurchaseCommandFactory.priceProducts(for: fetchProducts,
                                                        products: [productInfo(subscriptionId, hasIntroOffer: true)])

    XCTAssertEqual(result.products.first?.transaction, "")
    XCTAssertEqual(result.products.first?.tranDate.seconds, 0)
  }

  // MARK: Helpers

  private func event(productId: String,
                     transactionId: String?,
                     date: Date? = nil,
                     jws: String? = nil) -> SKPurchaseEvent {
    return SKPurchaseEvent(productId: productId,
                           transactionId: transactionId,
                           transactionDate: date,
                           jws: jws)
  }

  private func productInfo(_ productId: String, hasIntroOffer: Bool) -> SKProductInfo {
    let locale = Locale(identifier: "en_US")
    let week = SKPeriodInfo(unit: .week, count: 1)
    let introductoryOffer = SKDiscountInfo(price: 0,
                                           priceLocale: locale,
                                           identifier: "intro.1",
                                           kind: .introductory,
                                           paymentMode: .freeTrial,
                                           period: SKPeriodInfo(unit: .day, count: 3),
                                           numberOfPeriods: 1)
    return SKProductInfo(productId: productId,
                         groupId: "group.1",
                         price: 9.99,
                         priceLocale: locale,
                         currencyCode: "USD",
                         regionCode: "US",
                         subscriptionPeriod: week,
                         introductoryOffer: hasIntroOffer ? introductoryOffer : nil,
                         promotionalOffers: [],
                         storeProduct: nil)
  }
}
