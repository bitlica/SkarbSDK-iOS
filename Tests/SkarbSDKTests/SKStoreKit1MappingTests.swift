//
//  SKStoreKit1MappingTests.swift
//  SkarbSDKTests
//

import XCTest
import StoreKit
@testable import SkarbSDK

/// StoreKit 1 is still the default, and the StoreKit 2 work moved every product and purchase
/// field through a new intermediate model (`SKProductInfo` / `SKPurchaseEvent`). These tests pin
/// the StoreKit 1 side of that model: what reaches the backend, and what `SKOfferPackage` exposes
/// to host apps.
///
/// The codes are the point. `Priceapi_Period.unit` is a *stringified StoreKit 1 ordinal* and
/// `Priceapi_Discount.type` / `.mode` are StoreKit 1 ordinals as numbers - the backend reads them
/// as numbers, nothing validates them, and a wrong value shows up months later as skewed
/// analytics rather than as a failure.
final class SKStoreKit1MappingTests: XCTestCase {

  // MARK: Product metadata

  func testProductMappingKeepsEveryFieldTheSDKReads() {
    let product = FakeProduct(identifier: "com.bitlica.weekly",
                              price: 9.99,
                              locale: Locale(identifier: "en_US"),
                              groupId: "group.1",
                              period: FakePeriod(unit: .week, numberOfUnits: 1),
                              introductory: FakeDiscount(price: 0,
                                                         locale: Locale(identifier: "en_US"),
                                                         identifier: "intro.1",
                                                         period: FakePeriod(unit: .day, numberOfUnits: 3),
                                                         numberOfPeriods: 1,
                                                         paymentMode: .freeTrial,
                                                         type: .introductory))

    let info = SKProductInfo(skProduct: product)

    XCTAssertEqual(info.productId, "com.bitlica.weekly")
    XCTAssertEqual(info.groupId, "group.1")
    XCTAssertEqual(info.price, Decimal(string: "9.99"))
    XCTAssertEqual(info.currencyCode, "USD")
    XCTAssertEqual(info.regionCode, "US")
    XCTAssertEqual(info.subscriptionPeriod?.unit, .week)
    XCTAssertEqual(info.subscriptionPeriod?.count, 1)
    XCTAssertEqual(info.introductoryOffer?.identifier, "intro.1")
    XCTAssertEqual(info.introductoryOffer?.numberOfPeriods, 1)
    XCTAssertTrue(info.introductoryOffer?.paymentMode.isFreeTrial ?? false)
    // Still the live StoreKit 1 object: `SKOfferPackage.storeProduct` is deprecated but must keep
    // working on v1 - host apps build `SKPayment` from it.
    XCTAssertTrue(info.storeProduct === product)
  }

  func testSubscriptionPeriodIsNotNormalizedOnStoreKit1() {
    // `SKPeriodInfo.normalized` exists because StoreKit 2 reports a weekly subscription as 7 days.
    // It is applied on the StoreKit 2 path only: whatever StoreKit 1 says is what has always been
    // sent, and rewriting it here would change the v1 wire payload.
    let product = FakeProduct(identifier: "p",
                              price: 1,
                              locale: Locale(identifier: "en_US"),
                              period: FakePeriod(unit: .day, numberOfUnits: 7))

    let info = SKProductInfo(skProduct: product)

    XCTAssertEqual(info.subscriptionPeriod?.unit, .day)
    XCTAssertEqual(info.subscriptionPeriod?.count, 7)
  }

  func testProductWithoutSubscriptionMapsToNoPeriodAndNoOffer() {
    let product = FakeProduct(identifier: "coinspack.m4", price: 4.99, locale: Locale(identifier: "en_US"))

    let info = SKProductInfo(skProduct: product)

    XCTAssertNil(info.subscriptionPeriod)
    XCTAssertNil(info.introductoryOffer)
    XCTAssertTrue(info.promotionalOffers.isEmpty)
    XCTAssertEqual(info.groupId, "")
  }

  // MARK: Wire codes

  func testPeriodUnitsKeepTheirStoreKit1Ordinals() {
    let expected: [(SKProduct.PeriodUnit, String)] = [(.day, "0"), (.week, "1"), (.month, "2"), (.year, "3")]

    for (unit, wire) in expected {
      let period = Priceapi_Period(period: SKPeriodInfo(unit: unit, count: 2))
      XCTAssertEqual(period.unit, wire, "unit \(unit) must go out as \"\(wire)\"")
      XCTAssertEqual(period.count, 2)
    }
  }

  func testDiscountTypeAndModeKeepTheirStoreKit1Ordinals() {
    let cases: [(SKProductDiscount.PaymentMode, SKProductDiscount.`Type`, Int32, Int32)] = [
      (.payAsYouGo, .introductory, 0, 0),
      (.payUpFront, .introductory, 0, 1),
      (.freeTrial, .introductory, 0, 2),
      // StoreKit 1 calls a promotional offer `.subscription`, and its ordinal is 1.
      (.payUpFront, .subscription, 1, 1)
    ]

    for (mode, type, expectedType, expectedMode) in cases {
      let discount = FakeDiscount(price: 1,
                                  locale: Locale(identifier: "en_US"),
                                  identifier: "offer",
                                  period: FakePeriod(unit: .month, numberOfUnits: 1),
                                  numberOfPeriods: 2,
                                  paymentMode: mode,
                                  type: type)

      let wire = Priceapi_Discount(discount: SKDiscountInfo(skDiscount: discount))

      XCTAssertEqual(wire.type, expectedType, "type for \(type)")
      XCTAssertEqual(wire.mode, expectedMode, "mode for \(mode)")
      XCTAssertEqual(wire.periodCount, 2)
      XCTAssertEqual(wire.period.unit, "2")
      XCTAssertEqual(wire.discountID, "offer")
    }
  }

  func testPriceRequestProductIsBuiltFromAStoreKit1Product() {
    let product = FakeProduct(identifier: "com.bitlica.yearly",
                              price: 59.99,
                              locale: Locale(identifier: "en_US"),
                              groupId: "group.2",
                              period: FakePeriod(unit: .year, numberOfUnits: 1),
                              introductory: FakeDiscount(price: 0,
                                                         locale: Locale(identifier: "en_US"),
                                                         identifier: "trial",
                                                         period: FakePeriod(unit: .week, numberOfUnits: 1),
                                                         numberOfPeriods: 1,
                                                         paymentMode: .freeTrial,
                                                         type: .introductory),
                              discounts: [FakeDiscount(price: 29.99,
                                                       locale: Locale(identifier: "en_US"),
                                                       identifier: "promo",
                                                       period: FakePeriod(unit: .month, numberOfUnits: 6),
                                                       numberOfPeriods: 1,
                                                       paymentMode: .payUpFront,
                                                       type: .subscription)])

    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let wire = Priceapi_Product(product: SKProductInfo(skProduct: product),
                                transactionDate: date,
                                transactionId: "2000001236151777")

    XCTAssertEqual(wire.productID, "com.bitlica.yearly")
    XCTAssertEqual(wire.groupID, "group.2")
    XCTAssertEqual(wire.price, 59.99, accuracy: 0.0001)
    XCTAssertEqual(wire.period.unit, "3")
    XCTAssertEqual(wire.period.count, 1)
    XCTAssertEqual(wire.intro.type, 0)
    XCTAssertEqual(wire.intro.mode, 2)
    XCTAssertEqual(wire.intro.period.unit, "1")
    XCTAssertEqual(wire.discounts.count, 1)
    XCTAssertEqual(wire.discounts.first?.type, 1)
    XCTAssertEqual(wire.discounts.first?.mode, 1)
    XCTAssertEqual(wire.transaction, "2000001236151777")
    XCTAssertEqual(wire.tranDate.seconds, 1_700_000_000)
  }

  // MARK: Purchase events

  func testStoreKit1TransactionCarriesNoSignedTransaction() {
    // This is why `signed_transactions` stays empty on v1, and why protobuf leaves the field off
    // the wire entirely there. Nothing about the StoreKit 1 request changed.
    let transaction = FakeTransaction(productId: "coinspack.m4",
                                      transactionId: "1000000123",
                                      date: Date(timeIntervalSince1970: 1_700_000_000))

    let event = SKPurchaseEvent(skTransaction: transaction)

    XCTAssertEqual(event.productId, "coinspack.m4")
    XCTAssertEqual(event.transactionId, "1000000123")
    XCTAssertNil(event.jws)
  }

  // MARK: SKOfferPackage

  func testOfferPackageExposesTheSameProductPropertiesAsBefore() {
    let package = offerPackage(for: FakeProduct(identifier: "com.bitlica.weekly",
                                                price: 9.99,
                                                locale: Locale(identifier: "en_US"),
                                                groupId: "group.1",
                                                period: FakePeriod(unit: .week, numberOfUnits: 1),
                                                introductory: FakeDiscount(price: 0,
                                                                           locale: Locale(identifier: "en_US"),
                                                                           identifier: "trial",
                                                                           period: FakePeriod(unit: .day, numberOfUnits: 3),
                                                                           numberOfPeriods: 1,
                                                                           paymentMode: .freeTrial,
                                                                           type: .introductory)),
                               purchaseType: "weekly")

    XCTAssertEqual(package.productId, "com.bitlica.weekly")
    XCTAssertEqual(package.purchaseType, .weekly)
    XCTAssertTrue(package.isSubscription)
    XCTAssertTrue(package.isTrial)
    XCTAssertFalse(package.isIntroPriceOrPeriod)
    XCTAssertEqual(package.period, .week)
    XCTAssertEqual(package.subscriptionPeriodUnit, .week)
    XCTAssertEqual(package.numberOfUnits, 1)
    XCTAssertEqual(package.discountPeriod, .day)
    XCTAssertEqual(package.discountPeriodDuration, 3)
    XCTAssertEqual(package.trialPeriodDuration, 3)
    XCTAssertEqual(package.priceLocale.identifier, "en_US")
    XCTAssertEqual(package.currencyCode, "USD")
    XCTAssertEqual(package.price, Decimal(string: "9.99"))
    XCTAssertNotNil(package.storeProduct)
    XCTAssertEqual(package.introductoryOffer?.identifier, "trial")
    XCTAssertEqual(package.introductoryOffer?.periodUnit, .day)
    XCTAssertTrue(package.introductoryOffer?.isFreeTrial ?? false)
  }

  func testOfferPackagePaidIntroductoryOfferIsNotATrial() {
    let package = offerPackage(for: FakeProduct(identifier: "com.bitlica.monthly",
                                                price: 4.99,
                                                locale: Locale(identifier: "en_US"),
                                                period: FakePeriod(unit: .month, numberOfUnits: 1),
                                                introductory: FakeDiscount(price: 1.99,
                                                                           locale: Locale(identifier: "en_US"),
                                                                           identifier: "intro",
                                                                           period: FakePeriod(unit: .month, numberOfUnits: 1),
                                                                           numberOfPeriods: 3,
                                                                           paymentMode: .payAsYouGo,
                                                                           type: .introductory)),
                               purchaseType: "monthly")

    XCTAssertFalse(package.isTrial)
    XCTAssertTrue(package.isIntroPriceOrPeriod)
    XCTAssertNil(package.trialPeriodDuration)
    XCTAssertEqual(package.localizedIntroductoryPriceString, "$1.99")
  }

  func testOfferPackagePerPeriodPriceMathIsUnchanged() {
    // The paywall renders these strings, so the arithmetic is user-visible. Rounding is
    // `.down`, scale 2.
    let weekly = offerPackage(for: FakeProduct(identifier: "w",
                                               price: 9.99,
                                               locale: Locale(identifier: "en_US"),
                                               period: FakePeriod(unit: .week, numberOfUnits: 1)),
                              purchaseType: "weekly")

    XCTAssertEqual(weekly.localizedPriceString, "$9.99")
    XCTAssertEqual(weekly.weeklyLocalizedPriceString, "$9.99")
    // 9.99 / (1/4) = 39.96
    XCTAssertEqual(weekly.monthlyLocalizedPriceString, "$39.96")
    // 9.99 / 7 = 1.427...
    XCTAssertEqual(weekly.dailyLocalizedPriceString, "$1.42")

    let yearly = offerPackage(for: FakeProduct(identifier: "y",
                                               price: 59.99,
                                               locale: Locale(identifier: "en_US"),
                                               period: FakePeriod(unit: .year, numberOfUnits: 1)),
                              purchaseType: "yearly")

    // 59.99 / 12 = 4.999...
    XCTAssertEqual(yearly.monthlyLocalizedPriceString, "$4.99")
    // 59.99 / 52 = 1.153...
    XCTAssertEqual(yearly.weeklyLocalizedPriceString, "$1.15")
    XCTAssertEqual(yearly.localizedPriceWithMultiplier(2), "$119.98")
  }

  func testOfferPackageWithoutSubscriptionHasNoPerPeriodPrice() {
    let consumable = offerPackage(for: FakeProduct(identifier: "coinspack.m4",
                                                   price: 4.99,
                                                   locale: Locale(identifier: "en_US")),
                                  purchaseType: "consumable")

    XCTAssertEqual(consumable.purchaseType, .consumable)
    XCTAssertFalse(consumable.isSubscription)
    XCTAssertNil(consumable.period)
    XCTAssertNil(consumable.monthlyLocalizedPriceString)
    XCTAssertNil(consumable.weeklyLocalizedPriceString)
    XCTAssertEqual(consumable.localizedPriceString, "$4.99")
  }

  // MARK: Helpers

  private func offerPackage(for product: FakeProduct, purchaseType: String) -> SKOfferPackage {
    var package = Setupsapi_Package()
    package.id = "package.\(product.productIdentifier)"
    package.description_p = "description"
    package.productID = product.productIdentifier
    package.purchaseType = purchaseType
    return SKOfferPackage(package: package, productInfo: SKProductInfo(skProduct: product))
  }
}

// MARK: - StoreKit 1 fakes
//
// `SKProduct` and friends have no usable initializer, but their properties are `open`, so the
// values can be supplied by a subclass. This is the only way to exercise the StoreKit 1 mapping
// off-device.

private final class FakePeriod: SKProductSubscriptionPeriod {
  private let _unit: SKProduct.PeriodUnit
  private let _numberOfUnits: Int

  init(unit: SKProduct.PeriodUnit, numberOfUnits: Int) {
    _unit = unit
    _numberOfUnits = numberOfUnits
    super.init()
  }

  override var unit: SKProduct.PeriodUnit { _unit }
  override var numberOfUnits: Int { _numberOfUnits }
}

private final class FakeDiscount: SKProductDiscount {
  private let _price: NSDecimalNumber
  private let _priceLocale: Locale
  private let _identifier: String?
  private let _period: SKProductSubscriptionPeriod
  private let _numberOfPeriods: Int
  private let _paymentMode: SKProductDiscount.PaymentMode
  private let _type: SKProductDiscount.`Type`

  init(price: Double,
       locale: Locale,
       identifier: String?,
       period: SKProductSubscriptionPeriod,
       numberOfPeriods: Int,
       paymentMode: SKProductDiscount.PaymentMode,
       type: SKProductDiscount.`Type`) {
    _price = NSDecimalNumber(value: price)
    _priceLocale = locale
    _identifier = identifier
    _period = period
    _numberOfPeriods = numberOfPeriods
    _paymentMode = paymentMode
    _type = type
    super.init()
  }

  override var price: NSDecimalNumber { _price }
  override var priceLocale: Locale { _priceLocale }
  override var identifier: String? { _identifier }
  override var subscriptionPeriod: SKProductSubscriptionPeriod { _period }
  override var numberOfPeriods: Int { _numberOfPeriods }
  override var paymentMode: SKProductDiscount.PaymentMode { _paymentMode }
  override var type: SKProductDiscount.`Type` { _type }
}

private final class FakeProduct: SKProduct {
  private let _productIdentifier: String
  private let _price: NSDecimalNumber
  private let _priceLocale: Locale
  private let _groupId: String?
  private let _period: SKProductSubscriptionPeriod?
  private let _introductory: SKProductDiscount?
  private let _discounts: [SKProductDiscount]

  init(identifier: String,
       price: Double,
       locale: Locale,
       groupId: String? = nil,
       period: SKProductSubscriptionPeriod? = nil,
       introductory: SKProductDiscount? = nil,
       discounts: [SKProductDiscount] = []) {
    _productIdentifier = identifier
    _price = NSDecimalNumber(value: price)
    _priceLocale = locale
    _groupId = groupId
    _period = period
    _introductory = introductory
    _discounts = discounts
    super.init()
  }

  override var productIdentifier: String { _productIdentifier }
  override var price: NSDecimalNumber { _price }
  override var priceLocale: Locale { _priceLocale }
  override var subscriptionGroupIdentifier: String? { _groupId }
  override var subscriptionPeriod: SKProductSubscriptionPeriod? { _period }
  override var introductoryPrice: SKProductDiscount? { _introductory }
  override var discounts: [SKProductDiscount] { _discounts }
}

private final class FakeTransaction: SKPaymentTransaction {
  private let _payment: SKPayment
  private let _transactionIdentifier: String?
  private let _transactionDate: Date?

  init(productId: String, transactionId: String?, date: Date?) {
    let payment = SKMutablePayment()
    payment.productIdentifier = productId
    _payment = payment
    _transactionIdentifier = transactionId
    _transactionDate = date
    super.init()
  }

  override var payment: SKPayment { _payment }
  override var transactionIdentifier: String? { _transactionIdentifier }
  override var transactionDate: Date? { _transactionDate }
  override var transactionState: SKPaymentTransactionState { .purchased }
}
