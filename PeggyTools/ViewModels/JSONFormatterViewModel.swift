//
//  JSONFormatterViewModel.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import Foundation
import SwiftUI

/// `--demo` / `--demo-tree` 启动参数下预填的演示数据。
/// 放在 VM 默认初始化里，保证 SwiftUI 无论重建多少次视图身份，演示内容都在。
private let demoSampleInput = """
{
  // Peggy Tools 演示数据（JSON5）
  name: 'peggy-tools',
  version: 2,
  host: "127.0.0.1",
  ports: [80, 8080,],        // 尾逗号也没问题
  features: {
    json5: true,
    jsonl: true,
    timeout: .5,
  },
}
"""

/// ViewModel for JSON formatting operations
@MainActor
class JSONFormatterViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var inputText: String = "" {
        didSet { inputKind = JSON5Service.detect(inputText) }
    }

    init(initialInput: String = ProcessInfo.processInfo.arguments.contains(where: { $0 == "--demo" || $0 == "--demo-tree" })
        ? demoSampleInput
        : "") {
        self.inputText = initialInput
        self.inputKind = JSON5Service.detect(initialInput)
    }
    @Published var outputText: String = ""
    @Published var errorMessage: String?
    @Published var isValid: Bool = true

    /// Format detected from the current input (nil = unknown / invalid)
    @Published private(set) var inputKind: JSONInputKind?

    // Validation summary for the success screen
    @Published var validationHeadline: String = ""
    @Published var validationDetail: String?

    // Formatting options
    @Published var indentSize: Int = 2
    @Published var sortedKeys: Bool = false

    // MARK: - Computed Properties

    var hasInput: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasOutput: Bool {
        !outputText.isEmpty
    }

    var inputLineCount: Int {
        hasInput ? inputText.components(separatedBy: .newlines).count : 0
    }

    // MARK: - Actions

    /// Format the input JSON
    func format() {
        guard hasInput else {
            outputText = ""
            errorMessage = nil
            isValid = true
            return
        }

        do {
            outputText = try JSONService.format(inputText, indent: indentSize, sortedKeys: sortedKeys)
            errorMessage = nil
            isValid = true
        } catch {
            let result = JSONService.validate(inputText)
            outputText = ""
            errorMessage = formatErrorMessage(result)
            isValid = false
        }
    }

    /// Minify the input JSON
    func minify() {
        guard hasInput else {
            outputText = ""
            errorMessage = nil
            isValid = true
            return
        }

        do {
            outputText = try JSONService.minify(inputText)
            errorMessage = nil
            isValid = true
        } catch {
            let result = JSONService.validate(inputText)
            outputText = ""
            errorMessage = formatErrorMessage(result)
            isValid = false
        }
    }

    /// Validate the input (JSON / JSON5 / JSONL aware)
    func validate() {
        guard hasInput else {
            outputText = ""
            errorMessage = nil
            isValid = true
            validationHeadline = ""
            validationDetail = nil
            return
        }

        let result = JSONService.validate(inputText)
        isValid = result.isValid

        if result.isValid {
            outputText = "✓ Valid"
            errorMessage = nil
            validationHeadline = "Valid \(result.kind?.rawValue ?? "JSON")"
            validationDetail = result.notes
        } else {
            outputText = ""
            errorMessage = formatErrorMessage(result)
            validationHeadline = ""
            validationDetail = nil
        }
    }

    /// Build a single parseable JSON text for the tree view
    /// (JSONL is presented as an array of its documents)
    func prepareTree() {
        guard hasInput else {
            outputText = ""
            errorMessage = nil
            isValid = true
            return
        }

        do {
            outputText = try JSONService.treeSource(inputText)
            errorMessage = nil
            isValid = true
        } catch {
            let result = JSONService.validate(inputText)
            outputText = ""
            errorMessage = formatErrorMessage(result)
            isValid = false
        }
    }

    /// Convert JSON to JSONL
    func toJSONL() {
        guard hasInput else {
            outputText = ""
            errorMessage = nil
            isValid = true
            return
        }

        do {
            outputText = try JSONService.toJSONL(inputText)
            errorMessage = nil
            isValid = true
        } catch {
            let result = JSONService.validate(inputText)
            outputText = ""
            if result.isValid {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = formatErrorMessage(result)
            }
            isValid = false
        }
    }

    /// Convert JSONL to JSON array
    func fromJSONL() {
        guard hasInput else {
            outputText = ""
            errorMessage = nil
            isValid = true
            return
        }

        do {
            outputText = try JSONService.fromJSONL(inputText)
            errorMessage = nil
            isValid = true
        } catch {
            outputText = ""
            errorMessage = error.localizedDescription
            isValid = false
        }
    }

    /// Convert JSON to YAML
    func toYAML() {
        guard hasInput else {
            outputText = ""
            errorMessage = nil
            isValid = true
            return
        }

        do {
            outputText = try JSONService.toYAML(inputText)
            errorMessage = nil
            isValid = true
        } catch {
            let result = JSONService.validate(inputText)
            outputText = ""
            if result.isValid {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = formatErrorMessage(result)
            }
            isValid = false
        }
    }

    /// Convert YAML to Properties
    func yamlToProperties() {
        guard hasInput else {
            outputText = ""
            errorMessage = nil
            isValid = true
            return
        }

        do {
            outputText = try JSONService.yamlToProperties(inputText)
            errorMessage = nil
            isValid = true
        } catch {
            outputText = ""
            errorMessage = error.localizedDescription
            isValid = false
        }
    }

    /// Convert Properties to YAML
    func propertiesToYAML() {
        guard hasInput else {
            outputText = ""
            errorMessage = nil
            isValid = true
            return
        }

        do {
            outputText = try JSONService.propertiesToYAML(inputText)
            errorMessage = nil
            isValid = true
        } catch {
            outputText = ""
            errorMessage = error.localizedDescription
            isValid = false
        }
    }

    /// Copy output to clipboard
    func copyOutput() {
        guard hasOutput else { return }
        ClipboardService.copy(outputText)
    }

    /// Paste from clipboard to input
    func pasteFromClipboard() {
        if let text = ClipboardService.paste() {
            inputText = text
        }
    }

    /// Clear all fields
    func clear() {
        inputText = ""          // didSet recomputes inputKind
        outputText = ""
        errorMessage = nil
        isValid = true
        validationHeadline = ""
        validationDetail = nil
    }

    // MARK: - Helpers

    private func formatErrorMessage(_ result: ValidationResult) -> String {
        var message = result.errorMessage ?? "Unknown error"

        // Show the problematic line if available
        if let line = result.line, line > 0 {
            let lines = inputText.components(separatedBy: .newlines)
            if line <= lines.count {
                let errorLine = lines[line - 1]
                message += "\n\nLine \(line): \(errorLine)"

                // Show pointer to error column
                if let column = result.column, column > 0, column <= errorLine.count + 1 {
                    let pointer = String(repeating: " ", count: column - 1) + "^"
                    message += "\n         \(pointer)"
                }
            }
        }

        return message
    }
}
