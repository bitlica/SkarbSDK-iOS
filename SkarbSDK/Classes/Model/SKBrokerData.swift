//
//  SKBrokerData.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 4/7/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import Foundation

struct SKBrokerData: SKCodableStruct {
  let broker: String
  let featuresData: Data
  
  init(broker: String, features: [AnyHashable: Any]) {
    self.broker = broker
    do {
      featuresData = try JSONSerialization.data(withJSONObject: features, options: .fragmentsAllowed)
    } catch {
      featuresData = Data()
      SKLogger.logError("SKBrokerData: can't json serialization to Data",
                        features: [SKLoggerFeatureType.internalError: SKLoggerFeatureType.internalError])
    }
  }
  
  func getJSON() -> [String: Any] {
    let brokerJSON: Any
    do {
      brokerJSON = try JSONSerialization.jsonObject(with: featuresData, options: .fragmentsAllowed)
    } catch {
      brokerJSON = [:]
      SKLogger.logError("SKBrokerData: can't json serialization to Data for source",
                        features: [SKLoggerFeatureType.internalError: SKLoggerFeatureType.internalError])
    }
    
    return ["broker": broker,
            "features": brokerJSON]
  }
  
  func getData() -> Data? {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(self) {
      return encoded
    }
    
    return nil
  }
}
