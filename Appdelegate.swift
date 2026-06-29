//
//  Appdelegate.swift
//  macOS_tracker
//
//  Created by Saumil on 09/04/26.
//

import AppKit
import SwiftUI
import ServiceManagement   // ✅ IMPORTANT

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var statusItem: NSStatusItem!
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {

        NSApp.setActivationPolicy(.accessory)

        // ✅ Start your manager
        _ = USBMonitorManager.shared

        // ✅ ADD THIS HERE (Auto start on login)
        registerLoginItem()

        setupMenuBar()
    }

    // ✅ NEW FUNCTION
    private func registerLoginItem() {
        do {
            try SMAppService.mainApp.register()
            print("✅ Auto-start enabled")
        } catch {
            print("❌ Auto-start failed:", error)
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button,
           let image = NSImage(named: "ic_shaligram_logo") {
            image.isTemplate = false
            button.image = image
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openWindow), keyEquivalent: "o"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc func openWindow() {
        if let window = window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            USBMonitorManager.shared.refreshDevices()
            return
        }

        let view = ContentView()
            .environmentObject(USBMonitorManager.shared)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        newWindow.center()
        newWindow.title = "USB Dashboard"
        newWindow.contentView = NSHostingView(rootView: view)
        newWindow.delegate = self

        self.window = newWindow

        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)

        USBMonitorManager.shared.refreshDevices()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
