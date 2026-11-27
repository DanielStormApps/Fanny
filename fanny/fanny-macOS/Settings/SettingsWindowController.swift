//
//  SettingsWindowController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

/// Owns the Settings window, which looks like System Settings.
final class SettingsWindowController: NSWindowController {
    
    private static let frameAutosaveName: String = "SettingsWindow"
    private static let toolbarIdentifier: NSToolbar.Identifier = NSToolbar.Identifier("SettingsToolbar")
    /// Shared with the Developer Menu window, so the two match.
    static let defaultContentSize: CGSize = CGSize(width: 740.0, height: 800.0)
    static let minimumContentSize: CGSize = CGSize(width: 700.0, height: 360.0)
    
    // MARK: - Init
    static let shared: SettingsWindowController = SettingsWindowController()
    
    private init() {
        super.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Show
    /// Brings the window forward, building it the first time.
    /// - Note: The app has no Dock icon, so it has to activate itself for the window to take focus.
    func show() {
        if window == nil {
            window = makeWindow()
            Log.info("🎛️ show -> built settings window")
        }
        
        NSApplication.shared.activate()
        window?.makeKeyAndOrderFront(nil)
    }
    
    /// Brings the window forward on a pane, keeping the sidebar selection in step.
    func show(pane: SettingsPane) {
        show()
        (window?.contentViewController as? SettingsSplitViewController)?.select(pane)
    }
    
    // MARK: - Window
    private func makeWindow() -> NSWindow {
        let splitViewController: SettingsSplitViewController = SettingsSplitViewController()
        splitViewController.settingsDelegate = self
        
        let window: NSWindow = NSWindow(contentViewController: splitViewController)
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.toolbarStyle = .unified
        window.title = splitViewController.currentPane.title
        window.contentMinSize = SettingsWindowController.minimumContentSize
        window.setContentSize(SettingsWindowController.defaultContentSize)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        
        let toolbar: NSToolbar = NSToolbar(identifier: SettingsWindowController.toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        
        window.center()
        window.setFrameAutosaveName(SettingsWindowController.frameAutosaveName)
        AppThemeManager.shared.register(window)
        
        return window
    }
}

// MARK: - SettingsSplitViewControllerDelegate
extension SettingsWindowController: SettingsSplitViewControllerDelegate {
    
    func settingsSplitViewController(_ viewController: SettingsSplitViewController, didShow pane: SettingsPane) {
        window?.title = pane.title
    }
}

// MARK: - NSWindowDelegate
extension SettingsWindowController: NSWindowDelegate {
    
    /// Ending the edit commits a typed but uncommitted value before the window goes away.
    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil)
    }
}

// MARK: - NSToolbarDelegate
extension SettingsWindowController: NSToolbarDelegate {
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [NSToolbarItem.Identifier.sidebarTrackingSeparator]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [NSToolbarItem.Identifier.sidebarTrackingSeparator]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        return nil
    }
}
