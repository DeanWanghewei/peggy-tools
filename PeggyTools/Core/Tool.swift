//
//  Tool.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import Foundation
import SwiftUI

/// 工具协议：每个小工具实现此协议即可接入应用。
///
/// 实现步骤见 README「添加新工具」：在 Features/ 下建目录、
/// 写一个遵守 Tool 的结构体、最后到 ToolRegistry 注册一行。
protocol Tool: Identifiable {
    /// 唯一标识（同时用作 Tab 切换与状态恢复的 key）
    var id: String { get }
    /// 工具名（显示在 Tab 上）
    var name: String { get }
    /// 一句话功能说明
    var description: String { get }
    /// SF Symbol 图标名
    var systemImage: String { get }
    /// 所属分类
    var category: ToolCategory { get }

    /// 工具主界面工厂方法
    func makeView() -> AnyView
}

/// 工具分类（工具数量增多后可按此分组展示）
enum ToolCategory: String, CaseIterable, Identifiable {
    case json = "JSON"
    case encoding = "Encoding"
    case text = "Text"
    case developer = "Developer"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .json: return "curlybraces"
        case .encoding: return "lock.shield"
        case .text: return "textformat"
        case .developer: return "ladybug"
        }
    }
}
