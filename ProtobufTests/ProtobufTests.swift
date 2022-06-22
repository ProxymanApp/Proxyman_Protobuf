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
        let file = bundle.url(forResource: "google", withExtension: "desc")!
        ProtobufRawImporter.registerRootDirectory(file.deletingLastPathComponent().path)
        let importer = ProtobufRawImporter.sharedInstance()

        var error : NSError?
        importer.paresFileDescriptor(atPath: file.path, error: &error)

        if let error = error {
            XCTFail(error.localizedDescription)
        }

        XCTAssertEqual(28, importer.getAllMessageTypes().count)
    }

    func testParseBookData() throws {


        let bundle = Bundle(for: ProtobufTests.self)
        let file = bundle.url(forResource: "book-desc", withExtension: "desc")!
        let root = file.deletingLastPathComponent()

        ProtobufRawImporter.registerRootDirectory(root.path)
        let importer = ProtobufRawImporter.sharedInstance()
        let fileGoogle = bundle.url(forResource: "google", withExtension: "desc")!

        // Import desc
        var error : NSError?
//        importer.paresFileDescriptor(atPath: fileGoogle.path, error: &error)
//        importer.paresFileDescriptor(atPath: file.path, error: &error)

        importer.loadProtobufFile(withName: "Book-scheme.proto")
        if let error = error {
            XCTFail(error.localizedDescription)
        }
//        XCTAssertEqual(1, importer.getAllMessageTypes().count)

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
            XCTFail()
        }
    }
}
