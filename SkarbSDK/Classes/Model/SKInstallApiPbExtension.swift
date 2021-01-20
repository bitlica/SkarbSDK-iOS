//
//  SKInstallApiPbExtension.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 10/13/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation
import UIKit
import AdSupport
import SwiftProtobuf

extension Installapi_Auth: SKCodableStruct {
  
  init(from decoder: Swift.Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let key = try container.decode(String.self, forKey: .key)
    let bundleID = try container.decode(String.self, forKey: .bundleID)
    let agentName = try container.decode(String.self, forKey: .agentName)
    let agentVer = try container.decode(String.self, forKey: .agentVer)
    self = Installapi_Auth()
    self.key = key
    self.bundleID = bundleID
    self.agentName = agentName
    self.agentVer = agentVer
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

extension Installapi_DeviceRequest: SKCodableStruct {
  
  init(clientId: String, deviceId: String) {
    let authData = Installapi_Auth.with {
      $0.key = clientId
      $0.bundleID = Bundle.main.bundleIdentifier ?? "unknown"
      $0.agentName = SkarbSDK.agentName
      $0.agentVer = SkarbSDK.version
    }
    
    auth = authData
    installID = deviceId
    idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
    idfv = UIDevice.current.identifierForVendor?.uuidString ?? ""
    bundleVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    if let preferredLanguage = Locale.preferredLanguages.first {
      locale = preferredLanguage
    } else {
      locale = "unknown"
    }
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else { return identifier }
      return identifier + String(UnicodeScalar(UInt8(value)))
    }
    device = identifier
    osVer = UIDevice.current.systemVersion
    let appStoreReceiptURL = Bundle.main.appStoreReceiptURL
    if let appStoreReceiptURL = appStoreReceiptURL {
      receiptURL = appStoreReceiptURL.absoluteString
    } else {
      receiptURL = ""
      SKLogger.logError("Create install for V4. AppStoreReceiptURL is nil",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name])
    }
    var dataCount: Int = 0
    if let appStoreReceiptURL = appStoreReceiptURL,
      let recieptData = try? Data(contentsOf: appStoreReceiptURL) {
      dataCount = recieptData.count
    }
    receiptLen = "\(dataCount)"
    
    docDate = SwiftProtobuf.Google_Protobuf_Timestamp(timeIntervalSince1970: appInstallDate.timeIntervalSince1970)
    buildDate = SwiftProtobuf.Google_Protobuf_Timestamp(timeIntervalSince1970: appBuildDate.timeIntervalSince1970)
  }
  
  init(from decoder: Swift.Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let auth = try container.decode(Installapi_Auth.self, forKey: .auth)
    let installID = try container.decode(String.self, forKey: .installID)
    let idfa = try container.decode(String.self, forKey: .idfa)
    let idfv = try container.decode(String.self, forKey: .idfv)
    let bundleVer = try container.decode(String.self, forKey: .bundleVer)
    let locale = try container.decode(String.self, forKey: .locale)
    let device = try container.decode(String.self, forKey: .device)
    let osVer = try container.decode(String.self, forKey: .osVer)
    let receiptURL = try container.decode(String.self, forKey: .receiptURL)
    let receiptLen = try container.decode(String.self, forKey: .receiptLen)
    let docDateSec = try container.decode(Int64.self, forKey: .docDateSec)
    let docDateNanosec = try container.decode(Int32.self, forKey: .docDateNanosec)
    let buildDateSec = try container.decode(Int64.self, forKey: .buildDateSec)
    let buildDateNanosec = try container.decode(Int32.self, forKey: .buildDateNanosec)
    
    self = Installapi_DeviceRequest.with({
      $0.auth = auth
      $0.installID = installID
      $0.idfa = idfa
      $0.idfv = idfv
      $0.bundleVer = bundleVer
      $0.locale = locale
      $0.device = device
      $0.osVer = osVer
      $0.receiptURL = receiptURL
      $0.receiptLen = receiptLen
      $0.docDate = SwiftProtobuf.Google_Protobuf_Timestamp(seconds: docDateSec,
                                                           nanos: docDateNanosec)
      $0.buildDate = SwiftProtobuf.Google_Protobuf_Timestamp(seconds: buildDateSec,
                                                             nanos: buildDateNanosec)
    })
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(auth, forKey: .auth)
    try container.encode(installID, forKey: .installID)
    try container.encode(idfa, forKey: .idfa)
    try container.encode(idfv, forKey: .idfv)
    try container.encode(bundleVer, forKey: .bundleVer)
    try container.encode(locale, forKey: .locale)
    try container.encode(device, forKey: .device)
    try container.encode(osVer, forKey: .osVer)
    try container.encode(receiptURL, forKey: .receiptURL)
    try container.encode(receiptLen, forKey: .receiptLen)
    try container.encode(docDate.seconds, forKey: .docDateSec)
    try container.encode(docDate.nanos, forKey: .docDateNanosec)
    try container.encode(buildDate.seconds, forKey: .buildDateSec)
    try container.encode(buildDate.nanos, forKey: .buildDateNanosec)
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
    case idfa
    case idfv
    case bundleVer
    case locale
    case device
    case osVer
    case receiptURL
    case receiptLen
    case docDateSec
    case docDateNanosec
    case buildDateSec
    case buildDateNanosec
  }
  
  private var appBuildDate: Date {
    if let path = Bundle.main.path(forResource: "Info", ofType: "plist") {
      if let createdDate = try? FileManager.default.attributesOfItem(atPath: path)[.creationDate] as? Date {
        return createdDate
      }
    }
    SKLogger.logError("AppBuildDate is nil.",
                      features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                 SKLoggerFeatureType.internalValue.name: "AppBuildDate is nil."])
    return Date() // Should never execute
  }

  private var appInstallDate: Date {
    if let documentsFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
      if let installDate = try? FileManager.default.attributesOfItem(atPath: documentsFolder.path)[.creationDate] as? Date {
        return installDate
      }
    }
    SKLogger.logError("AppInstallDate is nil.",
                      features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                 SKLoggerFeatureType.internalValue.name: "AppInstallDate is nil."])
    return Date() // Should never execute
  }
}


extension Installapi_AttribRequest: SKCodableStruct {
  
  init(broker: String, features: [AnyHashable: Any]) {
    
    let authData = Installapi_Auth.with {
      $0.key = SkarbSDK.clientId
      $0.bundleID = Bundle.main.bundleIdentifier ?? "unknown"
      $0.agentName = SkarbSDK.agentName
      $0.agentVer = SkarbSDK.version
    }
    self.auth = authData
    self.installID = SkarbSDK.getDeviceId()
    self.broker = broker
    
    guard JSONSerialization.isValidJSONObject(features) else {
      SKLogger.logError("Api_AttribRequest init: json isValidJSONObject",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.internalValue.name: features.description])
      return
    }
    do {
      payload = try JSONSerialization.data(withJSONObject: features, options: .fragmentsAllowed)
    } catch {
      payload = Data()
      SKLogger.logError("Api_AttribRequest: can't json serialization to Data",
                        features: [SKLoggerFeatureType.internalError.name: SKLoggerFeatureType.internalError.name,
                                   SKLoggerFeatureType.internalValue.name: features.description])
    }
  }
  
  init(from decoder: Swift.Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let auth = try container.decode(Installapi_Auth.self, forKey: .auth)
    let installID = try container.decode(String.self, forKey: .installID)
    let broker = try container.decode(String.self, forKey: .broker)
    let payload = try container.decode(Data.self, forKey: .payload)
    
    self = Installapi_AttribRequest.with({
      $0.auth = auth
      $0.installID = installID
      $0.broker = broker
      $0.payload = payload
    })
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(auth, forKey: .auth)
    try container.encode(installID, forKey: .installID)
    try container.encode(broker, forKey: .broker)
    try container.encode(payload, forKey: .payload)
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
    case broker
    case payload
  }
}

extension Installapi_TestRequest: SKCodableStruct {
  
  init(name: String, group: String) {
    
    let authData = Installapi_Auth.with {
      $0.key = SkarbSDK.clientId
      $0.bundleID = Bundle.main.bundleIdentifier ?? "unknown"
      $0.agentName = SkarbSDK.agentName
      $0.agentVer = SkarbSDK.version
    }
    self.auth = authData
    self.installID = SkarbSDK.getDeviceId()
    self.name = name
    self.group = group
    
    
  }
  
  init(from decoder: Swift.Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let auth = try container.decode(Installapi_Auth.self, forKey: .auth)
    let installID = try container.decode(String.self, forKey: .installID)
    let name = try container.decode(String.self, forKey: .name)
    let group = try container.decode(String.self, forKey: .group)
    
    self = Installapi_TestRequest.with({
      $0.auth = auth
      $0.installID = installID
      $0.name = name
      $0.group = group
    })
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(auth, forKey: .auth)
    try container.encode(installID, forKey: .installID)
    try container.encode(name, forKey: .name)
    try container.encode(group, forKey: .group)
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
    case name
    case group
  }
}

