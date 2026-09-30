//
//  SKCommandStoreDeviceResetTests.swift
//  SkarbSDKTests
//

import XCTest
@testable import SkarbSDK

/// The command store side of `SkarbSDK.resetDeviceId`. Each test gets its own store on a
/// throwaway UserDefaults suite with a no-op sync trigger, so nothing reaches the network.
final class SKCommandStoreDeviceResetTests: XCTestCase {

  private let purchaseTypes: [SKCommandType] = [.fetchProducts,
                                                .purchaseV4,
                                                .transactionV4,
                                                .priceV4,
                                                .setReceipt]
  private let deviceScopedTypes: [SKCommandType] = [.installV4,
                                                    .sourceV4,
                                                    .testV4,
                                                    .idfaV4,
                                                    .fetchIdfa,
                                                    .automaticSearchAds,
                                                    .logging]
  private let statuses: [SKCommandStatus] = [.pending, .inProgress, .done, .canceled]

  private var suiteName: String!
  private var userDefaults: UserDefaults!
  private var store: SKCommandStore!
  private var syncCount = 0
  private var previousDeviceId: String?

  override func setUp() {
    super.setUp()
    suiteName = "SKCommandStoreDeviceResetTests.\(UUID().uuidString)"
    userDefaults = UserDefaults(suiteName: suiteName)
    store = makeStore()
    syncCount = 0
    // Install payloads read the id through `SkarbSDK.getDeviceId()`
    previousDeviceId = SKServiceRegistry.userDefaultsService.string(forKey: .deviceId)
  }

  override func tearDown() {
    SKServiceRegistry.userDefaultsService.setValue(previousDeviceId, forKey: .deviceId)
    userDefaults.removePersistentDomain(forName: suiteName)
    store = nil
    userDefaults = nil
    super.tearDown()
  }

  func testDropKeepsEveryPurchaseCommandInAnyStatus() {
    let purchaseCommands = seed(purchaseTypes)
    seed(deviceScopedTypes)

    store.dropDeviceScopedCommands()

    let kept = allCommands()
    XCTAssertEqual(kept.count, purchaseCommands.count)
    for command in purchaseCommands {
      let stored = kept.first(where: { $0 == command })
      XCTAssertNotNil(stored, "\(command.description) was dropped")
      XCTAssertEqual(stored?.status, command.status)
    }
  }

  func testDropRemovesEveryDeviceScopedCommandInAnyStatus() {
    seed(purchaseTypes)
    seed(deviceScopedTypes)
    SKServiceRegistry.userDefaultsService.setValue("old-device-id", forKey: .deviceId)
    let attribution = Installapi_AttribRequest(broker: SKBroker.appsflyer.name,
                                               features: ["af_status": "Organic"],
                                               brokerUserID: nil)
    store.saveCommand(SKCommand(commandType: .sourceV4, status: .done, data: attribution.getData()))
    XCTAssertTrue(store.hasSendSourceV4Command(broker: .appsflyer))

    store.dropDeviceScopedCommands()

    for commandType in deviceScopedTypes {
      XCTAssertTrue(store.getAllCommands(by: commandType).isEmpty, "\(commandType) survived the drop")
    }
    XCTAssertFalse(store.hasInstallV4Command)
    XCTAssertFalse(store.hasTestV4Command)
    XCTAssertFalse(store.hasIDFACommand)
    XCTAssertFalse(store.hasAutomaticSearchAdsCommand)
    XCTAssertFalse(store.hasSendSourceV4Command(broker: .appsflyer))
  }

  func testDropIsPersisted() {
    let purchaseCommands = seed(purchaseTypes)
    seed(deviceScopedTypes)

    store.dropDeviceScopedCommands()

    let reloaded = makeStore()
    for commandType in deviceScopedTypes {
      XCTAssertTrue(reloaded.getAllCommands(by: commandType).isEmpty, "\(commandType) was reloaded")
    }
    for command in purchaseCommands {
      XCTAssertTrue(reloaded.getAllCommands(by: command.commandType).contains(command))
    }
  }

  /// An old install whose request was in flight during the reset finishes afterwards. Were it
  /// re-inserted, `hasInstallV4Command` would block the install for the new id.
  func testDroppedInFlightCommandIsNotReinsertedOnCompletion() {
    var install = SKCommand(commandType: .installV4, status: .pending, data: Data("old".utf8))
    store.saveCommand(install)
    install.changeStatus(to: .inProgress)
    store.saveCommand(install)

    store.dropDeviceScopedCommands()

    var succeeded = install
    succeeded.changeStatus(to: .done)
    store.saveCommand(succeeded)
    XCTAssertFalse(store.hasInstallV4Command)

    // The failure path saves it back as pending
    var failed = install
    failed.updateRetryCountAndFireDate()
    failed.changeStatus(to: .pending)
    store.saveCommand(failed)
    XCTAssertFalse(store.hasInstallV4Command)
    XCTAssertTrue(makeStore().getAllCommands(by: .installV4).isEmpty)
  }

  func testPurchaseCommandInFlightIsUpdatedAsBefore() {
    var purchase = SKCommand(commandType: .purchaseV4, status: .pending, data: Data("receipt".utf8))
    store.saveCommand(purchase)
    purchase.changeStatus(to: .inProgress)
    store.saveCommand(purchase)

    store.dropDeviceScopedCommands()

    purchase.changeStatus(to: .done)
    store.saveCommand(purchase)
    XCTAssertEqual(store.getAllCommands(by: .purchaseV4).map { $0.status }, [.done])
  }

  func testNewCommandsAreSavedAfterDrop() {
    seed(deviceScopedTypes)
    store.dropDeviceScopedCommands()
    let syncCountBefore = syncCount

    let test = SKCommand(commandType: .testV4, status: .pending, data: Data("new".utf8))
    store.saveCommand(test)
    let transaction = SKCommand(commandType: .transactionV4, status: .pending, data: Data("tx".utf8))
    store.saveCommand(transaction)

    XCTAssertTrue(store.hasTestV4Command)
    XCTAssertEqual(store.getAllCommands(by: .transactionV4), [transaction])
    XCTAssertEqual(syncCount, syncCountBefore + 2)
  }

  func testRecreatedInstallCarriesTheNewDeviceId() throws {
    // A nil receipt URL makes the install payload log an error through the shared store
    try XCTSkipIf(Bundle.main.appStoreReceiptURL == nil, "No receipt URL in this test host")

    SKServiceRegistry.userDefaultsService.setValue("old-device-id", forKey: .deviceId)
    store.createInstallCommandIfNeeded(clientId: "client")
    XCTAssertEqual(store.getDeviceRequest()?.installID, "old-device-id")

    // The order `SkarbSDK.resetDeviceId` uses: new id, drop, recreate
    SKServiceRegistry.userDefaultsService.setValue("new-device-id", forKey: .deviceId)
    store.dropDeviceScopedCommands()
    store.createInstallCommandIfNeeded(clientId: "client")

    let installs = store.getAllCommands(by: .installV4)
    XCTAssertEqual(installs.count, 1)
    XCTAssertEqual(installs.first?.status, .pending)
    XCTAssertEqual(store.getDeviceRequest()?.installID, "new-device-id")
  }

  func testIDFACommandsAreRecreatedAfterDrop() {
    store.createIDFACommandIfNeeded(automaticCollectIDFA: true)
    store.saveCommand(SKCommand(commandType: .idfaV4, status: .done, data: Data("idfa".utf8)))

    store.dropDeviceScopedCommands()
    store.createIDFACommandIfNeeded(automaticCollectIDFA: true)

    // Fresh install: the delayed 5 / 15 / 60 second fetches again
    XCTAssertEqual(store.getAllCommands(by: .fetchIdfa).count, 3)
    XCTAssertTrue(store.getAllCommands(by: .idfaV4).isEmpty)
  }

  func testAutomaticSearchAdsCommandIsRecreatedAfterDrop() {
    var searchAds = SKCommand(commandType: .automaticSearchAds, status: .pending, data: Data())
    store.saveCommand(searchAds)
    searchAds.changeStatus(to: .done)
    store.saveCommand(searchAds)

    store.dropDeviceScopedCommands()
    store.createAutomaticSearchAdsCommand(true)

    XCTAssertEqual(store.getAllCommands(by: .automaticSearchAds).map { $0.status }, [.pending])
  }

  // MARK: Helpers

  private func makeStore() -> SKCommandStore {
    return SKCommandStore(userDefaultsService: SKUserDefaultsService(userDefaults: userDefaults),
                          syncAllCommands: { [weak self] in self?.syncCount += 1 })
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

  private func allCommands() -> [SKCommand] {
    return statuses.flatMap { store.getAllCommands(by: $0) }
  }
}
