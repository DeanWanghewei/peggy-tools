//
//  AppDelegate.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 显示在 Dock 中，支持 Spotlight 搜索打开
        NSApp.setActivationPolicy(.regular)

        // Preload window controllers
        _ = MainWindowController.shared
        _ = SettingsWindowController.shared

        // 启动时显示主窗口
        MainWindowController.shared.showWindow()

        // `--screenshot <path>`：离屏渲染主窗口内容为 PNG 后退出（用于生成 README 截图）
        maybeCaptureScreenshotAndExit()
    }

    /// 配合 `--demo` / `--demo-tree` 使用：等待视图完成首次布局与格式化，
    /// 再用 cacheDisplay 离屏导出，不依赖窗口是否可见
    private func maybeCaptureScreenshotAndExit() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--screenshot"),
              index + 1 < arguments.count else { return }
        let path = arguments[index + 1]

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.captureMainWindow(to: path)
            NSApp.terminate(nil)
        }
    }

    private func captureMainWindow(to path: String) {
        guard let window = MainWindowController.shared.window,
              let contentView = window.contentView else { return }

        let rect = contentView.bounds
        let scale: Int = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(rect.width) * scale,
            pixelsHigh: Int(rect.height) * scale,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return }
        rep.size = rect.size
        contentView.cacheDisplay(in: rect, to: rep)

        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }

    func applicationShouldHandleReopen(_ sender: Bool) -> Bool {
        // 当应用被重新激活时（如从 Dock 点击或 Spotlight 打开)，显示主窗口
        // 只有窗口不可见时才显示
        if MainWindowController.shared.window?.isVisible == false {
            MainWindowController.shared.showWindow()
        }
        return false // 不拦截事件，允许正常交互
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup event monitor
        if let monitor = AppState.shared.eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = AppState.shared.localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Main Window Controller

class MainWindowController: NSWindowController {
    static let shared = MainWindowController()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Peggy Tools"
        window.isMovableByWindowBackground = true
        window.center()
        window.setFrameAutosaveName("PeggyToolsMainWindow")
        window.level = .normal

        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView

        self.init(window: window)
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideWindow() {
        window?.orderOut(nil)
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.isMovableByWindowBackground = true
        window.center()
        window.setFrameAutosaveName("PeggyToolsSettingsWindow")

        let contentView = SettingsView()
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView

        self.init(window: window)
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
