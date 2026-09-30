//
//  JSONServiceTests.swift
//  PeggyToolsTests
//
//  Created by Peggy Tools
//

import XCTest
@testable import PeggyTools

final class JSONServiceTests: XCTestCase {

    // MARK: - Format Tests

    func testFormatValidJSON() throws {
        let input = "{\"name\":\"test\",\"value\":123}"
        let output = try JSONService.format(input)

        XCTAssertTrue(output.contains("\"name\" : \"test\""))
        XCTAssertTrue(output.contains("\"value\" : 123"))
    }

    func testFormatWithCustomIndent() throws {
        let input = "{\"a\":1}"
        let output = try JSONService.format(input, indent: 4)

        XCTAssertTrue(output.contains("    "))  // 4 spaces
    }

    func testFormatWithSortedKeys() throws {
        let input = "{\"z\":1,\"a\":2,\"m\":3}"
        let output = try JSONService.format(input, sortedKeys: true)

        // 'a' should come before 'm' and 'z'
        let aIndex = output.range(of: "\"a\"")?.lowerBound
        let mIndex = output.range(of: "\"m\"")?.lowerBound
        let zIndex = output.range(of: "\"z\"")?.lowerBound

        XCTAssertLessThan(aIndex!, mIndex!)
        XCTAssertLessThan(mIndex!, zIndex!)
    }

    func testFormatInvalidJSON() {
        let input = "{invalid json}"

        XCTAssertThrowsError(try JSONService.format(input))
    }

    // MARK: - Minify Tests

    func testMinifyJSON() throws {
        let input = """
        {
            "name": "test",
            "value": 123
        }
        """
        let output = try JSONService.minify(input)

        XCTAssertEqual(output, "{\"name\":\"test\",\"value\":123}")
    }

    func testMinifyAlreadyMinified() throws {
        let input = "{\"a\":1}"
        let output = try JSONService.minify(input)

        XCTAssertEqual(output, "{\"a\":1}")
    }

    // MARK: - Validate Tests

    func testValidateValidJSON() {
        let input = "{\"name\":\"test\"}"
        let result = JSONService.validate(input)

        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testValidateValidJSONArray() {
        let input = "[1, 2, 3]"
        let result = JSONService.validate(input)

        XCTAssertTrue(result.isValid)
    }

    func testValidateInvalidJSON() {
        let input = "{invalid}"
        let result = JSONService.validate(input)

        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
    }

    func testValidateUnclosedBrace() {
        let input = "{\"name\":\"test\""
        let result = JSONService.validate(input)

        XCTAssertFalse(result.isValid)
    }

    // MARK: - JSONL Tests

    func testToJSONL() throws {
        let input = "[{\"a\":1},{\"b\":2}]"
        let output = try JSONService.toJSONL(input)

        let lines = output.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], "{\"a\":1}")
        XCTAssertEqual(lines[1], "{\"b\":2}")
    }

    func testFromJSONL() throws {
        let input = "{\"a\":1}\n{\"b\":2}"
        let output = try JSONService.fromJSONL(input)

        XCTAssertTrue(output.contains("["))
        XCTAssertTrue(output.contains("{\"a\":1}"))
        XCTAssertTrue(output.contains("{\"b\":2}"))
    }

    func testToJSONLNotArray() {
        let input = "{\"a\":1}"

        XCTAssertThrowsError(try JSONService.toJSONL(input))
    }

    // MARK: - YAML Tests

    func testToYAMLSimple() throws {
        let input = "{\"name\":\"test\",\"count\":42}"
        let output = try JSONService.toYAML(input)

        XCTAssertTrue(output.contains("name: test"))
        XCTAssertTrue(output.contains("count: 42"))
    }

    func testToYAMLNested() throws {
        let input = "{\"user\":{\"name\":\"John\",\"age\":30}}"
        let output = try JSONService.toYAML(input)

        XCTAssertTrue(output.contains("user:"))
        XCTAssertTrue(output.contains("name: John"))
        XCTAssertTrue(output.contains("age: 30"))
    }

    func testToYAMLArray() throws {
        let input = "[1,2,3]"
        let output = try JSONService.toYAML(input)

        XCTAssertTrue(output.contains("- 1"))
        XCTAssertTrue(output.contains("- 2"))
        XCTAssertTrue(output.contains("- 3"))
    }
}
