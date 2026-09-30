//
//  JSON5Service.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import Foundation

/// Input format detected by JSON Tools
enum JSONInputKind: String {
    case json = "JSON"
    case json5 = "JSON5"
    case jsonl = "JSONL"
}

/// Result of normalizing JSON5 text to strict JSON
struct JSON5NormalizeResult {
    /// Strict-JSON equivalent of the input (comments removed, keys quoted, …)
    let json: String
    /// How many comments were removed
    let commentsRemoved: Int
}

/// Syntax error with source position, so users get Line/Column hints
struct JSON5SyntaxError: Error, LocalizedError {
    let message: String
    let line: Int
    let column: Int

    var errorDescription: String? {
        "\(message) (Line \(line), Column \(column))"
    }
}

/// Normalizes JSON5 text (comments, single quotes, unquoted keys, trailing
/// commas, hex / `.5` / `5.` / `+n` numbers) into equivalent strict JSON.
///
/// Implemented as a single string-aware pass — a naive regex approach would
/// mangle strings that contain `//`, `,}` etc.
enum JSON5Service {

    // MARK: - Detection

    /// Detect the input format: strict JSON → JSON5 → JSONL (≥ 2 lines, each a value)
    static func detect(_ input: String) -> JSONInputKind? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if parsesStrict(trimmed) { return .json }

        if let normalized = try? normalize(trimmed), parsesStrict(normalized.json) {
            return .json5
        }

        let lines = jsonLines(in: trimmed)
        if lines.count >= 2, lines.allSatisfy({ parses($0) }) {
            return .jsonl
        }

        return nil
    }

    /// Whether the text parses as strict JSON (top-level scalars allowed —
    /// a JSONL line may be any JSON value, not only objects/arrays)
    static func parsesStrict(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
    }

    /// Whether the text parses as strict JSON or JSON5
    static func parses(_ text: String) -> Bool {
        if parsesStrict(text) { return true }
        guard let normalized = try? normalize(text) else { return false }
        return parsesStrict(normalized.json)
    }

    /// Non-empty trimmed lines of a JSONL input
    static func jsonLines(in input: String) -> [String] {
        input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Normalization

    static func normalize(_ input: String) throws -> JSON5NormalizeResult {
        let chars = Array(input)
        var out = String()
        var i = 0
        var commentsRemoved = 0
        var stack: [Character] = []     // "{" or "["
        var expectKey = false           // next significant token may be an unquoted key
        var pendingComma = false        // comma held back so trailing commas can be dropped

        // MARK: helpers

        func position(_ index: Int) -> (line: Int, column: Int) {
            var line = 1
            var column = 1
            for j in 0..<min(index, chars.count) {
                if chars[j] == "\n" { line += 1; column = 1 } else { column += 1 }
            }
            return (line, column)
        }

        func fail(_ index: Int, _ message: String) throws -> Never {
            let p = position(index)
            throw JSON5SyntaxError(message: message, line: p.line, column: p.column)
        }

        /// Next index at/after `index` that is neither whitespace nor comment
        func nextSignificant(from index: Int) -> Int? {
            var j = index
            while j < chars.count {
                let c = chars[j]
                if c == " " || c == "\t" || c == "\n" || c == "\r" { j += 1; continue }
                if c == "/", j + 1 < chars.count {
                    if chars[j + 1] == "/" {
                        j += 2
                        while j < chars.count, chars[j] != "\n" { j += 1 }
                        continue
                    }
                    if chars[j + 1] == "*" {
                        j += 2
                        while j + 1 < chars.count, !(chars[j] == "*" && chars[j + 1] == "/") { j += 1 }
                        if j + 1 < chars.count { j += 2 }
                        continue
                    }
                }
                return j
            }
            return nil
        }

        func flushPendingComma() {
            if pendingComma {
                out.append(",")
                pendingComma = false
            }
        }

        // MARK: scan

        while i < chars.count {
            let c = chars[i]

            // Whitespace: keep (positions in output stay close to the input)
            if c == " " || c == "\t" || c == "\n" || c == "\r" {
                out.append(c)
                i += 1
                continue
            }

            // Comments
            if c == "/", i + 1 < chars.count {
                if chars[i + 1] == "/" {
                    commentsRemoved += 1
                    i += 2
                    while i < chars.count, chars[i] != "\n" { i += 1 }
                    continue
                }
                if chars[i + 1] == "*" {
                    commentsRemoved += 1
                    i += 2
                    var closed = false
                    while i < chars.count {
                        if chars[i] == "*", i + 1 < chars.count, chars[i + 1] == "/" {
                            i += 2
                            closed = true
                            break
                        }
                        i += 1
                    }
                    if !closed { try fail(i, "Unterminated block comment") }
                    out.append(" ")
                    continue
                }
            }

            // Strings (single- or double-quoted) → always double-quoted output
            if c == "\"" || c == "'" {
                flushPendingComma()
                out.append("\"")
                i += 1
                var closed = false
                while i < chars.count {
                    let sc = chars[i]

                    if sc == "\\" {
                        guard i + 1 < chars.count else { try fail(i, "Unterminated string") }
                        let e = chars[i + 1]
                        switch e {
                        case "'":
                            out.append("'")                 // \' → ' (no escape needed in JSON)
                        case "\"":
                            out.append("\\\"")
                        case "\n", "\r":                    // backslash line continuation: drop
                            if e == "\r", i + 2 < chars.count, chars[i + 2] == "\n" { i += 1 }
                        case "v":
                            out.append("\\u000B")           // \v is not a JSON escape
                        case "0":
                            out.append("\\u0000")
                        case "x":
                            guard i + 3 < chars.count,
                                  let code = UInt32(String(chars[(i + 2)...(i + 3)]), radix: 16) else {
                                try fail(i, "Invalid \\x escape sequence")
                            }
                            out += String(format: "\\u%04x", code)
                            i += 2                          // consumed 2 hex digits beyond the escape
                        default:
                            out.append("\\")
                            out.append(e)                   // \n \t \r \b \f \uXXXX … pass through
                        }
                        i += 2
                        continue
                    }

                    if sc == c {                            // closing quote
                        closed = true
                        i += 1
                        break
                    }
                    if sc == "\"" {                         // bare " inside single-quoted string
                        out.append("\\\"")
                        i += 1
                        continue
                    }
                    if sc == "\n" || sc == "\r" {           // tolerate raw line breaks
                        out.append("\\n")
                        if sc == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                        i += 1
                        continue
                    }

                    out.append(sc)
                    i += 1
                }
                if !closed { try fail(i, "Unterminated string") }
                out.append("\"")
                expectKey = false
                continue
            }

            // Signed Infinity / NaN (also catches stray sign + letter combos)
            if c == "-" || c == "+", i + 1 < chars.count, chars[i + 1].isLetter {
                try fail(i, "JSON5 Infinity/NaN cannot be represented in standard JSON")
            }

            // Numbers (hex, .5, 5., +1, -2e3)
            let startsNumber = c.isNumber
                || (c == "." && i + 1 < chars.count && chars[i + 1].isNumber)
                || ((c == "-" || c == "+") && i + 1 < chars.count && (chars[i + 1].isNumber || chars[i + 1] == "."))
            if startsNumber {
                var j = i
                var sign = ""
                if chars[j] == "+" { j += 1 }               // JSON allows no leading +
                else if chars[j] == "-" { sign = "-"; j += 1 }

                // Hexadecimal
                if j + 1 < chars.count, chars[j] == "0", chars[j + 1] == "x" || chars[j + 1] == "X" {
                    var k = j + 2
                    var hex = ""
                    while k < chars.count, chars[k].isHexDigit { hex.append(chars[k]); k += 1 }
                    guard !hex.isEmpty, let value = UInt64(hex, radix: 16) else {
                        try fail(i, "Invalid hexadecimal number")
                    }
                    flushPendingComma()
                    out += sign
                    out += String(value)
                    i = k
                    expectKey = false
                    continue
                }

                var intPart = ""
                var fracPart = ""
                var expPart = ""
                var hasDot = false
                while j < chars.count, chars[j].isNumber { intPart.append(chars[j]); j += 1 }
                if j < chars.count, chars[j] == "." {
                    hasDot = true
                    j += 1
                    while j < chars.count, chars[j].isNumber { fracPart.append(chars[j]); j += 1 }
                }
                if j < chars.count, chars[j] == "e" || chars[j] == "E" {
                    var k = j + 1
                    var expSign = ""
                    if k < chars.count, chars[k] == "+" || chars[k] == "-" {
                        expSign = String(chars[k])
                        k += 1
                    }
                    var digits = ""
                    while k < chars.count, chars[k].isNumber { digits.append(chars[k]); k += 1 }
                    if !digits.isEmpty {
                        expPart = "e" + expSign + digits
                        j = k
                    }
                }
                guard !intPart.isEmpty || !fracPart.isEmpty else {
                    try fail(i, "Invalid number")
                }
                flushPendingComma()
                out += sign
                if hasDot {
                    // JSON requires digits on both sides of the decimal point
                    out += intPart.isEmpty ? "0" : intPart
                    out += "."
                    out += fracPart.isEmpty ? "0" : fracPart
                } else {
                    out += intPart
                }
                out += expPart
                i = j
                expectKey = false
                continue
            }

            // Identifiers: unquoted keys, true/false/null
            if c.isLetter || c == "_" || c == "$" {
                var j = i
                while j < chars.count {
                    let ch = chars[j]
                    if ch.isLetter || ch.isNumber || ch == "_" || ch == "$" { j += 1 } else { break }
                }
                let identifier = String(chars[i..<j])

                // Unquoted object key when followed by ':'
                if expectKey, let next = nextSignificant(from: j), chars[next] == ":" {
                    flushPendingComma()
                    out += "\"" + identifier + "\""
                    i = j
                    continue                                  // ':' is handled in the main loop
                }

                switch identifier {
                case "true", "false", "null":
                    flushPendingComma()
                    out += identifier
                    i = j
                    expectKey = false
                case "Infinity", "NaN":
                    try fail(i, "JSON5 Infinity/NaN cannot be represented in standard JSON")
                default:
                    try fail(i, "Unexpected identifier \"\(identifier)\" — unquoted keys are only allowed inside objects")
                }
                continue
            }

            // Structural characters
            switch c {
            case "{":
                flushPendingComma()
                out.append(c)
                stack.append("{")
                expectKey = true
                i += 1
            case "[":
                flushPendingComma()
                out.append(c)
                stack.append("[")
                expectKey = false
                i += 1
            case "}", "]":
                pendingComma = false                           // drop trailing comma
                out.append(c)
                if !stack.isEmpty { stack.removeLast() }
                expectKey = false
                i += 1
            case ",":
                pendingComma = true
                expectKey = (stack.last == "{")
                i += 1
            case ":":
                out.append(c)
                expectKey = false
                i += 1
            default:
                try fail(i, "Unexpected character \"\(c)\"")
            }
        }

        return JSON5NormalizeResult(json: out, commentsRemoved: commentsRemoved)
    }
}
