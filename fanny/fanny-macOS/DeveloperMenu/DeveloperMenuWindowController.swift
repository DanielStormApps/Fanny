//
//  DeveloperMenuWindowController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/25/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

/// Owns the Developer Menu window, laid out like the Settings window, with logs and raw sensor readings for debugging.
final class DeveloperMenuWindowController: NSWindowController {
    
    private static let frameAutosaveName: String = "DeveloperMenuWindow"
    private static let toolbarIdentifier: NSToolbar.Identifier = NSToolbar.Identifier("DeveloperMenuToolbar")
    static let windowTitle: String = String(localized: "Developer Menu", comment: "Developer Menu: window title and the name VoiceOver reads for its sidebar.")
    /// Moves the first open right and down from center, so it doesn't land exactly on top of a Settings window that hasn't been moved.
    private static let defaultCenterOffset: CGFloat = 40.0
    
    // MARK: - Init
    static let shared: DeveloperMenuWindowController = DeveloperMenuWindowController()
    
    private init() {
        super.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Show
    /// Brings the window forward, building it the first time.
    func show() {
        if window == nil {
            window = makeWindow()
            Log.info("🛠️ show -> built developer menu window")
        }
        
        NSApplication.shared.activate()
        window?.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - Window
    private func makeWindow() -> NSWindow {
        let splitViewController: DeveloperMenuSplitViewController = DeveloperMenuSplitViewController()
        
        let window: NSWindow = NSWindow(contentViewController: splitViewController)
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unified
        window.title = DeveloperMenuWindowController.windowTitle
        window.contentMinSize = SettingsWindowController.minimumContentSize
        window.setContentSize(SettingsWindowController.defaultContentSize)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        
        let toolbar: NSToolbar = NSToolbar(identifier: DeveloperMenuWindowController.toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        
        window.center()
        DeveloperMenuWindowController.offsetFromCenter(window)
        // Restores a saved size and position, which then wins over the default.
        window.setFrameAutosaveName(DeveloperMenuWindowController.frameAutosaveName)
        AppThemeManager.shared.register(window)
        
        return window
    }
    
    /// Keeps the offset window on screen, so a short display never pushes its bottom edge off.
    private static func offsetFromCenter(_ window: NSWindow) {
        var frame: CGRect = window.frame
        frame.origin.x = frame.origin.x + DeveloperMenuWindowController.defaultCenterOffset
        frame.origin.y = frame.origin.y - DeveloperMenuWindowController.defaultCenterOffset
        
        if let visibleFrame: CGRect = (window.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - frame.width)
            frame.origin.y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - frame.height)
        }
        
        window.setFrameOrigin(frame.origin)
    }
}

// MARK: - NSToolbarDelegate
extension DeveloperMenuWindowController: NSToolbarDelegate {
    
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
