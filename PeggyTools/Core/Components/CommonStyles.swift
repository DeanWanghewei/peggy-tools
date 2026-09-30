//
//  CommonStyles.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import SwiftUI

// MARK: - View Modifiers

/// 等宽字体文本样式
struct MonospacedTextModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(.body, design: .monospaced))
    }
}

/// 面板边框样式
struct PanelBorderModifier: ViewModifier {
    var isError: Bool = false

    func body(content: Content) -> some View {
        content.border(isError ? Color.red.opacity(0.3) : Color.secondary.opacity(0.2))
    }
}

// MARK: - View Extensions

extension View {
    func monospacedText() -> some View {
        modifier(MonospacedTextModifier())
    }

    func panelBorder(isError: Bool = false) -> some View {
        modifier(PanelBorderModifier(isError: isError))
    }
}

// MARK: - Reusable Components

/// 小型彩色徽章（用于状态/格式提示）
struct TextBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
            .help(text)
    }
}

/// 输入面板组件
struct InputPanel: View {
    let title: String
    @Binding var text: String
    /// 面板标题旁的状态徽章（如输入格式）
    var badge: (text: String, color: Color)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PanelHeader(title: title, badge: badge) {
                if let pasteText = ClipboardService.paste() {
                    text = pasteText
                }
            }
            TextEditor(text: $text)
                .monospacedText()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .panelBorder()
        }
    }
}

/// 输出面板组件
struct OutputPanel: View {
    let title: String
    let text: String
    let isError: Bool
    var onCopy: (() -> Void)?
    var badge: (text: String, color: Color)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PanelHeader(title: title, badge: badge, showAction: !text.isEmpty, actionTitle: "Copy", action: onCopy)

            ScrollView {
                Text(text)
                    .monospacedText()
                    .foregroundColor(isError ? .red : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .panelBorder(isError: isError)
        }
    }
}

/// 面板头部组件
struct PanelHeader: View {
    let title: String
    var badge: (text: String, color: Color)? = nil
    var showAction: Bool = true
    var actionTitle: String = "Paste"
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            if let badge = badge {
                TextBadge(text: badge.text, color: badge.color)
            }

            Spacer()

            if showAction, let action = action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.accentColor)
            }
        }
    }
}

/// 工具栏按钮组件
struct ToolbarButton: View {
    let title: String
    let systemImage: String?
    let isPrimary: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let image = systemImage {
                    Image(systemName: image)
                }
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
        }
        .if(isPrimary) { view in
            view.buttonStyle(.borderedProminent)
        } else: { view in
            view.buttonStyle(.plain)
        }
        .foregroundColor(buttonColor)
        .disabled(isDisabled)
    }

    private var buttonColor: Color {
        if isDisabled {
            return .secondary
        }
        return isPrimary ? .white : .accentColor
    }
}

// MARK: - Conditional View Modifier Extension

extension View {
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        then trueModifier: (Self) -> TrueContent,
        else falseModifier: (Self) -> FalseContent
    ) -> some View {
        if condition {
            trueModifier(self)
        } else {
            falseModifier(self)
        }
    }
}

/// 分段选择器组件
struct SegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let titleForOption: (T) -> String
    var disabled: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button(action: { selection = option }) {
                    Text(titleForOption(option))
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(selection == option ? Color.accentColor : Color.clear)
                        .foregroundColor(selection == option ? .white : .primary)
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        }
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}
