//
//  ViewController.swift
//  SkarbSDKExample
//
//  Created by Artem Hitrik on 1/21/20.
//  Copyright © 2020 Prodinfire. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    
    view.backgroundColor = .red
    
    SKServiceRegistry.initialize()
    
//    SKServiceRegistry.serverAPI.sendInstall { error in
//      print("error = \(error)")
//    }
//    SKServiceRegistry.serverAPI.sendSource(source: .facebook, features: ["source": "facebookTest"], completion: { error in
//      print("error = \(error)")
//    })
//    SKServiceRegistry.serverAPI.sendTest(name: "testFacebook", group: "A")
//    SKServiceRegistry.serverAPI.sendPurchase(paywall: "facebook", price: 120.99, currency: "BYN")
  }


}

