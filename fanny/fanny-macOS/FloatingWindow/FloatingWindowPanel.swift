//
//  FloatingWindowPanel.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

/// The borderless panel that floats the readings above other windows without taking focus.
final class FloatingWindowPanel: NSPanel {
    
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    // MARK: - Init
    init(contentSize: CGSize) {
        super.init(contentRect: CGRect(origin: CGPoint.zero, size: contentSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        
        // One level above the Dock, so the window stays visible and grabbable when it is dragged beside or over it.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = NSColor.clear
        hasShadow = true
        title = String(localized: "Fanny Floating Window", comment: "Accessibility title of the floating window (keep app name).")
    }
    
    // MARK: - Frame
    /// Lets the panel sit over the menu bar area instead of being pushed below it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}
