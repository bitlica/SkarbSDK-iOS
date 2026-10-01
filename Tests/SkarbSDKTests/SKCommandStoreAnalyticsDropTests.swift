//
//  SKCommandStoreAnalyticsDropTests.swift
//  SkarbSDKTests
//

import XCTest
@testable import SkarbSDK

/// The command store side of `SkarbSDK.setAnalyticsEnabled(false)`. Each test gets its own store
/// on a throwaway UserDefaults suite with a no-op sync trigger, so nothing reaches the network.
final class SKCommandStoreAnalyticsDropTests: XCTestCase {

  private let analyticsTypes: [SKCommandType] = [.sourceV4,
                                                 .testV4,
                                                 .idfaV4,
                                                 .fetchIdfa,
                                                 .automaticSearchAds,
                                                 .logging]
  private let keptTypes: [SKCommandType] = [.installV4,
                                            .fetchProducts,
                                            .purchaseV4,
                                            .transactionV4,
                                            .priceV4,
                                            .setReceipt]
  private let statuses: [SKCommandStatus] = [.pending, .inProgress, .done, .canceled]

  private var suiteName: String!
  private var userDefaults: UserDefaults!
  private var store: SKCommandStore!

  override func setUp() {
    super.setUp()
    suiteName = "SKCommandStoreAnalyticsDropTests.\(UUID().uuidString)"
    userDefaults = UserDefaults(suiteName: suiteName)
    store = makeStore()
  }

  override func tearDown() {
    userDefaults.removePersistentDomain(forName: suiteName)
    store = nil
    userDefaults = nil
    super.tearDown()
  }

  func testDropRemovesEveryAnalyticsCommandInAnyStatus() {
    seed(analyticsTypes)

    store.dropAnalyticsCommands()

    for commandType in analyticsTypes {
      XCTAssertTrue(store.getAllCommands(by: commandType).isEmpty, "\(commandType) survived the drop")
    }
    XCTAssertFalse(store.hasTestV4Command)
    XCTAssertFalse(store.hasIDFACommand)
    XCTAssertFalse(store.hasAutomaticSearchAdsCommand)
    XCTAssertTrue(makeStore().getAllCommands(by: .sourceV4).isEmpty)
  }

  func testDropKeepsInstallAndPurchaseCommands() {
    let kept = seed(keptTypes)
    seed(analyticsTypes)

    store.dropAnalyticsCommands()

    let reloaded = makeStore()
    for command in kept {
      let stored = reloaded.getAllCommands(by: command.commandType).first(where: { $0 == command })
      XCTAssertNotNil(stored, "\(command.description) was dropped")
      XCTAssertEqual(stored?.status, command.status)
    }
  }

  /// A source request in flight during the revocation finishes afterwards. Were it re-inserted,
  /// `hasSendSourceV4Command` would keep the attribution from being sent once consent is back.
  func testDroppedInFlightCommandIsNotReinsertedOnCompletion() {
    let attribution = Installapi_AttribRequest(broker: SKBroker.appsflyer.name,
                                               features: ["af_status": "Organic"],
                                               brokerUserID: nil)
    var source = SKCommand(commandType: .sourceV4, status: .pending, data: attribution.getData())
    store.saveCommand(source)
    source.changeStatus(to: .inProgress)
    store.saveCommand(source)

    store.dropAnalyticsCommands()

    source.changeStatus(to: .done)
    store.saveCommand(source)
    XCTAssertFalse(store.hasSendSourceV4Command(broker: .appsflyer))
  }

  func testIDFACommandsAreRecreatedAfterDrop() {
    store.createIDFACommandIfNeeded(automaticCollectIDFA: true)
    store.saveCommand(SKCommand(commandType: .idfaV4, status: .done, data: Data("idfa".utf8)))

    store.dropAnalyticsCommands()
    store.createIDFACommandIfNeeded(automaticCollectIDFA: true)

    // As on a first launch: the delayed 5 / 15 / 60 second fetches again
    XCTAssertEqual(store.getAllCommands(by: .fetchIdfa).count, 3)
    XCTAssertTrue(store.getAllCommands(by: .idfaV4).isEmpty)
  }

  // MARK: Helpers

  private func makeStore() -> SKCommandStore {
    return SKCommandStore(userDefaultsService: SKUserDefaultsService(userDefaults: userDefaults),
                          syncAllCommands: {})
  }

  /// One command per type and status, saved the way the SDK saves them.
  @discardableResult
  private func seed(_ commandTypes: [SKCommandType]) -> [SKCommand] {
    var seeded: [SKCommand] = []
    for commandType in commandTypes {
      for (index, status) in statuses.enumerated() {
        let data = Data("\(commandType)-\(index)".utf8)
        var command = SKCommand(commandType: commandType, status: .pending, data: data)
        store.saveCommand(command)
        if status != .pending {
          command.changeStatus(to: status)
          store.saveCommand(command)
        }
        seeded.append(command)
      }
    }
    return seeded
  }
}
