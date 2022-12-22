//
//  ViewController.swift
//  SkarbSDKExample
//
//  Created by Bitlica Inc. on 1/21/20.
//  Copyright © 2020 Bitlica Inc. All rights reserved.
//

import UIKit
import SkarbSDK
import AppTrackingTransparency
import SwiftProtobuf
import AdSupport

class ViewController: UIViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    
    view.backgroundColor = .red

    SkarbSDK.initialize(clientId: "YOUR_CLIENT_ID",
                        isObservable: true)
  }
}

