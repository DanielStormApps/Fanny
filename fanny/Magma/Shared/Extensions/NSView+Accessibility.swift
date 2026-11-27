//
//  NSView+Accessibility.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppKit

extension NSView {
    
    // MARK: - Accessibility
    /// Hides a decorative view from VoiceOver.
    /// - Note: Controls such as `NSImageView` and `NSTextField` are exposed through their cell, so the cell is hidden too.
    func hideFromAccessibility() {
        setAccessibilityElement(false)
        (self as? NSControl)?.cell?.setAccessibilityElement(false)
    }
}
