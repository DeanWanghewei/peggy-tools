//
//  PeggyToolsApp.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import SwiftUI

@main
struct PeggyToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra("Peggy Tools", systemImage: "wrench.and.screwdriver") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)
    }
}

// MARK: - App State

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var showMainWindow: Bool = false
    @Published var shortcutKey: String = "⌘⇧J"
    @Published var shortcutModifiers: NSEvent.ModifierFlags = [.command, .shift]
    @Published var shortcutKeyCode: UInt16 = 38
    @Published var hasAccessibilityPermission: Bool = false
    @Published var shortcutConflict: String?

    var eventMonitor: Any?
    var localMonitor: Any?

    private init() {
        loadSettings()
        checkAccessibilityPermission()
    }

    func loadSettings() {
        if let s = UserDefaults.standard.string(forKey: "shortcutKey") {
            shortcutKey = s
        }
        if let m = UserDefaults.standard.value(forKey: "shortcutModifiers") as? UInt {
            shortcutModifiers = NSEvent.ModifierFlags(rawValue: m)
        }
        if let k = UserDefaults.standard.value(forKey: "shortcutKeyCode") as? UInt16 {
            shortcutKeyCode = k
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(shortcutKey, forKey: "shortcutKey")
        UserDefaults.standard.set(shortcutModifiers.rawValue, forKey: "shortcutModifiers")
        UserDefaults.standard.set(shortcutKeyCode, forKey: "shortcutKeyCode")
        checkShortcutConflict()
        setupGlobalShortcut()
    }

    func checkAccessibilityPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(opts as CFDictionary)
        if hasAccessibilityPermission {
            setupGlobalShortcut()
        }
    }

    func requestAccessibilityPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }

    func checkShortcutConflict() {
        if shortcutModifiers == [.command, .shift] {
            let keys: [UInt16: String] = [20: "Screenshot (⌘⇧3)", 21: "Screenshot (⌘⇧4)", 23: "Screenshot (⌘⇧5)"]
            if let c = keys[shortcutKeyCode] {
                shortcutConflict = "⚠️ Conflicts: \(c)"
                return
            }
        }
        if shortcutModifiers == [.command] {
            let keys: [UInt16: String] = [12: "Quit (⌘Q)", 13: "Close (⌘W)", 0: "Select All (⌘A)", 1: "Save (⌘S)", 3: "Find (⌘F)"]
            if let c = keys[shortcutKeyCode] {
                shortcutConflict = "⚠️ Conflicts: \(c)"
                return
            }
        }
        shortcutConflict = nil
    }

    func setupGlobalShortcut() {
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        guard hasAccessibilityPermission else { return }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true { return nil }
            return event
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard mods == shortcutModifiers && event.keyCode == shortcutKeyCode else { return false }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showMainWindow.toggle()
            if self.showMainWindow {
                MainWindowController.shared.showWindow()
            } else {
                MainWindowController.shared.hideWindow()
            }
        }
        return true
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    var body: some View {
        Button("Open Peggy Tools") {
            AppState.shared.showMainWindow = true
            MainWindowController.shared.showWindow()
        }
        Divider()
        Button("Settings...") {
            SettingsWindowController.shared.showWindow()
        }
        Divider()
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
