//
//  SettingsView.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var appState = AppState.shared

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ShortcutSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 450, height: 320)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
            } header: {
                Text("Startup")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // App Info
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.title)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Peggy Tools")
                                .font(.headline)
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Description
                    Text("A lightweight macOS menu bar toolkit for developers. JSON formatting, validation, conversion and more.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    // Copyright
                    VStack(alignment: .leading, spacing: 4) {
                        Text("© 2026 Peggy Tools")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Made with ❤️ for developers")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("About")
            }
        }
        .padding()
    }
}

// MARK: - Shortcut Settings

struct ShortcutSettingsView: View {
    @StateObject private var appState = AppState.shared
    @State private var isRecording: Bool = false
    @State private var currentShortcut: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Permission Status - 只有在没有权限时才显示
            if !appState.hasAccessibilityPermission {
                GroupBox {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Accessibility Permission Required")
                                .font(.headline)

                            Text("Global shortcuts require accessibility permission to work.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Grant Permission") {
                                appState.requestAccessibilityPermission()
                            }
                            .buttonStyle(.link)
                        }

                        Spacer()
                    }
                    .padding(4)
                }
            }

            // Shortcut Configuration
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Toggle Window Shortcut")
                        .font(.headline)

                    Text("Press the keyboard shortcut to open/close Peggy Tools window.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Shortcut:")

                        Spacer()

                        Button(action: {
                            isRecording = true
                            currentShortcut = "Press keys..."
                        }) {
                            Text(currentShortcut.isEmpty ? appState.shortcutKey : currentShortcut)
                                .frame(minWidth: 100)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isRecording ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    // Conflict Warning
                    if let conflict = appState.shortcutConflict {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(conflict)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }

                    if isRecording {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text("Recording... Press your shortcut keys")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Reset to Default") {
                            appState.shortcutKey = "⌘⇧J"
                            appState.shortcutModifiers = [.command, .shift]
                            appState.shortcutKeyCode = 38
                            appState.saveSettings()
                            currentShortcut = appState.shortcutKey
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
                .padding(4)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            currentShortcut = appState.shortcutKey
        }
        .background(
            ShortcutRecorder(
                isRecording: $isRecording,
                shortcutKey: $appState.shortcutKey,
                shortcutModifiers: $appState.shortcutModifiers,
                shortcutKeyCode: $appState.shortcutKeyCode,
                displayText: $currentShortcut
            )
        )
    }
}

// MARK: - Shortcut Recorder

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var shortcutKey: String
    @Binding var shortcutModifiers: NSEvent.ModifierFlags
    @Binding var shortcutKeyCode: UInt16
    @Binding var displayText: String

    func makeNSView(context: Context) -> NSView {
        let view = ShortcutRecorderView()
        view.onShortcutRecorded = { modifiers, keyCode, displayString in
            DispatchQueue.main.async {
                self.shortcutModifiers = modifiers
                self.shortcutKeyCode = keyCode
                self.shortcutKey = displayString
                self.displayText = displayString
                self.isRecording = false
                AppState.shared.saveSettings()
            }
        }
        view.isRecording = isRecording
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ShortcutRecorderView)?.isRecording = isRecording
    }
}

class ShortcutRecorderView: NSView {
    var isRecording: Bool = false {
        didSet {
            if isRecording {
                window?.makeFirstResponder(self)
            }
        }
    }
    var onShortcutRecorded: ((NSEvent.ModifierFlags, UInt16, String) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode

        // Require at least one modifier
        guard !modifiers.isEmpty else { return }

        // Build display string
        var displayString = ""
        if modifiers.contains(.control) { displayString += "⌃" }
        if modifiers.contains(.option) { displayString += "⌥" }
        if modifiers.contains(.shift) { displayString += "⇧" }
        if modifiers.contains(.command) { displayString += "⌘" }

        // Get key character
        if let characters = event.charactersIgnoringModifiers?.uppercased() {
            displayString += characters
        } else {
            let specialKeys: [UInt16: String] = [
                36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
                123: "←", 124: "→", 125: "↓", 126: "↑",
            ]
            displayString += specialKeys[keyCode] ?? "?"
        }

        onShortcutRecorded?(modifiers, keyCode, displayString)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }
}
