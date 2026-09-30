//
//  JSONService.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import Foundation

/// Result of JSON validation
struct ValidationResult {
    let isValid: Bool
    let errorMessage: String?
    let errorOffset: Int?
    let line: Int?
    let column: Int?
    /// Detected input format (set when valid)
    var kind: JSONInputKind? = nil
    /// Number of documents (JSONL)
    var documentCount: Int? = nil
    /// Extra friendly context (e.g. comment count, document count)
    var notes: String? = nil
}

/// Service for JSON processing operations
enum JSONService {

    // MARK: - Format (format-aware)

    /// Format JSON / JSON5 / JSONL input with the specified indentation.
    /// JSON5 is normalized first (comments removed); JSONL keeps one pretty
    /// document per line group, separated by a blank line.
    static func format(_ input: String, indent: Int = 2, sortedKeys: Bool = false) throws -> String {
        switch JSON5Service.detect(input) {
        case .json:
            return try formatStrict(input, indent: indent, sortedKeys: sortedKeys)
        case .json5:
            let normalized = try JSON5Service.normalize(input).json
            return try formatStrict(normalized, indent: indent, sortedKeys: sortedKeys)
        case .jsonl:
            return try mapJSONLLine(input, separator: "\n\n") { source in
                try formatStrict(source, indent: indent, sortedKeys: sortedKeys)
            }
        case nil:
            throw invalidInputError(input)
        }
    }

    /// Format strict JSON string with specified indentation
    /// - Parameters:
    ///   - input: Raw JSON string
    ///   - indent: Number of spaces for indentation (default: 2)
    ///   - sortedKeys: Whether to sort keys alphabetically (default: false)
    /// - Returns: Formatted JSON string
    /// - Throws: JSON formatting errors
    private static func formatStrict(_ input: String, indent: Int, sortedKeys: Bool) throws -> String {
        guard let data = input.data(using: .utf8) else {
            throw JSONError.invalidEncoding
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data)

        var options: JSONSerialization.WritingOptions = [.prettyPrinted]
        if sortedKeys {
            options.insert(.sortedKeys)
        }

        let outputData = try JSONSerialization.data(withJSONObject: jsonObject, options: options)
        guard let outputString = String(data: outputData, encoding: .utf8) else {
            throw JSONError.invalidEncoding
        }

        // Adjust indentation if not 2 spaces (default prettyPrinted uses 2)
        if indent != 2 {
            return adjustIndentation(outputString, to: indent)
        }

        return outputString
    }

    /// Adjust indentation of formatted JSON (reindent the 2-space prettyPrinted output line by line)
    private static func adjustIndentation(_ json: String, to spaces: Int) -> String {
        let indentUnit = String(repeating: " ", count: spaces)
        var depth = 0
        var lines: [String] = []

        for rawLine in json.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            // A line starting with a closing bracket dedents first
            if line.hasPrefix("}") || line.hasPrefix("]") {
                depth = max(0, depth - 1)
            }
            lines.append(String(repeating: indentUnit, count: depth) + line)
            // A line ending with an opening bracket indents its children
            if line.hasSuffix("{") || line.hasSuffix("[") {
                depth += 1
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Minify (format-aware)

    /// Minify JSON / JSON5 / JSONL input.
    /// JSONL output stays JSONL: one compact JSON value per line.
    static func minify(_ input: String) throws -> String {
        switch JSON5Service.detect(input) {
        case .json, .json5:
            let source = JSON5Service.parsesStrict(input)
                ? input
                : try JSON5Service.normalize(input).json
            return try minifyStrict(source)
        case .jsonl:
            return try mapJSONLLine(input, separator: "\n") { source in
                try minifyStrict(source)
            }
        case nil:
            throw invalidInputError(input)
        }
    }

    /// Minify strict JSON by removing whitespace
    private static func minifyStrict(_ input: String) throws -> String {
        guard let data = input.data(using: .utf8) else {
            throw JSONError.invalidEncoding
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let outputData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        guard let outputString = String(data: outputData, encoding: .utf8) else {
            throw JSONError.invalidEncoding
        }

        return outputString
    }

    // MARK: - Validate (format-aware)

    /// Validate JSON / JSON5 / JSONL input and return a detailed result
    static func validate(_ input: String) -> ValidationResult {
        switch JSON5Service.detect(input) {
        case .json:
            return validateStrict(input)
        case .json5:
            guard let normalized = try? JSON5Service.normalize(input) else {
                return diagnose(input)
            }
            return ValidationResult(
                isValid: true, errorMessage: nil, errorOffset: nil, line: nil, column: nil,
                kind: .json5, documentCount: 1,
                notes: normalized.commentsRemoved > 0
                    ? "\(normalized.commentsRemoved) comment(s) will be removed when formatting"
                    : "Relaxed JSON5 syntax accepted")
        case .jsonl:
            let lines = JSON5Service.jsonLines(in: input)
            return ValidationResult(
                isValid: true, errorMessage: nil, errorOffset: nil, line: nil, column: nil,
                kind: .jsonl, documentCount: lines.count,
                notes: "\(lines.count) documents · one JSON value per line")
        case nil:
            return diagnose(input)
        }
    }

    /// Validate strict JSON and return a detailed result
    private static func validateStrict(_ input: String) -> ValidationResult {
        guard let data = input.data(using: .utf8) else {
            return ValidationResult(
                isValid: false,
                errorMessage: "Invalid string encoding",
                errorOffset: nil,
                line: nil,
                column: nil
            )
        }

        // Check for empty input
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ValidationResult(
                isValid: false,
                errorMessage: "Input is empty",
                errorOffset: nil,
                line: nil,
                column: nil
            )
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return ValidationResult(
                isValid: true,
                errorMessage: nil,
                errorOffset: nil,
                line: nil,
                column: nil
            )
        } catch {
            let nsError = error as NSError

            // Try to extract error position from various sources
            var line: Int?
            var column: Int?
            var offset: Int?
            var detailedMessage: String?

            // Try NSDebugDescription first
            if let debugDesc = nsError.userInfo["NSDebugDescription"] as? String {
                detailedMessage = debugDesc
                // Parse "at position X" or "character X"
                let patterns = ["at position ", "character ", "index "]
                for pattern in patterns {
                    if let range = debugDesc.lowercased().range(of: pattern.lowercased()) {
                        let positionString = debugDesc[range.upperBound...]
                            .split(whereSeparator: { !$0.isNumber })
                            .first
                        if let posStr = positionString, let position = Int(posStr) {
                            offset = position
                            let result = calculateLineAndColumn(in: input, at: position)
                            line = result.line
                            column = result.column
                            break
                        }
                    }
                }
            }

            // Build error message
            var errorMessage = detailedMessage ?? nsError.localizedDescription

            // Add context around the error position
            if let offset = offset, offset < input.count {
                let contextResult = getErrorContext(in: input, at: offset)
                if !contextResult.isEmpty {
                    errorMessage += "\n\nNear: \(contextResult)"
                }
            }

            // Add line/column info
            if let line = line, let column = column {
                errorMessage += "\n\nLocation: Line \(line), Column \(column)"
            }

            return ValidationResult(
                isValid: false,
                errorMessage: errorMessage,
                errorOffset: offset,
                line: line,
                column: column
            )
        }
    }

    // MARK: - Format-aware Helpers

    /// Apply `transform` to every JSONL line (normalizing JSON5 lines first),
    /// joining results with `separator`
    private static func mapJSONLLine(
        _ input: String,
        separator: String,
        _ transform: (String) throws -> String
    ) throws -> String {
        try JSON5Service.jsonLines(in: input)
            .map { line -> String in
                let source = JSON5Service.parsesStrict(line)
                    ? line
                    : try JSON5Service.normalize(line).json
                return try transform(source)
            }
            .joined(separator: separator)
    }

    /// Single parseable JSON text for the tree view:
    /// JSONL becomes an array of its documents.
    static func treeSource(_ input: String) throws -> String {
        guard JSON5Service.detect(input) == .jsonl else {
            return try format(input)
        }
        let values = try JSON5Service.jsonLines(in: input).map { line -> Any in
            let source = JSON5Service.parsesStrict(line)
                ? line
                : try JSON5Service.normalize(line).json
            guard let data = source.data(using: .utf8) else {
                throw JSONError.invalidEncoding
            }
            return try JSONSerialization.jsonObject(with: data)
        }
        let data = try JSONSerialization.data(withJSONObject: values, options: [])
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Build the friendliest possible error for input that parses as nothing
    private static func diagnose(_ input: String) -> ValidationResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ValidationResult(
                isValid: false, errorMessage: "Input is empty",
                errorOffset: nil, line: nil, column: nil
            )
        }

        // Looks like broken JSONL (valid lines followed by a bad one)?
        if let bad = firstInvalidJSONLLine(in: input) {
            return ValidationResult(
                isValid: false,
                errorMessage: bad.message,
                errorOffset: nil,
                line: bad.lineNumber,
                column: nil
            )
        }

        // JSON5 syntax error with position
        do {
            _ = try JSON5Service.normalize(trimmed)
        } catch let error as JSON5SyntaxError {
            return ValidationResult(
                isValid: false,
                errorMessage: error.message,
                errorOffset: nil,
                line: error.line,
                column: error.column
            )
        } catch { /* fall through */ }

        // Normalized fine but still not valid JSON → report on normalized text
        if let normalized = try? JSON5Service.normalize(trimmed).json, !normalized.isEmpty {
            return validateStrict(normalized)
        }

        return validateStrict(trimmed)
    }

    /// First line that breaks JSONL shape — only when at least one earlier
    /// line already parsed (otherwise the input is more likely one broken document)
    private static func firstInvalidJSONLLine(in input: String) -> (lineNumber: Int, message: String)? {
        var lineNumber = 0
        var hasValidBefore = false

        for raw in input.components(separatedBy: .newlines) {
            lineNumber += 1
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if JSON5Service.parses(line) {
                hasValidBefore = true
                continue
            }
            if hasValidBefore {
                // normalizeError: syntax message when JSON5 parsing fails;
                // nil when it normalized fine but is still not valid JSON
                let detail = normalizeError(in: line) ?? "not valid JSON"
                return (lineNumber, "Line \(lineNumber) is not valid JSON/JSON5: \(detail)")
            }
            return nil
        }
        return nil
    }

    /// Message of the JSON5 syntax error contained in `line`, if any
    private static func normalizeError(in line: String) -> String? {
        do {
            _ = try JSON5Service.normalize(line)
        } catch let error as JSON5SyntaxError {
            return error.errorDescription
        } catch {
            return nil
        }
        return nil
    }

    /// Error thrown by format/minify when the input parses as nothing
    private static func invalidInputError(_ input: String) -> Error {
        let result = diagnose(input)
        return JSONError.invalidJSON(result.errorMessage ?? "Invalid JSON")
    }

    /// Get context around an error position
    private static func getErrorContext(in string: String, at offset: Int) -> String {
        let startIndex = string.index(string.startIndex, offsetBy: max(0, offset - 20), limitedBy: string.endIndex) ?? string.startIndex
        let endIndex = string.index(string.startIndex, offsetBy: min(string.count, offset + 20), limitedBy: string.endIndex) ?? string.endIndex

        let context = String(string[startIndex..<endIndex])
            .replacingOccurrences(of: "\n", with: "↵")
            .replacingOccurrences(of: "\r", with: "")

        return "...\(context)..."
    }

    /// Calculate line and column from character offset
    private static func calculateLineAndColumn(in string: String, at offset: Int) -> (line: Int, column: Int) {
        var line = 1
        var column = 1

        for (index, char) in string.enumerated() {
            if index >= offset {
                break
            }
            if char == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }

        return (line, column)
    }

    // MARK: - JSONL Conversion

    /// Convert JSON array to JSONL format
    /// - Parameter input: JSON array string
    /// - Returns: JSONL string (one JSON object per line)
    /// - Throws: JSON parsing errors
    static func toJSONL(_ input: String) throws -> String {
        guard let data = input.data(using: .utf8) else {
            throw JSONError.invalidEncoding
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data)

        guard let jsonArray = jsonObject as? [Any] else {
            throw JSONError.notAnArray
        }

        var lines: [String] = []

        for item in jsonArray {
            let itemData = try JSONSerialization.data(withJSONObject: item, options: [])
            guard let itemString = String(data: itemData, encoding: .utf8) else {
                throw JSONError.invalidEncoding
            }
            lines.append(itemString)
        }

        return lines.joined(separator: "\n")
    }

    /// Convert JSONL to JSON array
    /// - Parameter input: JSONL string
    /// - Returns: JSON array string
    /// - Throws: JSON parsing errors
    static func fromJSONL(_ input: String) throws -> String {
        var jsonArray: [Any] = []

        let lines = input.components(separatedBy: .newlines).filter { !$0.isEmpty }

        for line in lines {
            guard let data = line.data(using: .utf8) else {
                throw JSONError.invalidEncoding
            }
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            jsonArray.append(jsonObject)
        }

        // Compact output keeps each original line intact for round-trip fidelity
        let outputData = try JSONSerialization.data(withJSONObject: jsonArray, options: [])
        guard let outputString = String(data: outputData, encoding: .utf8) else {
            throw JSONError.invalidEncoding
        }

        return outputString
    }

    // MARK: - YAML Conversion

    /// Convert JSON to YAML format
    /// - Parameter input: JSON string
    /// - Returns: YAML string
    /// - Throws: JSON parsing errors
    static func toYAML(_ input: String) throws -> String {
        guard let data = input.data(using: .utf8) else {
            throw JSONError.invalidEncoding
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data)
        return convertToYAML(jsonObject, indent: 0)
    }

    /// Convert object to YAML string recursively
    private static func convertToYAML(_ object: Any, indent: Int) -> String {
        let indentString = String(repeating: "  ", count: indent)

        if let dict = object as? [String: Any] {
            if dict.isEmpty {
                return "{}"
            }

            var lines: [String] = []
            for (key, value) in dict {
                let yamlValue = convertToYAML(value, indent: indent + 1)
                if yamlValue.contains("\n") {
                    lines.append("\(indentString)\(key):")
                    lines.append(yamlValue)
                } else {
                    lines.append("\(indentString)\(key): \(yamlValue)")
                }
            }
            return lines.joined(separator: "\n")
        } else if let array = object as? [Any] {
            if array.isEmpty {
                return "[]"
            }

            var lines: [String] = []
            for item in array {
                let yamlValue = convertToYAML(item, indent: indent + 1)
                if yamlValue.contains("\n") {
                    lines.append("\(indentString)-")
                    lines.append(yamlValue)
                } else {
                    lines.append("\(indentString)- \(yamlValue)")
                }
            }
            return lines.joined(separator: "\n")
        } else if let string = object as? String {
            // Quote strings that need it
            if string.isEmpty || string.contains(":") || string.contains("#") || string.contains("\n") {
                return "\"\(string)\""
            }
            return string
        } else if let number = object as? NSNumber {
            return number.stringValue
        } else if let bool = object as? Bool {
            return bool ? "true" : "false"
        } else if object is NSNull {
            return "null"
        }

        return String(describing: object)
    }

    // MARK: - YAML ↔ Properties Conversion

    /// Convert YAML to Java Properties format
    /// - Parameter input: YAML string
    /// - Returns: Properties format string
    /// - Throws: YAML parsing errors
    static func yamlToProperties(_ input: String) throws -> String {
        let dict = try parseYAMLToDictionary(input)
        var lines: [String] = []
        flattenDictionary(dict, prefix: "", lines: &lines)
        return lines.joined(separator: "\n")
    }

    /// Convert Java Properties to YAML format
    /// - Parameter input: Properties format string
    /// - Returns: YAML string
    /// - Throws: Properties parsing errors
    static func propertiesToYAML(_ input: String) throws -> String {
        let dict = try parsePropertiesToDictionary(input)
        return convertDictionaryToYAML(dict, indent: 0)
    }

    // MARK: - YAML Parsing

    /// Parse YAML string to dictionary
    private static func parseYAMLToDictionary(_ input: String) throws -> [String: Any] {
        var result: [String: Any] = [:]
        let lines = input.components(separatedBy: .newlines)

        // Track the current path and indentation levels
        var pathStack: [(key: String, indent: Int)] = []

        // Detect indentation size from first indented line
        var indentSize = 2  // Default to 2 spaces
        for line in lines {
            let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" })
            if !leadingSpaces.isEmpty {
                // Count tabs as 1, spaces normally
                indentSize = leadingSpaces.reduce(0) { $0 + ($1 == "\t" ? 1 : 1) }
                break
            }
        }

        for line in lines {
            // Skip empty lines and comments
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { continue }

            // Calculate indentation level (support both tabs and spaces)
            let leadingWhitespace = line.prefix(while: { $0 == " " || $0 == "\t" })
            let indent = max(0, leadingWhitespace.count / max(1, indentSize))

            // Pop stack to current indentation level
            while !pathStack.isEmpty && pathStack.last!.indent >= indent {
                pathStack.removeLast()
            }

            // Skip array items for now (limited support)
            if trimmed.hasPrefix("- ") {
                continue
            }

            // Parse key-value pair
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let valuePart = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

                // Build full key path
                let fullPath = pathStack.map { $0.key } + [key]
                let fullKey = fullPath.joined(separator: ".")

                if valuePart.isEmpty {
                    // Nested object - push to stack
                    pathStack.append((key: key, indent: indent))
                } else {
                    // Leaf value - add to result
                    let value = parseYAMLValue(valuePart)
                    result[fullKey] = value
                }
            }
        }

        return result
    }

    /// Parse YAML value
    private static func parseYAMLValue(_ value: String) -> Any {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        // Boolean
        if trimmed == "true" { return true }
        if trimmed == "false" { return false }

        // Null
        if trimmed == "null" || trimmed == "~" { return NSNull() }

        // Number
        if let int = Int(trimmed) { return int }
        if let double = Double(trimmed) { return double }

        // Quoted string
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }

        // Plain string
        return trimmed
    }

    /// Flatten nested dictionary to dot-notation keys
    private static func flattenDictionary(_ dict: [String: Any], prefix: String, lines: inout [String]) {
        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"

            if let nested = value as? [String: Any] {
                flattenDictionary(nested, prefix: fullKey, lines: &lines)
            } else {
                let propValue = escapePropertyValue(value)
                lines.append("\(fullKey)=\(propValue)")
            }
        }
    }

    /// Escape property value for Properties format
    private static func escapePropertyValue(_ value: Any) -> String {
        let stringValue: String
        if let bool = value as? Bool {
            stringValue = bool ? "true" : "false"
        } else if let number = value as? NSNumber {
            stringValue = number.stringValue
        } else if value is NSNull {
            stringValue = ""
        } else {
            stringValue = String(describing: value)
        }

        // Escape special characters
        return stringValue
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    // MARK: - Properties Parsing

    /// Parse Properties string to nested dictionary
    private static func parsePropertiesToDictionary(_ input: String) throws -> [String: Any] {
        var result: [String: Any] = [:]

        let lines = input.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("!") else {
                continue
            }

            // Find separator
            guard let separatorIndex = trimmed.firstIndex(where: { $0 == "=" || $0 == ":" }) ?? trimmed.firstIndex(of: " ") else {
                continue
            }

            let key = String(trimmed[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespaces)

            // Unescape value
            value = unescapePropertyValue(value)

            // Build nested dictionary
            let keys = key.components(separatedBy: ".")
            buildNestedDictionary(&result, keys: keys, value: value)
        }

        return result
    }

    /// Unescape property value
    private static func unescapePropertyValue(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    /// Build nested dictionary from dot-notation key
    private static func buildNestedDictionary(_ dict: inout [String: Any], keys: [String], value: Any) {
        guard !keys.isEmpty else { return }

        if keys.count == 1 {
            dict[keys[0]] = value
        } else {
            let firstKey = keys[0]
            if dict[firstKey] == nil {
                dict[firstKey] = [String: Any]()
            }
            if var nested = dict[firstKey] as? [String: Any] {
                buildNestedDictionary(&nested, keys: Array(keys[1...]), value: value)
                dict[firstKey] = nested
            }
        }
    }

    /// Convert dictionary to YAML format
    private static func convertDictionaryToYAML(_ dict: [String: Any], indent: Int) -> String {
        let indentString = String(repeating: "  ", count: indent)
        var lines: [String] = []

        for (key, value) in dict {
            if let nested = value as? [String: Any] {
                lines.append("\(indentString)\(key):")
                lines.append(convertDictionaryToYAML(nested, indent: indent + 1))
            } else {
                let yamlValue = formatYAMLValue(value)
                lines.append("\(indentString)\(key): \(yamlValue)")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Format value for YAML output
    private static func formatYAMLValue(_ value: Any) -> String {
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if let number = value as? NSNumber {
            return number.stringValue
        } else if value is NSNull {
            return "null"
        } else {
            let stringValue = String(describing: value)
            // Quote strings that need it
            if stringValue.isEmpty || stringValue.contains(":") || stringValue.contains("#") || stringValue.contains("\n") {
                return "\"\(stringValue)\""
            }
            return stringValue
        }
    }
}

// MARK: - Errors

enum JSONError: LocalizedError {
    case invalidEncoding
    case notAnArray
    case notAnObject
    case conversionFailed
    case invalidYAML
    case invalidProperties
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Invalid string encoding"
        case .notAnArray:
            return "Input is not a JSON array"
        case .notAnObject:
            return "Input is not a JSON object"
        case .conversionFailed:
            return "Conversion failed"
        case .invalidYAML:
            return "Invalid YAML format"
        case .invalidProperties:
            return "Invalid Properties format"
        case .invalidJSON(let message):
            return message
        }
    }
}
