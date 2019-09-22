//
//  FNYTextField.swift
//  FannyWidget
//
//  Created by Daniel Storm on 9/15/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Cocoa

/// A macOS `NSTextField` that behaves like an iOS `UILabel`.
class FNYTextField: NSTextField {
    
    override var stringValue: String {
        get { return super.stringValue }
        set {
            super.stringValue = newValue
            super.sizeToFit()
        }
    }
    
    // MARK: - View Cycle
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        drawsBackground = false
        isSelectable = false
        isEditable = false
        isBezeled = false
    }
    
}
