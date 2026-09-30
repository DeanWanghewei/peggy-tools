//
//  JSONToolsDefinition.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import SwiftUI

/// 「JSON Tools」工具：格式化 / 压缩 / 校验 / 树形浏览
struct JSONToolsDefinition: Tool {
    let id = "json-tools"
    let name = "JSON Tools"
    let description = "Format, minify, validate JSON / JSON5 / JSONL"
    let systemImage = "curlybraces"
    let category: ToolCategory = .json

    func makeView() -> AnyView {
        AnyView(JSONToolsView())
    }
}
