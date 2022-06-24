//
//  ProtobufTests.swift
//  ProtobufTests
//
//  Created by Nghia Tran on 19/11/2021.
//

import XCTest
@testable import Protobuf

class ProtobufTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        ProtobufRawImporter.sharedInstance().resetAll()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testParseDescFromProtobufFile() throws {
        let bundle = Bundle(for: ProtobufTests.self)
        let file = bundle.url(forResource: "data", withExtension: "desc")!
        ProtobufRawImporter.registerRootDirectory(file.deletingLastPathComponent().path)
        let importer = ProtobufRawImporter.sharedInstance()

        var error : NSError?
        importer.paresFileDescriptor(atPath: file.path, error: &error)

        if let error = error {
            XCTFail(error.localizedDescription)
        }

        XCTAssertEqual(3, importer.getAllMessageTypes().count)
    }

    func testParseGoogleFile() throws {
        let bundle = Bundle(for: ProtobufTests.self)
        let file = bundle.url(forResource: "google.common", withExtension: "desc")!
        ProtobufRawImporter.registerRootDirectory(file.deletingLastPathComponent().path)
        let importer = ProtobufRawImporter.sharedInstance()

        var error : NSError?
        importer.paresFileDescriptor(atPath: file.path, error: &error)

        if let error = error {
            XCTFail(error.localizedDescription)
        }
        print(importer.getAllMessageTypes())
        XCTAssertEqual(47, importer.getAllMessageTypes().count)
    }

    func testParseBookData() throws {
        let bundle = Bundle(for: ProtobufTests.self)
        let file = bundle.url(forResource: "book-desc", withExtension: "desc")!
        let root = file.deletingLastPathComponent()

        ProtobufRawImporter.registerRootDirectory(root.path)
        let importer = ProtobufRawImporter.sharedInstance()
        let fileGoogle = bundle.url(forResource: "google.common", withExtension: "desc")!

        // Import desc
        var error : NSError?
        importer.paresFileDescriptor(atPath: fileGoogle.path, error: &error)
        importer.paresFileDescriptor(atPath: file.path, error: &error)
        if let error = error {
            XCTFail(error.localizedDescription)
        }

        // parse data
        let dataURL = bundle.url(forResource: "binary_BookInfo", withExtension: "data")!
        let data = try! Data(contentsOf: dataURL)
        let rawContents = importer.parseProtobufContent(withMessageType: "com.proxyman.BookInfo", from: data, payloadMode: PXProtobufPayloadModeAuto)

        let expected = """
"title":"Really Interesting Book"
"""
        if let rawText = rawContents.first?.rawText {
            XCTAssertTrue(rawText.contains(expected))
        } else {
            print(rawContents.first!.error!)
            XCTFail()
        }
    }

    func testWithGoogleProto() throws {
        let bundle = Bundle(for: ProtobufTests.self)
        let file = bundle.url(forResource: "config", withExtension: "desc")!
        let root = file.deletingLastPathComponent()

        ProtobufRawImporter.registerRootDirectory(root.path)
        let importer = ProtobufRawImporter.sharedInstance()
        let fileGoogle = bundle.url(forResource: "google", withExtension: "desc")!

        // Import desc
        var error : NSError?
        importer.paresFileDescriptor(atPath: fileGoogle.path, error: &error)
        importer.paresFileDescriptor(atPath: file.path, error: &error)
        if let error = error {
            XCTFail(error.localizedDescription)
        }

        print(importer.getAllMessageTypes())

        // parse data
        let dataURL = bundle.url(forResource: "config_dump_protobuff", withExtension: "data")!
        let data = try! Data(contentsOf: dataURL)
        let rawContents = importer.parseProtobufContent(withMessageType: "envoy.admin.v3.ClustersConfigDump", from: data, payloadMode: PXProtobufPayloadModeAuto)

        if let rawText = rawContents.first?.rawText {
            let expected = """
{"versionInfo":"Proxyman 3.5.0","staticClusters":[{"cluster":{"@type":"type.googleapis.com/google.protobuf.Timestamp","value":"2022-06-23T02:38:54.814669013Z"},"lastUpdated":"2022-06-23T02:38:54.815036058Z"},{"cluster":{"@type":"type.googleapis.com/google.protobuf.Timestamp","value":"2022-06-23T02:38:54.814669013Z"},"lastUpdated":"2022-06-23T02:38:54.815049052Z"}],"dynamicActiveClusters":[{"versionInfo":"v1.0","cluster":{"@type":"type.googleapis.com/google.protobuf.Timestamp","value":"2022-06-23T02:38:54.814669013Z"},"lastUpdated":"2022-06-23T02:38:54.815062046Z","errorState":{"failedConfiguration":{"@type":"type.googleapis.com/google.protobuf.Timestamp","value":"2022-06-23T02:38:54.814669013Z"}}},{"versionInfo":"v2.0","cluster":{"@type":"type.googleapis.com/google.protobuf.Timestamp","value":"2022-06-23T02:38:54.814669013Z"},"lastUpdated":"2022-06-23T02:38:54.815089941Z","errorState":{"failedConfiguration":{"@type":"type.googleapis.com/google.protobuf.Timestamp","value":"2022-06-23T02:38:54.814669013Z"}}}]}
"""
            XCTAssertEqual(expected, rawText)
        } else {
            print(rawContents.first!.error!)
            XCTFail()
        }
    }
}
