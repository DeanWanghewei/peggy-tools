//
//  JSONConverterView.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import SwiftUI

/// Conversion types
enum ConversionType: String, CaseIterable, Identifiable {
    case jsonToJSONL = "JSON → JSONL"
    case jsonlToJSON = "JSONL → JSON"
    case jsonToYAML = "JSON → YAML"
    case yamlToProperties = "YAML → Properties"
    case propertiesToYAML = "Properties → YAML"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .jsonToJSONL:
            return "Convert JSON array to JSON Lines format"
        case .jsonlToJSON:
            return "Convert JSON Lines to JSON array"
        case .jsonToYAML:
            return "Convert JSON to YAML format"
        case .yamlToProperties:
            return "Convert YAML to Java Properties format"
        case .propertiesToYAML:
            return "Convert Java Properties to YAML format"
        }
    }

    var inputLabel: String {
        switch self {
        case .jsonToJSONL, .jsonToYAML: return "JSON"
        case .jsonlToJSON: return "JSONL"
        case .yamlToProperties: return "YAML"
        case .propertiesToYAML: return "Properties"
        }
    }

    var outputLabel: String {
        switch self {
        case .jsonToJSONL: return "JSONL"
        case .jsonlToJSON: return "JSON"
        case .jsonToYAML: return "YAML"
        case .yamlToProperties: return "Properties"
        case .propertiesToYAML: return "YAML"
        }
    }
}

/// JSON conversion view
struct JSONConverterView: View {
    @StateObject private var viewModel = JSONFormatterViewModel()
    @State private var conversionType: ConversionType = .jsonToJSONL

    var body: some View {
        VStack(spacing: 12) {
            // 工具栏
            ConverterToolbar(
                conversionType: $conversionType,
                viewModel: viewModel,
                onConvert: { performConversion() }
            )

            // 输入/输出面板
            HStack(spacing: 12) {
                InputPanel(title: conversionType.inputLabel, text: $viewModel.inputText)
                    .frame(maxWidth: .infinity)

                OutputPanel(
                    title: conversionType.outputLabel,
                    text: viewModel.errorMessage ?? viewModel.outputText,
                    isError: viewModel.errorMessage != nil,
                    onCopy: viewModel.hasOutput ? { viewModel.copyOutput() } : nil
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
        .onReceive(viewModel.$inputText) { _ in
            if viewModel.hasInput {
                performConversion()
            }
        }
    }

    private func performConversion() {
        switch conversionType {
        case .jsonToJSONL:
            viewModel.toJSONL()
        case .jsonlToJSON:
            viewModel.fromJSONL()
        case .jsonToYAML:
            viewModel.toYAML()
        case .yamlToProperties:
            viewModel.yamlToProperties()
        case .propertiesToYAML:
            viewModel.propertiesToYAML()
        }
    }
}

// MARK: - Converter Toolbar

struct ConverterToolbar: View {
    @Binding var conversionType: ConversionType
    @ObservedObject var viewModel: JSONFormatterViewModel
    var onConvert: () -> Void

    var body: some View {
        HStack {
            Text("Convert:")
                .font(.caption)

            Picker("", selection: $conversionType) {
                ForEach(ConversionType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            Text(conversionType.description)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            ToolbarButton(
                title: "Convert",
                systemImage: "arrow.left.arrow.right",
                isPrimary: true,
                isDisabled: !viewModel.hasInput,
                action: onConvert
            )

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
    JSONConverterView()
        .frame(width: 700, height: 500)
}
