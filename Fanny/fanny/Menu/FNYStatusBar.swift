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
    
    // MARK: - Init
    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Loading.."
        statusItem?.menu = menu
    }
    
//    // MARK: - Setup
//    private func applyStatusItemIcon() {
//        guard let statusItemIcon: NSImage = NSImage(named: "status-item-icon-default.png") else { return }
//        statusItemIcon.isTemplate = true
//        statusItem?.image = statusItemIcon
//    }

    func updateStatusItem() {
        let cpuTemperature = SMC.shared.cpuTemperatureAverage()
        statusItem?.button?.title = cpuTemperature!.formattedTemperature(decimals: 0, useSpaceDelimiter: false)
    }
    
}
