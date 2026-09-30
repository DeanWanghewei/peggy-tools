//
//  JSONConverterDefinition.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import SwiftUI

/// 「Convert」工具：JSON / JSONL / YAML / Properties 互转
struct JSONConverterDefinition: Tool {
    let id = "json-converter"
    let name = "Convert"
    let description = "Convert between JSON, YAML, JSONL"
    let systemImage = "arrow.left.arrow.right"
    let category: ToolCategory = .json

    func makeView() -> AnyView {
        AnyView(JSONConverterView())
    }
}
