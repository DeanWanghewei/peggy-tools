//
//  JSONToolsView.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import SwiftUI

/// Output mode for JSON tools
enum JSONOutputMode: String, CaseIterable {
    case formatted = "Formatted"
    case minified = "Minified"
    case validated = "Validate"
    case tree = "Tree View"
}

/// Unified JSON tools view with format, minify, validate, and tree view.
/// Accepts JSON, JSON5 and JSONL input — the format is detected automatically.
struct JSONToolsView: View {
    @StateObject private var viewModel = JSONFormatterViewModel()
    @State private var outputMode: JSONOutputMode = .formatted

    /// `--demo` / `--demo-tree`：预填演示数据（见 JSONFormatterViewModel.demoSample），
    /// `--demo-tree` 同时以树形视图启动，用于截图与功能演示
    init() {
        if DemoMode.current == .tree {
            _outputMode = State(initialValue: .tree)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // 顶部工具栏
            ToolbarView(
                outputMode: $outputMode,
                viewModel: viewModel,
                onModeChange: { mode in
                    performAction(for: mode)
                }
            )

            // 主内容区域
            HStack(spacing: 12) {
                // 输入面板（带格式识别徽章）
                InputPanel(title: "Input", text: $viewModel.inputText, badge: inputBadge)
                    .frame(maxWidth: .infinity)

                // 输出面板 - 根据模式显示不同内容
                outputPanel
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)

            // 状态栏
            statsBar
        }
        .padding(.bottom, 8)
        .onReceive(viewModel.$inputText) { _ in
            if viewModel.hasInput {
                performAction(for: outputMode)
            }
        }
        .onReceive(viewModel.$indentSize) { _ in
            if viewModel.hasInput && outputMode == .formatted {
                viewModel.format()
            }
        }
        .onReceive(viewModel.$sortedKeys) { _ in
            if viewModel.hasInput && outputMode == .formatted {
                viewModel.format()
            }
        }
    }

    // MARK: - Input Badge

    private var inputBadge: (text: String, color: Color)? {
        guard let kind = viewModel.inputKind else { return nil }
        return (kind.rawValue, Self.badgeColor(for: kind))
    }

    static func badgeColor(for kind: JSONInputKind) -> Color {
        switch kind {
        case .json: return .green
        case .json5: return .orange
        case .jsonl: return .blue
        }
    }

    // MARK: - Output Panel

    @ViewBuilder
    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Output")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if viewModel.inputKind == .json5 && outputMode == .formatted {
                    TextBadge(text: "comments removed", color: .orange)
                }
                if viewModel.inputKind == .jsonl && outputMode == .formatted {
                    TextBadge(text: "one document per block", color: .blue)
                }

                Spacer()

                if viewModel.hasOutput && outputMode != .validated {
                    Button("Copy") {
                        viewModel.copyOutput()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }

            if let error = viewModel.errorMessage {
                // 错误信息
                ScrollView {
                    Text(error)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(Color.red.opacity(0.3))
            } else if viewModel.hasOutput {
                switch outputMode {
                case .formatted:
                    // 格式化输出 - 带语法高亮
                    ScrollView {
                        Text(attributedJSON(viewModel.outputText))
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.secondary.opacity(0.2))

                case .minified:
                    // 压缩输出
                    ScrollView {
                        Text(viewModel.outputText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.secondary.opacity(0.2))

                case .validated:
                    // 验证成功
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)

                        Text(viewModel.validationHeadline.isEmpty ? "Valid JSON" : viewModel.validationHeadline)
                            .font(.headline)
                            .foregroundColor(.green)

                        if let detail = viewModel.validationDetail {
                            Text(detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.green.opacity(0.05))

                case .tree:
                    // 树形视图（JSONL 输入以数组形式展示）
                    JSONTreeView(json: viewModel.outputText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .border(Color.secondary.opacity(0.2))
                }
            } else {
                // 空输入时的引导
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.6))

                    Text("Paste or type JSON / JSON5 / JSONL")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Format is detected automatically · results update as you type")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(Color.secondary.opacity(0.2))
            }
        }
    }

    // MARK: - Stats Bar

    @ViewBuilder
    private var statsBar: some View {
        if viewModel.hasInput {
            HStack(spacing: 12) {
                if let kind = viewModel.inputKind {
                    TextBadge(text: kind.rawValue, color: Self.badgeColor(for: kind))
                } else {
                    TextBadge(text: "Not valid yet", color: .red)
                }

                Text("\(viewModel.inputText.count) chars · \(viewModel.inputLineCount) lines")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if outputMode == .minified && viewModel.hasOutput {
                    Text("\(viewModel.inputText.count) → \(viewModel.outputText.count) chars")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func performAction(for mode: JSONOutputMode) {
        switch mode {
        case .formatted:
            viewModel.format()
        case .minified:
            viewModel.minify()
        case .validated:
            viewModel.validate()
        case .tree:
            viewModel.prepareTree()
        }
    }

    // MARK: - Syntax Highlighting

    private func attributedJSON(_ json: String) -> AttributedString {
        var result = AttributedString(json)

        let patterns: [(String, Color)] = [
            ("\"[^\"]*\"(?=\\s*:)", .purple),        // Keys
            ("\"[^\"]*\"(?=\\s*[,\\]\\}])", .green), // String values
            ("\\b-?\\d+\\.?\\d*\\b", .blue),         // Numbers
            ("\\b(true|false)\\b", .orange),         // Booleans
            ("\\bnull\\b", .gray),                   // Null
        ]

        for (pattern, color) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(json.startIndex..., in: json)
                for match in regex.matches(in: json, options: [], range: range).reversed() {
                    if let swiftRange = Range(match.range, in: json),
                       let attrRange = Range(swiftRange, in: result) {
                        result[attrRange].foregroundColor = color
                    }
                }
            }
        }

        return result
    }
}

// MARK: - Demo Mode

private enum DemoMode {
    case none, formatted, tree

    static var current: DemoMode {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--demo-tree") { return .tree }
        if arguments.contains("--demo") { return .formatted }
        return .none
    }
}

// MARK: - Toolbar View

struct ToolbarView: View {
    @Binding var outputMode: JSONOutputMode
    @ObservedObject var viewModel: JSONFormatterViewModel
    var onModeChange: (JSONOutputMode) -> Void

    var body: some View {
        HStack {
            // 模式选择器
            SegmentedPicker(
                selection: $outputMode,
                options: JSONOutputMode.allCases,
                titleForOption: { $0.rawValue },
                disabled: !viewModel.hasInput
            )
            .frame(width: 280)
            .simultaneousGesture(TapGesture().onEnded {
                onModeChange(outputMode)
            })

            Spacer()

            // 格式化选项
            if outputMode == .formatted {
                HStack(spacing: 8) {
                    Text("Indent:")
                        .font(.caption)

                    Picker("", selection: $viewModel.indentSize) {
                        Text("2").tag(2)
                        Text("4").tag(4)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 50)

                    Toggle("Sort", isOn: $viewModel.sortedKeys)
                        .font(.caption)
                }
            }

            // 清除按钮
            ToolbarButton(
                title: "Clear",
                systemImage: nil,
                isPrimary: false,
                action: { viewModel.clear() }
            )
        }
        .padding(.horizontal)
    }
}

#Preview {
    JSONToolsView()
        .frame(width: 700, height: 500)
}
