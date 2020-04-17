//
//  ViewController.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/21/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import UIKit
//import SkarbSDK

class ViewController: UIViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    
    view.backgroundColor = .red

//    SkarbSDK.initialize(clientId: "YOUR_CLIENT_ID", isObservable: true, isDebug: true)
//    let features: [String: Any] = ["source": "artemMigration", "campaign": "artemMigration"]
//    SkarbSDK.sendSource(broker: .appsflyer, features: features, completion: { _ in
//
//    })

    SkarbSDK.initialize(clientId: "YOUR_CLIENT_ID", isObservable: true)
//    SkarbSDK.sendPurchase(productId: "testProductId", price: 9.99, currency: "USD")
    let logCommand = SKCommand(timestamp: Date().nowTimestampInt,
                               commandType: .logging,
                               status: .pending,
                               data: SKCommand.prepareApplogData(message: "Test message"),
                               retryCount: 0)
    SKServiceRegistry.commandStore.saveCommand(logCommand)
    
//    let features: [String: Any] = ["source": "artemMigration", "campaign": "artemMigration"]
//    SkarbSDK.sendSource(broker: .appsflyer, features: features)
  } 
}

