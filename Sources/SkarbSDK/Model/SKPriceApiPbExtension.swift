//
//  SKPriceApiPbExtension.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 12/2/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import StoreKit
import SwiftProtobuf

extension Priceapi_PricesRequest: SKCodableStruct {
  
  init(storefront: String?,
       region: String?,
       currency: String?,
       products: [Priceapi_Product]) {
    self.auth = Auth_Auth.createDefault()
    self.installID = SkarbSDK.getDeviceId()
    self.storefront = storefront ?? ""
    self.region = region ?? ""
    self.currency = currency ?? ""
    self.products = products
  }
  
  init(from decoder: Swift.Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let auth = try container.decode(Auth_Auth.self, forKey: .auth)
    let installID = try container.decode(String.self, forKey: .installID)
    let storefront = try container.decode(String.self, forKey: .storefront)
    let region = try container.decode(String.self, forKey: .region)
    let currency = try container.decode(String.self, forKey: .currency)
    let products = try container.decode(Array<Priceapi_Product>.self, forKey: .products)
    
    self = Priceapi_PricesRequest.with({
      $0.auth = auth
      $0.installID = installID
      $0.storefront = storefront
      $0.region = region
      $0.currency = currency
      $0.products = products
    })
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(auth, forKey: .auth)
    try container.encode(installID, forKey: .installID)
    try container.encode(storefront, forKey: .storefront)
    try container.encode(region, forKey: .region)
    try container.encode(currency, forKey: .currency)
    try container.encode(products, forKey: .products)
  }
  
  func getData() -> Data? {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      return encoded
    }
    
    return nil
  }
  
  enum CodingKeys: String, CodingKey {
    case auth
    case installID
    case storefront
    case region
    case currency
    case products
  }
}

extension Priceapi_Product: SKCodableStruct {
  
  init(product: SKProductInfo, transactionDate: Date?, transactionId: String?) {
    productID = product.productId
    groupID = product.groupId

    // `period` and `intro` are left unset when absent, so `hasPeriod` / `hasIntro`
    // stay false on the wire exactly as before.
    if let subscriptionPeriod = product.subscriptionPeriod {
      period = Priceapi_Period(period: subscriptionPeriod)
    }
    price = NSDecimalNumber(decimal: product.price).doubleValue
    if let introductoryOffer = product.introductoryOffer {
      intro = Priceapi_Discount(discount: introductoryOffer)
    }
    discounts = product.promotionalOffers.map({ Priceapi_Discount(discount: $0) })
    if let transactionDate = transactionDate {
      tranDate = SwiftProtobuf.Google_Protobuf_Timestamp(date: transactionDate)
    } else {
      tranDate = SwiftProtobuf.Google_Protobuf_Timestamp()
    }
    transaction = transactionId ?? ""
  }
  
  init(from decoder: Swift.Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let productID = try container.decode(String.self, forKey: .productID)
    let groupID = try container.decode(String.self, forKey: .groupID)
    let period = try container.decode(Priceapi_Period.self, forKey: .period)
    let price = try container.decode(Double.self, forKey: .price)
    let intro = try container.decode(Priceapi_Discount.self, forKey: .intro)
    let discounts = try container.decode(Array<Priceapi_Discount>.self, forKey: .discounts)
    let tranDateSec = try container.decode(Int64.self, forKey: .buildDateSec)
    let tranDateNanosec = try container.decode(Int32.self, forKey: .tranDateNanosec)
    let transaction = try container.decode(String.self, forKey: .transaction)
    
    self = Priceapi_Product.with({
      $0.productID = productID
      $0.groupID = groupID
      $0.period = period
      $0.price = price
      $0.intro = intro
      $0.discounts = discounts
      $0.tranDate = SwiftProtobuf.Google_Protobuf_Timestamp(seconds: tranDateSec,
                                                            nanos: tranDateNanosec)
      $0.transaction = transaction
    })
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(productID, forKey: .productID)
    try container.encode(groupID, forKey: .groupID)
    try container.encode(period, forKey: .period)
    try container.encode(price, forKey: .price)
    try container.encode(intro, forKey: .intro)
    try container.encode(discounts, forKey: .discounts)
    try container.encode(tranDate.seconds, forKey: .buildDateSec)
    try container.encode(tranDate.nanos, forKey: .tranDateNanosec)
    try container.encode(transaction, forKey: .transaction)
  }
  
  func getData() -> Data? {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      return encoded
    }
    
    return nil
  }
  
  enum CodingKeys: String, CodingKey {
    case productID
    case groupID
    case period
    case price
    case intro
    case discounts
    case buildDateSec
    case tranDateNanosec
    case transaction
  }
}

extension Priceapi_Period: SKCodableStruct {
  
  /// `unit` is the StringIFIED StoreKit 1 enum ordinal ("0" day ... "3" year),
  /// not the period name. The backend parses it as a number - do not send "day"/"week".
  init(period: SKPeriodInfo) {
    unit = "\(period.unit.rawValue)"
    count = Int32(period.count)
  }
  
  init(from decoder: Swift.Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let unit = try container.decode(String.self, forKey: .unit)
    let count = try container.decode(Int32.self, forKey: .count)
    
    self = Priceapi_Period.with({
      $0.unit = unit
      $0.count = count
    })
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(unit, forKey: .unit)
    try container.encode(count, forKey: .count)
  }
  
  func getData() -> Data? {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      return encoded
    }
    
    return nil
  }
  
  enum CodingKeys: String, CodingKey {
    case unit
    case count
  }
}

extension Priceapi_Discount: SKCodableStruct {
  
  init(discount: SKDiscountInfo) {
    price = NSDecimalNumber(decimal: discount.price).doubleValue
    discountID = discount.identifier ?? ""
    // Numeric codes come from the enums' `wireCode`, never from a StoreKit rawValue:
    // StoreKit 2 raw values are Strings, so `Int32(rawValue)` would always be nil.
    type = discount.kind.wireCode
    mode = discount.paymentMode.wireCode
    period = Priceapi_Period(period: discount.period)
    periodCount = Int32(discount.numberOfPeriods)
  }
  
  init(from decoder: Swift.Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let price = try container.decode(Double.self, forKey: .price)
    let discountID = try container.decode(String.self, forKey: .discountID)
    let type = try container.decode(Int32.self, forKey: .type)
    let mode = try container.decode(Int32.self, forKey: .mode)
    let period = try container.decode(Priceapi_Period.self, forKey: .period)
    let periodCount = try container.decode(Int32.self, forKey: .periodCount)
    
    self = Priceapi_Discount.with({
      $0.price = price
      $0.discountID = discountID
      $0.type = type
      $0.mode = mode
      $0.period = period
      $0.periodCount = periodCount
    })
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(price, forKey: .price)
    try container.encode(discountID, forKey: .discountID)
    try container.encode(type, forKey: .type)
    try container.encode(mode, forKey: .mode)
    try container.encode(period, forKey: .period)
    try container.encode(periodCount, forKey: .periodCount)
  }
  
  func getData() -> Data? {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      return encoded
    }
    
    return nil
  }
  
  enum CodingKeys: String, CodingKey {
    case price
    case discountID
    case type
    case mode
    case period
    case periodCount
  }
}
