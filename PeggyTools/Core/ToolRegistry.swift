//
//  ToolRegistry.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import Foundation

/// 工具注册表：应用内所有工具的唯一登记处。
///
/// 新增工具只需在 `allTools` 追加一行，主界面 Tab、
/// 内容区会自动渲染，无需改动任何其他文件：
///
///     static let allTools: [any Tool] = [
///         JSONToolsDefinition(),
///         JSONConverterDefinition(),
///         MyNewToolDefinition(),   // ← 新工具
///     ]
enum ToolRegistry {
    /// 已注册的全部工具（顺序即 Tab 显示顺序）
    static let allTools: [any Tool] = [
        JSONToolsDefinition(),
        JSONConverterDefinition(),
    ]

    /// 按 id 查找工具
    static func tool(withID id: String) -> (any Tool)? {
        allTools.first { $0.id == id }
    }

    /// 按分类筛选工具
    static func tools(in category: ToolCategory) -> [any Tool] {
        allTools.filter { $0.category == category }
    }
}
