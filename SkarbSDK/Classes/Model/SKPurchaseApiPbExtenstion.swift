//
//  SKPurchaseApiPbExtenstion.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 11/24/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import UIKit
import AdSupport

extension Purchaseapi_Auth: SKCodableStruct {
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let key = try container.decode(String.self, forKey: .key)
    let bundleID = try container.decode(String.self, forKey: .bundleID)
    let agentName = try container.decode(String.self, forKey: .agentName)
    let agentVer = try container.decode(String.self, forKey: .agentVer)
    self = Purchaseapi_Auth.with({
      $0.key = key
      $0.bundleID = bundleID
      $0.agentName = agentName
      $0.agentVer = agentVer
    })
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(key, forKey: .key)
    try container.encode(bundleID, forKey: .bundleID)
    try container.encode(agentName, forKey: .agentName)
    try container.encode(agentVer, forKey: .agentVer)
  }
  
  func getData() -> Data? {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      return encoded
    }
    
    return nil
  }
  
  enum CodingKeys: String, CodingKey {
    case key
    case bundleID
    case agentName
    case agentVer
  }
}

extension Purchaseapi_TransactionsRequest: SKCodableStruct {
  
  init(deviceId: String, newTransactions: [String]) {
    let authData = Purchaseapi_Auth.with {
      $0.key = SkarbSDK.clientId
      $0.bundleID = Bundle.main.bundleIdentifier ?? "unknown"
      $0.agentName = SkarbSDK.agentName
      $0.agentVer = SkarbSDK.version
    }
    auth = authData
    installID = deviceId
    transactions = newTransactions
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let auth = try container.decode(Purchaseapi_Auth.self, forKey: .auth)
    let installID = try container.decode(String.self, forKey: .installID)
    let transactions = try container.decode(Array<String>.self, forKey: .transactions)
    
    self = Purchaseapi_TransactionsRequest.with({
      $0.auth = auth
      $0.installID = installID
      $0.transactions = transactions
    })
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(auth, forKey: .auth)
    try container.encode(installID, forKey: .installID)
    try container.encode(transactions, forKey: .transactions)
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
    case transactions
  }
}

extension Purchaseapi_ReceiptRequest: SKCodableStruct {
  
  init(deviceId: String, newTransactions: [String]) {
    let authData = Purchaseapi_Auth.with {
      $0.key = SkarbSDK.clientId
      $0.bundleID = Bundle.main.bundleIdentifier ?? "unknown"
      $0.agentName = SkarbSDK.agentName
      $0.agentVer = SkarbSDK.version
    }
    auth = authData
    installID = deviceId
    transactions = newTransactions
    idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
    idfv = UIDevice.current.identifierForVendor?.uuidString ?? ""
    let appStoreReceiptURL = Bundle.main.appStoreReceiptURL
    if let appStoreReceiptURL = appStoreReceiptURL {
      receiptURL = appStoreReceiptURL.absoluteString
    } else {
      receiptURL = ""
      SKLogger.logError("Create purchase for V4. AppStoreReceiptURL is nil",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
    }
    var dataCount: Int = 0
    if let appStoreReceiptURL = appStoreReceiptURL,
      let recieptData = try? Data(contentsOf: appStoreReceiptURL) {
      dataCount = recieptData.count
    }
    receiptLen = "\(dataCount)"
    if let appStoreReceiptURL = appStoreReceiptURL,
       let recieptData = try? Data(contentsOf: appStoreReceiptURL) {
      receipt = recieptData
    } else {
      receipt = Data()
      SKLogger.logError("Create purchase for V4. recieptData is nil",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
    }
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let auth = try container.decode(Purchaseapi_Auth.self, forKey: .auth)
    let installID = try container.decode(String.self, forKey: .installID)
    let transactions = try container.decode(Array<String>.self, forKey: .transactions)
    let idfa = try container.decode(String.self, forKey: .idfa)
    let idfv = try container.decode(String.self, forKey: .idfv)
    let receiptURL = try container.decode(String.self, forKey: .receiptURL)
    let receiptLen = try container.decode(String.self, forKey: .receiptLen)
    let receipt = try container.decode(Data.self, forKey: .receipt)
    
    self = Purchaseapi_ReceiptRequest.with({
      $0.auth = auth
      $0.installID = installID
      $0.transactions = transactions
      $0.idfa = idfa
      $0.idfv = idfv
      $0.receiptURL = receiptURL
      $0.receiptLen = receiptLen
      $0.receipt = receipt
    })
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(auth, forKey: .auth)
    try container.encode(installID, forKey: .installID)
    try container.encode(transactions, forKey: .transactions)
    try container.encode(idfa, forKey: .idfa)
    try container.encode(idfv, forKey: .idfv)
    try container.encode(receiptURL, forKey: .receiptURL)
    try container.encode(receiptLen, forKey: .receiptLen)
    try container.encode(receipt, forKey: .receipt)
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
    case transactions
    case idfa
    case idfv
    case receiptURL
    case receiptLen
    case receipt
  }
}
