//
//  AppBootstrap.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents
import Cocoa

/// Starts the app's services once, in the order that keeps settings from loading before the legacy migration.
/// - Note: Intents can launch the app before `applicationDidFinishLaunching` finishes, so every entry point calls `runIfNeeded()`.
@MainActor
final class AppBootstrap {
    
    private var hasRun: Bool = false
    private var menuBarController: MenuBarController?
    private var floatingWindowController: FloatingWindowController?
    
    // MARK: - Init
    private init() {}
    static let shared: AppBootstrap = AppBootstrap()
    
    // MARK: - Run
    func runIfNeeded() {
        guard hasRun == false else { return }
        hasRun = true
        Log.info("📲 AppBootstrap runIfNeeded")
        
        ConfigManager.shared.synchronouslyUpdateConfig()
        // Must run before any settings are first read, because their managers load their values when created.
        Storage.migrateLegacyKeys()
        setupFirebaseAnalytics()
        setupTelemetryDeckAnalytics()
        setupMainMenu()
        
        PositiveApp.trackLaunch()
        WidgetRefresher.shared.start()
        SensorMonitor.shared.start()
        AppThemeManager.shared.applyGlassTint()
        UpdateChecker.shared.start()
        
        let menuBarController: MenuBarController = MenuBarController()
        menuBarController.setup()
        self.menuBarController = menuBarController
        
        let floatingWindowController: FloatingWindowController = FloatingWindowController()
        floatingWindowController.contextMenuProvider = { [weak menuBarController] in
            return menuBarController?.makeContextMenu()
        }
        floatingWindowController.setup()
        self.floatingWindowController = floatingWindowController
        
        AppShortcuts.updateAppShortcutParameters()
    }
    
    // MARK: - Setup
    private func setupFirebaseAnalytics() {
        Analytics.shared.add(bridge: FirebaseAnalyticsBridge(trackingIDs: []))
    }
    
    private func setupTelemetryDeckAnalytics() {
        #if DEBUG
            guard
                let trackingIDs: [String] = ConfigManager.shared.config.analytics?.services?.telemetryDeck?.trackingIDs?.development,
                trackingIDs.isEmpty == false
            else { return }
        #else
            guard
                let trackingIDs: [String] = ConfigManager.shared.config.analytics?.services?.telemetryDeck?.trackingIDs?.production,
                trackingIDs.isEmpty == false
            else { return }
        #endif
        
        Analytics.shared.add(bridge: TelemetryDeckAnalyticsBridge(trackingIDs: trackingIDs))
    }
    
    /// A Dock-less app has no menu bar of its own, but text fields and windows still need these key equivalents.
    private func setupMainMenu() {
        let mainMenu: NSMenu = NSMenu()
        
        let appMenuItem: NSMenuItem = NSMenuItem()
        let appMenu: NSMenu = NSMenu(title: "Fanny")
        let quitTitle: String = String(localized: "Quit Fanny", comment: "Main menu: quit menu item (keep app name)")
        appMenu.addItem(NSMenuItem(title: quitTitle, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        let editMenuItem: NSMenuItem = NSMenuItem()
        let editMenu: NSMenu = NSMenu(title: String(localized: "Edit", comment: "Main menu: edit menu title"))
        editMenu.addItem(NSMenuItem(title: String(localized: "Undo", comment: "Main menu: undo menu item"), action: Selector(("undo:")), keyEquivalent: "z"))
        let redoItem: NSMenuItem = NSMenuItem(title: String(localized: "Redo", comment: "Main menu: redo menu item"), action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: String(localized: "Cut", comment: "Main menu: cut menu item"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: String(localized: "Copy", comment: "Main menu: copy menu item"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: String(localized: "Paste", comment: "Main menu: paste menu item"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: String(localized: "Select All", comment: "Main menu: select all menu item"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        let windowMenuItem: NSMenuItem = NSMenuItem()
        let windowMenu: NSMenu = NSMenu(title: String(localized: "Window", comment: "Main menu: window menu title"))
        windowMenu.addItem(NSMenuItem(title: String(localized: "Minimize", comment: "Main menu: minimize window menu item"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: String(localized: "Close", comment: "Main menu: close window menu item"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
        NSApplication.shared.windowsMenu = windowMenu
    }
}
