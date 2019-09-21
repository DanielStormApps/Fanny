//
//  FNYRadioButton.swift
//  FannyWidget
//
//  Created by Daniel Storm on 9/15/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Cocoa

class FNYRadioButton: NSButton {
    
    // MARK: - Init
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    init(tag: Int, state: NSControl.StateValue, target: AnyObject?, action: Selector?) {
        super.init(frame: NSRect.zero)
        setup()
        
        self.tag = tag
        self.state = state
        self.target = target
        self.action = action
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setup() {
        setButtonType(.radio)
        controlSize = .mini
        title = String()
    }
    
}
