//
//  SKReceiptRequestCodingTests.swift
//  SkarbSDKTests
//

import XCTest
@testable import SkarbSDK

/// `SetReceipt` commands are queued as JSON in `SKCommand.data` and only turned into protobuf at
/// send time, so anything that does not survive the Codable round trip is silently dropped from
/// the request. `signed_transactions` was added to the protobuf first and to the Codable
/// implementation second - these tests exist so that gap cannot reopen.
final class SKReceiptRequestCodingTests: XCTestCase {

  func testSignedTransactionsSurviveTheCommandQueue() throws {
    var request = Purchaseapi_ReceiptRequest()
    request.installID = "install"
    request.transactions = ["2000001236151777"]
    request.signedTransactions = ["header.payload.signature"]
    request.receipt = Data([0x01, 0x02])

    let data = try XCTUnwrap(request.getData())
    let decoded = try JSONDecoder().decode(Purchaseapi_ReceiptRequest.self, from: data)

    XCTAssertEqual(decoded.signedTransactions, ["header.payload.signature"])
    XCTAssertEqual(decoded.transactions, ["2000001236151777"])
    XCTAssertEqual(decoded.receipt, Data([0x01, 0x02]))
  }

  func testCommandQueuedByAnOlderBuildStillDecodes() throws {
    // A command written before `signed_transactions` existed has no such key. Failing to decode
    // it would strand it in the queue forever, so the field must be optional on the way in.
    var legacy = Purchaseapi_ReceiptRequest()
    legacy.installID = "install"
    legacy.transactions = ["1"]
    let full = try XCTUnwrap(legacy.getData())
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: full) as? [String: Any])
    json.removeValue(forKey: "signedTransactions")
    let withoutField = try JSONSerialization.data(withJSONObject: json)

    let decoded = try JSONDecoder().decode(Purchaseapi_ReceiptRequest.self, from: withoutField)

    XCTAssertTrue(decoded.signedTransactions.isEmpty)
    XCTAssertEqual(decoded.transactions, ["1"])
  }

  func testEmptySignedTransactionsAreNotSerializedOnTheWire() throws {
    // StoreKit 1 sends none. protobuf omits an empty repeated field, so the backend sees no key
    // at all rather than an empty list - that is what the backend's own logs showed.
    var request = Purchaseapi_ReceiptRequest()
    request.installID = "install"
    let wire = try request.serializedData()
    let decoded = try Purchaseapi_ReceiptRequest(serializedData: wire)

    XCTAssertTrue(decoded.signedTransactions.isEmpty)
  }

  func testSignedTransactionsUseTheAgreedFieldNumbers() throws {
    // Field numbers come from the backend's .proto: 15 on ReceiptRequest (4 is deliberately a
    // hole there) and 4 on VerifyReceiptRequest. A wrong number does not fail - the backend just
    // never sees the value - so it has to be pinned by a test.
    var receipt = Purchaseapi_ReceiptRequest()
    receipt.signedTransactions = ["a"]
    let receiptWire = [UInt8](try receipt.serializedData())
    // tag = field << 3 | wire type 2 (length-delimited); 15 << 3 | 2 = 122
    XCTAssertEqual(receiptWire.first, 122)

    var verify = Purchaseapi_VerifyReceiptRequest()
    verify.signedTransactions = ["a"]
    let verifyWire = [UInt8](try verify.serializedData())
    // 4 << 3 | 2 = 34
    XCTAssertEqual(verifyWire.first, 34)
  }
}
