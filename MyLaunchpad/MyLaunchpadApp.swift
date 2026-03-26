//
//  MyLaunchpadApp.swift
//  MyLaunchpad
//

import SwiftUI
import AppKit
import Carbon
import ServiceManagement

extension Notification.Name {
    static let toggleLaunchpad = Notification.Name("ToggleLaunchpad")
    static let hideLaunchpad = Notification.Name("HideLaunchpad")
    static let launchpadWillHide = Notification.Name("LaunchpadWillHide")
    static let launchpadWillShow = Notification.Name("LaunchpadWillShow")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?
    private var mainWindow: NSWindow?
    private var hasConfiguredWindow = false
    private var isHiding = false

    private static let hotKeySignature: OSType = 0x4D4C5044
    private static let hotKeyIdentifier: UInt32 = 1
    private static let hotKeyHandler: EventHandlerUPP = { _, event, _ in
        guard let event else {
            return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard
            status == noErr,
            hotKeyID.signature == hotKeySignature,
            hotKeyID.id == hotKeyIdentifier
        else {
            return noErr
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .toggleLaunchpad, object: nil)
        }

        return noErr
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerHotKey()
        DispatchQueue.main.async {
            NSApp.hide(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotKey()
    }

    /// Signal source B: Dock icon click
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        toggleLaunchpad()
        return false
    }

    /// Signal source C: auto-hide on focus loss
    func applicationDidResignActive(_ notification: Notification) {
        guard !NSApp.isHidden else {
            return
        }

        NotificationCenter.default.post(name: .hideLaunchpad, object: nil)
    }

    // MARK: - Unified toggle

    func toggleLaunchpad() {
        guard let window = resolvedWindow else {
            return
        }

        if !NSApp.isHidden && window.isVisible && window.alphaValue > 0.01 && !isHiding {
            NotificationCenter.default.post(name: .hideLaunchpad, object: nil)
        } else if !isHiding {
            showWindow(window)
        }
    }

    func hideWindowIfNeeded() {
        guard let window = resolvedWindow, window.isVisible else {
            return
        }

        hideWindow(window)
    }

    // MARK: - Launch at Login

    func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to toggle login item: \(error)")
        }
    }

    // MARK: - Window management

    func captureAndConfigureWindowIfNeeded() {
        DispatchQueue.main.async { [self] in
            guard let window = NSApplication.shared.windows.first(where: {
                $0.className != "NSStatusBarWindow" && $0.className != "_NSPopoverWindow"
            }) else {
                return
            }

            configureWindowIfNeeded(window)
        }
    }

    private func configureWindowIfNeeded(_ window: NSWindow) {
        mainWindow = window

        guard !hasConfiguredWindow else {
            return
        }

        hasConfiguredWindow = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.borderless, .fullSizeContentView]
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle, 
            .fullScreenAuxiliary
        ]

        resizeWindowToMouseScreen(window)
        window.alphaValue = 0
        NSApp.hide(nil)
    }

    private var resolvedWindow: NSWindow? {
        if let mainWindow {
            return mainWindow
        }

        guard let window = NSApplication.shared.windows.first(where: {
            $0.className != "NSStatusBarWindow" && $0.className != "_NSPopoverWindow"
        }) else {
            return nil
        }

        configureWindowIfNeeded(window)
        return window
    }

    private func resizeWindowToMouseScreen(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main

        if let screenFrame = targetScreen?.frame {
            window.setFrame(screenFrame, display: true)
        }
    }

    private func showWindow(_ window: NSWindow) {
        isHiding = false
        resizeWindowToMouseScreen(window)
        window.alphaValue = 1

        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        NotificationCenter.default.post(name: .launchpadWillShow, object: nil)
    }

    private func hideWindow(_ window: NSWindow) {
        isHiding = true
        NotificationCenter.default.post(name: .launchpadWillHide, object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            window.alphaValue = 0
            NSApp.hide(nil)
            isHiding = false
        }
    }

    // MARK: - Hotkey

    private func registerHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.hotKeyHandler,
            1,
            &eventType,
            nil,
            &hotKeyHandlerRef
        )

        let hotKeyID = EventHotKeyID(
            signature: Self.hotKeySignature,
            id: Self.hotKeyIdentifier
        )

        let modifiers = UInt32(optionKey)
        RegisterEventHotKey(
            UInt32(kVK_Space),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let hotKeyHandlerRef {
            RemoveEventHandler(hotKeyHandlerRef)
            self.hotKeyHandlerRef = nil
        }
    }
}

@main
struct MyLaunchpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appManager = AppManager()

    var body: some Scene {
        WindowGroup {
            ContentView(appManager: appManager)
                .onAppear {
                    appDelegate.captureAndConfigureWindowIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: .toggleLaunchpad)) { _ in
                    appDelegate.toggleLaunchpad()
                }
                .onReceive(NotificationCenter.default.publisher(for: .hideLaunchpad)) { _ in
                    appDelegate.hideWindowIfNeeded()
                }
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView(appManager: appManager)
        }

        MenuBarExtra("MyLaunchpad", systemImage: "square.grid.3x3") {
            Button("偏好设置...") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            Divider()
            Button(SMAppService.mainApp.status == .enabled ? "✓ 取消开机自启动" : "开机自启动") {
                appDelegate.toggleLaunchAtLogin()
            }
            Divider()
            Button("退出 MyLaunchpad") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
