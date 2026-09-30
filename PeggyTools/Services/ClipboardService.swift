//
//  ClipboardService.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import AppKit
import SwiftUI

/// Service for clipboard operations
enum ClipboardService {

    /// Copy text to clipboard
    /// - Parameter text: Text to copy
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Get text from clipboard
    /// - Returns: Clipboard text or nil if empty/not text
    static func paste() -> String? {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
    }

    /// Check if clipboard has text content
    /// - Returns: True if clipboard contains text
    static func hasText() -> Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.types?.contains(.string) ?? false
    }
}
