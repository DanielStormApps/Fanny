//
//  FNYStatusBar.swift
//  Fanny
//
//  Created by Daniel Storm on 9/2/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation
import Cocoa

class FNYStatusBar: NSStatusBar {
    
    let menu: FNYMenu = FNYMenu()
    
    private var statusItem: NSStatusItem?
    
    var statusItemExists = false
    var iconApplied = false
    
    
    // MARK: - Init
    override init() {
        super.init()
        createStatusItem()
        applyStatusItemIcon()
    }
    
    // MARK: - Create statusItem without icon or text
    func createStatusItem() {
        if !statusItemExists {
            iconApplied = false // reset
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem?.menu = menu
            statusItemExists = true
        }
    }

    // MARK: - Reset statusItem to no icon/text
    func resetStatusItem() {
        // TODO: This should be done by removing the icon and text rather than removing and recreating the item
        // something like
        // statusItem?.image = nil
        // statusItem?.button?.title = ""
        if statusItemExists {
            removeStatusItem(statusItem!)  // TODO: resolve force unwrap
            statusItemExists = false
        }
        createStatusItem()
    }
    
    // MARK: - Set to icon
    func applyStatusItemIcon() {
        if !statusItemExists {
            createStatusItem()
        }
        if !iconApplied {
            statusItem?.button?.title = ""
            guard let statusItemIcon: NSImage = NSImage(named: "status-item-icon-default.png") else { return }
            statusItemIcon.isTemplate = true
            statusItem?.image = statusItemIcon
            iconApplied = true
        }
    }
    

    // MARK: - Update to current temperature
    func updateStatusItemTemperature() {
        if !statusItemExists {
            createStatusItem()
        }
        if iconApplied {
            resetStatusItem()
        }
        let cpuTemperature = SMC.shared.cpuTemperatureAverage()
        // TODO: is this an okay way to avoid the force unwrap?
        if cpuTemperature != nil {
            statusItem?.button?.title = cpuTemperature!.formattedTemperature(decimals: 0, useSpaceDelimiter: false)
        } else {
            statusItem?.button?.title = "Err"
        }
        
    }
    
}
