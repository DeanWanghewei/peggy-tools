//
//  ContentView.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import SwiftUI

/// 主窗口：Tab 栏与内容区完全由 ToolRegistry 驱动，新增工具无需改动此文件
struct ContentView: View {
    @State private var selectedToolID: String = ToolRegistry.allTools.first?.id ?? ""

    var body: some View {
        VStack(spacing: 0) {
            // 工具选择器
            ToolTabBar(tools: ToolRegistry.allTools, selection: $selectedToolID)

            Divider()
                .padding(.vertical, 8)

            // 工具内容
            if let tool = ToolRegistry.tool(withID: selectedToolID) {
                tool.makeView()
                    .frame(minHeight: 300)
            } else {
                Text("No tools registered")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
                .padding(.vertical, 4)

            // 底部栏
            FooterView()
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - Tool Tab Bar

struct ToolTabBar: View {
    let tools: [any Tool]
    @Binding var selection: String

    var body: some View {
        // 工具增多后可横向滚动，不会挤爆窗口
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tools, id: \.id) { tool in
                    ToolTabButton(
                        tool: tool,
                        isSelected: selection == tool.id,
                        action: { selection = tool.id }
                    )
                    .frame(minWidth: 110)
                }
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.top, 12)
    }
}

// MARK: - Tool Tab Button

struct ToolTabButton: View {
    let tool: any Tool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 13))
                Text(tool.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Footer View

struct FooterView: View {
    var body: some View {
        HStack {
            Text("Peggy Tools v\(AppVersion.current)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button("Settings") {
                SettingsWindowController.shared.showWindow()
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .font(.caption)

            Text("•")
                .foregroundColor(.secondary)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    ContentView()
        .frame(width: 750, height: 550)
}
