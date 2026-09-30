//
//  JSON5ServiceTests.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import XCTest
@testable import PeggyTools

final class JSON5ServiceTests: XCTestCase {

    // MARK: - Normalize: comments

    func testNormalizeRemovesCommentsButKeepsURLs() throws {
        let input = """
        {
          // line comment
          /* block
             comment */
          "a": 1, // trailing comment
          "url": "http://example.com"
        }
        """
        let result = try JSON5Service.normalize(input)

        XCTAssertEqual(result.commentsRemoved, 3)
        XCTAssertTrue(result.json.contains("http://example.com"))
        XCTAssertFalse(result.json.contains("comment"))
        XCTAssertTrue(JSON5Service.parsesStrict(result.json))
    }

    // MARK: - Normalize: trailing commas

    func testNormalizeRemovesTrailingCommas() throws {
        let input = #"{"a": [1, 2,], "b": {"c": 3,},}"#
        let result = try JSON5Service.normalize(input)

        XCTAssertTrue(JSON5Service.parsesStrict(result.json))

        let object = try JSONSerialization.jsonObject(with: Data(result.json.utf8)) as? [String: Any]
        XCTAssertEqual(object?["a"] as? [Int], [1, 2])
        XCTAssertEqual((object?["b"] as? [String: Any])?["c"] as? Int, 3)
    }

    // MARK: - Normalize: strings

    func testNormalizeSingleQuotedStrings() throws {
        let input = #"{'a': 'it\'s', 'b': "say \"hi\"", 'c': "raw'double"}"#
        let result = try JSON5Service.normalize(input)

        let object = try JSONSerialization.jsonObject(with: Data(result.json.utf8)) as? [String: String]
        XCTAssertEqual(object?["a"], "it's")
        XCTAssertEqual(object?["b"], "say \"hi\"")
        XCTAssertEqual(object?["c"], "raw'double")
    }

    func testNormalizeHexEscape() throws {
        let input = #"{'a': '\x41'}"#
        let result = try JSON5Service.normalize(input)

        let object = try JSONSerialization.jsonObject(with: Data(result.json.utf8)) as? [String: String]
        XCTAssertEqual(object?["a"], "A")
    }

    // MARK: - Normalize: unquoted keys

    func testNormalizeUnquotedKeys() throws {
        let input = #"{ name: 'x', $id: 1, under_score: true, nested: { deep: null }}"#
        let result = try JSON5Service.normalize(input)

        let object = try JSONSerialization.jsonObject(with: Data(result.json.utf8)) as? [String: Any]
        XCTAssertEqual(object?["name"] as? String, "x")
        XCTAssertEqual(object?["$id"] as? Int, 1)
        XCTAssertEqual(object?["under_score"] as? Bool, true)
        XCTAssertTrue((object?["nested"] as? [String: Any])?["deep"] is NSNull)
    }

    // MARK: - Normalize: numbers

    func testNormalizeNumbers() throws {
        let input = #"{hex: 0xFF, dot5: .5, dotTrail: 5., plus: +3, exp: -2e3}"#
        let result = try JSON5Service.normalize(input)

        XCTAssertTrue(result.json.contains("255"))
        XCTAssertTrue(result.json.contains("0.5"))
        XCTAssertTrue(result.json.contains("5.0"))

        let object = try JSONSerialization.jsonObject(with: Data(result.json.utf8)) as? [String: NSNumber]
        XCTAssertEqual(object?["hex"]?.doubleValue, 255)
        XCTAssertEqual(object?["dot5"]?.doubleValue, 0.5)
        XCTAssertEqual(object?["plus"]?.doubleValue, 3)
        XCTAssertEqual(object?["exp"]?.doubleValue, -2000)
    }

    // MARK: - Normalize: errors

    func testNormalizeInfinityThrows() {
        XCTAssertThrowsError(try JSON5Service.normalize(#"{a: Infinity}"#)) { error in
            XCTAssertTrue("\(error)".contains("Infinity"))
        }
    }

    func testNormalizeNaNThrows() {
        XCTAssertThrowsError(try JSON5Service.normalize("{a: -NaN}"))
    }

    func testNormalizeBareWordThrows() {
        XCTAssertThrowsError(try JSON5Service.normalize(#"{a: hello}"#)) { error in
            XCTAssertTrue("\(error)".contains("hello"))
        }
    }

    func testNormalizeErrorCarriesPosition() {
        XCTAssertThrowsError(try JSON5Service.normalize("{\n  a: 1,\n  b: oops\n}")) { error in
            guard let syntaxError = error as? JSON5SyntaxError else {
                return XCTFail("expected JSON5SyntaxError, got \(error)")
            }
            XCTAssertEqual(syntaxError.line, 3)
        }
    }

    // MARK: - Detection

    func testDetectStrictJSON() {
        XCTAssertEqual(JSON5Service.detect(#"{"a": 1}"#), .json)
        XCTAssertEqual(JSON5Service.detect("""
        {
          "a": 1,
          "b": [1, 2]
        }
        """), .json)
    }

    func testDetectJSON5() {
        XCTAssertEqual(JSON5Service.detect("{ // comment\n a: 1 }"), .json5)
        XCTAssertEqual(JSON5Service.detect(#"{'a': 1}"#), .json5)
    }

    func testDetectJSONL() {
        XCTAssertEqual(JSON5Service.detect("{\"a\":1}\n{\"b\":2}"), .jsonl)
        XCTAssertEqual(JSON5Service.detect("123\n\"text\"\n[1, 2]"), .jsonl)
    }

    func testDetectInvalid() {
        XCTAssertNil(JSON5Service.detect(""))
        XCTAssertNil(JSON5Service.detect("   "))
        XCTAssertNil(JSON5Service.detect("{broken"))
        XCTAssertNil(JSON5Service.detect(#"{a: Infinity}"#))
    }

    // MARK: - Format (format-aware)

    func testFormatJSON5() throws {
        let input = "{ // config\n host: 'localhost', ports: [80, 8080,], }"
        let output = try JSONService.format(input, sortedKeys: true)

        XCTAssertTrue(output.contains("host"))
        XCTAssertTrue(output.contains("8080"))
        XCTAssertTrue(JSON5Service.parsesStrict(output))
    }

    func testFormatJSON5WithCustomIndent() throws {
        let output = try JSONService.format("{a: {b: 1}}", indent: 4)
        XCTAssertTrue(output.contains("    \"b\""))
    }

    func testFormatJSONLProducesOnePrettyBlockPerDocument() throws {
        let output = try JSONService.format("{\"a\": 1}\n{\"b\": 2}")
        let blocks = output.components(separatedBy: "\n\n")

        XCTAssertEqual(blocks.count, 2)
        XCTAssertTrue(JSON5Service.parsesStrict(blocks[0]))
        XCTAssertTrue(JSON5Service.parsesStrict(blocks[1]))
    }

    // MARK: - Minify (format-aware)

    func testMinifyJSON5() throws {
        let output = try JSONService.minify("{ // c\n a: 1, }")
        XCTAssertTrue(JSON5Service.parsesStrict(output))
        XCTAssertEqual(output, #"{"a":1}"#)
    }

    func testMinifyJSONLStaysJSONL() throws {
        let output = try JSONService.minify("{ \"a\" : 1 }\n{ \"b\" : 2 }")
        let lines = output.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], "{\"a\":1}")
        XCTAssertEqual(lines[1], "{\"b\":2}")
    }

    // MARK: - Validate (format-aware)

    func testValidateJSON5() {
        let result = JSONService.validate("{ a: 1, // c\n}")

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.kind, .json5)
        XCTAssertEqual(result.documentCount, 1)
        XCTAssertTrue(result.notes?.contains("comment") == true)
    }

    func testValidateJSONL() {
        let result = JSONService.validate("{\"a\":1}\n{\"b\":2}\n123")

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.kind, .jsonl)
        XCTAssertEqual(result.documentCount, 3)
    }

    func testValidateBrokenJSONLReportsLine() {
        let result = JSONService.validate("{\"a\":1}\n{bad}")

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.line, 2)
        XCTAssertTrue(result.errorMessage?.contains("Line 2") == true)
    }

    func testValidateSingleBrokenDocumentIsNotReportedAsJSONL() {
        let result = JSONService.validate("{\n \"a\": }")

        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.errorMessage?.contains("is not valid JSON/JSON5") == true)
    }

    // MARK: - Tree source

    func testTreeSourceJSONLBecomesArray() throws {
        let output = try JSONService.treeSource("{\"a\":1}\n{\"b\":2}")

        XCTAssertEqual(output, "[{\"a\":1},{\"b\":2}]")
    }

    func testTreeSourceSingleDocumentStaysSame() throws {
        let output = try JSONService.treeSource("{\"a\":1}")

        XCTAssertTrue(JSON5Service.parsesStrict(output))
        XCTAssertTrue(output.contains("a"))
    }
}
