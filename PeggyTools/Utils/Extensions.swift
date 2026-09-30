//
//  Extensions.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import Foundation
import AppKit

extension String {
    /// Check if string is valid JSON
    var isValidJSON: Bool {
        guard let data = self.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    /// Check if string looks like JSONL format
    var isJSONL: Bool {
        let lines = self.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return false }

        return lines.allSatisfy { line in
            line.trimmingCharacters(in: .whitespaces).isValidJSON
        }
    }

    /// Trim and normalize whitespace
    var normalized: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get indentation level (number of leading spaces / 2)
    var indentationLevel: Int {
        var count = 0
        for char in self {
            if char == " " {
                count += 1
            } else {
                break
            }
        }
        return count / 2
    }
}

extension NSPasteboard.PasteboardType {
    static let json = NSPasteboard.PasteboardType("public.json")
}
