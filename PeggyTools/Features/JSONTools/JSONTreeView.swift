//
//  JSONTreeView.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import SwiftUI

// MARK: - JSON Tree View

struct JSONTreeView: View {
    let json: String
    @State private var rootItem: JSONTreeItem?
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search keys or values...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Tree content
            ScrollView {
                if let root = rootItem {
                    JSONTreeItemView(item: root, searchText: searchText, depth: 0)
                        .padding(8)
                } else {
                    Text("Invalid JSON")
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .onAppear {
            parseJSON()
        }
        .onChange(of: json) { _ in
            parseJSON()
        }
    }

    private func parseJSON() {
        guard let data = json.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            rootItem = nil
            return
        }
        rootItem = JSONTreeItem.from(json: jsonObject, key: "Root")
    }
}

// MARK: - JSON Tree Item View

struct JSONTreeItemView: View {
    let item: JSONTreeItem
    let searchText: String
    let depth: Int

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                // Expand/collapse button for objects and arrays
                if item.children != nil && !item.children!.isEmpty {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 16)
                }

                // Key
                if item.key != "Root" {
                    Text(item.key)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.purple)
                    Text(":")
                        .foregroundColor(.secondary)
                }

                // Value preview or type
                valueView
            }
            .background(highlightMatch ? Color.yellow.opacity(0.3) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                if item.children != nil {
                    isExpanded.toggle()
                }
            }

            // Children
            if isExpanded, let children = item.children {
                ForEach(children) { child in
                    JSONTreeItemView(item: child, searchText: searchText, depth: depth + 1)
                        .padding(.leading, 16)
                }
            }
        }
    }

    @ViewBuilder
    private var valueView: some View {
        switch item.type {
        case .object:
            HStack(spacing: 2) {
                Text(isExpanded ? "{" : "{")
                    .foregroundColor(.secondary)
                if !isExpanded {
                    Text("\(item.children?.count ?? 0) keys")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("}")
                        .foregroundColor(.secondary)
                }
            }
        case .array:
            HStack(spacing: 2) {
                Text(isExpanded ? "[" : "[")
                    .foregroundColor(.secondary)
                if !isExpanded {
                    Text("\(item.children?.count ?? 0) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("]")
                        .foregroundColor(.secondary)
                }
            }
        case .string:
            Text("\"\(item.value)\"")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.green)
        case .number:
            Text(item.value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.blue)
        case .bool:
            Text(item.value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.orange)
        case .null:
            Text("null")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.gray)
        }
    }

    private var highlightMatch: Bool {
        guard !searchText.isEmpty else { return false }
        let lowercased = searchText.lowercased()
        return item.key.lowercased().contains(lowercased) ||
               item.value.lowercased().contains(lowercased)
    }
}

// MARK: - JSON Tree Item Model

struct JSONTreeItem: Identifiable {
    let id = UUID()
    let key: String
    let value: String
    let type: JSONType
    let children: [JSONTreeItem]?

    enum JSONType {
        case object, array, string, number, bool, null
    }

    static func from(json: Any, key: String) -> JSONTreeItem {
        if let dict = json as? [String: Any] {
            let children = dict.map { (k, v) in
                JSONTreeItem.from(json: v, key: k)
            }.sorted { $0.key < $1.key }
            return JSONTreeItem(key: key, value: "", type: .object, children: children)
        } else if let array = json as? [Any] {
            let children = array.enumerated().map { (index, item) in
                JSONTreeItem.from(json: item, key: "[\(index)]")
            }
            return JSONTreeItem(key: key, value: "", type: .array, children: children)
        } else if let string = json as? String {
            return JSONTreeItem(key: key, value: string, type: .string, children: nil)
        } else if let number = json as? NSNumber {
            let boolValue = number.boolValue
            if number === NSNumber(value: boolValue) && (number.intValue == 0 || number.intValue == 1) {
                // Check if it's actually a boolean
                if let bool = json as? Bool {
                    return JSONTreeItem(key: key, value: bool ? "true" : "false", type: .bool, children: nil)
                }
            }
            return JSONTreeItem(key: key, value: number.stringValue, type: .number, children: nil)
        } else if let bool = json as? Bool {
            return JSONTreeItem(key: key, value: bool ? "true" : "false", type: .bool, children: nil)
        } else if json is NSNull {
            return JSONTreeItem(key: key, value: "null", type: .null, children: nil)
        }

        return JSONTreeItem(key: key, value: String(describing: json), type: .string, children: nil)
    }
}

#Preview {
    JSONTreeView(json: """
    {
        "name": "John",
        "age": 30,
        "active": true,
        "address": {
            "city": "New York",
            "zip": "10001"
        },
        "hobbies": ["reading", "coding"]
    }
    """)
    .frame(width: 400, height: 400)
}
