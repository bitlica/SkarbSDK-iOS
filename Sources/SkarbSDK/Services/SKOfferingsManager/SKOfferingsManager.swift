//
//  SKOfferingsManager.swift
//  SkarbSDK
//
//  Created by Artem Hitrik on 24.11.22.
//

import Foundation

protocol SKOfferingsManager {
  func getOfferings(with refreshPolicy: SKRefreshPolicy,
                    completion: @escaping (Result<SKOfferings, Error>) -> Void)
}

class SKOfferingsManagerImplementation: SKOfferingsManager {
  
  private let exclusionSerialQueue = DispatchQueue(label: "com.skarbSDK.skOfferingsManager.exclusion")
  private var cachedOfferings: SKOfferings? = nil
  private var offerings: SKOfferings? {
    var offerings: SKOfferings? = nil
    exclusionSerialQueue.sync {
      offerings = cachedOfferings
    }
    
    return offerings
  }
  func getOfferings(with refreshPolicy: SKRefreshPolicy,
                    completion: @escaping (Result<SKOfferings, Error>) -> Void) {
    if refreshPolicy == .memoryCached,
       let offerings = offerings {
      DispatchQueue.main.async {
        completion(.success(offerings))
      }
      return
    }
    
    SKServiceRegistry.serverAPI.getOfferings(completion: { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .success(let updatedOfferings):
        self.parseUpdatedOfferings(updatedOfferings,
                                   retryCount: 0,
                                   completion: completion)
      case .failure(let error):
        DispatchQueue.main.async {
          completion(.failure(error))
        }
      }
    })
  }
}

//MARK: Private

private extension SKOfferingsManagerImplementation {
  
  func parseUpdatedOfferings(_ updatedOfferings: Setupsapi_OfferingsResponse,
                             retryCount: Int,
                             completion: @escaping (Result<SKOfferings, Error>) -> Void) {
    let offeringsData = updatedOfferings.data.compactMap { self.createOffering(with: $0) }
    
    guard retryCount < 3 else {
      DispatchQueue.main.async {
        let error = SKResponseError(errorCode: 34, message: "Can't get offerings after 3 attempts. Don't have [SKProduct] for offerings")
        completion(.failure(error))
      }
      return
    }
    
    // If count is not equal -> there are no SKProduct for any `productId`
    // and need to fetch them
    guard offeringsData.count == updatedOfferings.data.count else {
      DispatchQueue.main.async {
        SKServiceRegistry.storeKitService.requestProductsInfo(productIds: updatedOfferings.allProductIds) { [weak self] result in
          switch result {
          case .success:
            self?.parseUpdatedOfferings(updatedOfferings,
                                        retryCount: retryCount + 1,
                                        completion: completion)
          case .failure(let error):
            SKLogger.logInfo("parseUpdatedOfferings(:) fetching error during requestProductsInfo(:). Try to fetch one more time. Error = \(error.localizedDescription)")
            DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
              self?.parseUpdatedOfferings(updatedOfferings,
                                          retryCount: retryCount + 1,
                                          completion: completion)
            })
          }
        }
      }
      return
    }
    let offerings = SKOfferings(offerings: offeringsData)
    exclusionSerialQueue.sync {
      cachedOfferings = offerings
    }
    DispatchQueue.main.async {
      completion(.success(offerings))
    }
  }
  
  func createOffering(with offering: Setupsapi_Offering) -> SKOffering? {
    let packages = offering.packages.compactMap { createPackage(with: $0) }
    guard packages.count == offering.packages.count else {
      return nil
    }
    
    return SKOffering(id: offering.id,
                      description: offering.description_p,
                      packages: packages)
  }
  
  func createPackage(with package: Setupsapi_Package) -> SKOfferPackage? {
    guard let storeProduct = SKServiceRegistry.storeKitService.fetchProduct(by: package.productID) else {
      return nil
    }
    
    return SKOfferPackage(package: package, storeProduct: storeProduct)
  }
}
