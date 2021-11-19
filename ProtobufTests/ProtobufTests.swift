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
        let file = bundle.url(forResource: "task", withExtension: "proto")!
        ProtobufRawImporter.registerRootDirectory(file.deletingLastPathComponent().path)
        let importer = ProtobufRawImporter.sharedInstance()

        importer.parseDescriptorFromProto()
    }
}
