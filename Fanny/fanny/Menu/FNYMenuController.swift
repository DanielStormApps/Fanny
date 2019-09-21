//
//  FNYMenuController.swift
//  Fanny
//
//  Created by Daniel Storm on 9/2/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation
import Cocoa

class FNYMenuController {
    
    private let statusBar: FNYStatusBar = FNYStatusBar()
    
    private lazy var defaultItems: [NSMenuItem] = {
        return [NSMenuItem(title: Item.moreApps.title, action: Item.moreApps.action, keyEquivalent: Item.moreApps.keyEquivalent),
                NSMenuItem(title: Item.preferences.title, action: Item.preferences.action, keyEquivalent: Item.preferences.keyEquivalent),
                NSMenuItem(title: Item.quit.title, action: Item.quit.action, keyEquivalent: Item.quit.keyEquivalent)]
    }()
    
    // MARK: - Init
    init() {
        updateMenuItems()
    }
    
    // MARK: - Update Menu
    @objc private func updateMenuItems() {
        let items = menuItems(fans: SMC.shared.fans(),
                              cpuTemperature: SMC.shared.cpuTemperature(),
                              gpuTemperature: SMC.shared.gpuTemperature())
        
        guard !items.isEmpty else { return }
        statusBar.menu.items = items
    }
    
    // MARK: - Formatted Menu Items
    private func menuItems(fans: [Fan], cpuTemperature: Temperature?, gpuTemperature: Temperature?) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        
        for fan in fans {
            for item in fan.menuItems() {
                items.append(item)
            }
            
            items.append(NSMenuItem.separator())
        }
        
        if let cpuTemperature = cpuTemperature {
            let item = NSMenuItem()
            item.title = String(format: "CPU: %.02f °C", cpuTemperature.celsius)
            items.append(item)
        }
        
        if let gpuTemperature = gpuTemperature {
            let item = NSMenuItem()
            item.title = String(format: "GPU: %.02f °C", gpuTemperature.celsius)
            items.append(item)
        }
        
        items.append(NSMenuItem.separator())
        
        for defaultItem in defaultItems {
            defaultItem.target = self
            items.append(defaultItem)
        }
        
        return items
    }
    
    // MARK: - Default Item Actions
    @objc private func moreAppsClicked() {
        guard let url = URL(string: "macappstore://itunes.apple.com/developer/daniel-storm/id432169230?mt=12&at=1l3vm3h&ct=FANNY") else { return }
        NSWorkspace.shared.open(url)
    }
    
    @objc private func preferencesClicked() {
        //
    }
    
    @objc private func quitClicked() {
        NSApp.terminate(self)
    }
    
}

extension FNYMenuController: FNYMonitorDelegate {

    // MARK: - FNYMonitorDelegate
    func monitorDidRefreshSystemStats(_ monitor: FNYMonitor) {
        updateMenuItems()
    }
    
}

extension FNYMenuController {
    
    // MARK: - Default Menu Items
    private enum Item {
        case moreApps
        case preferences
        case quit
        
        var title: String {
            switch self {
            case .moreApps: return "More Apps"
            case .preferences: return "Preferences"
            case .quit: return "Quit"
            }
        }
        
        var keyEquivalent: String {
            switch self {
            case .quit: return "q"
            default: return String()
            }
        }
        
        var action: Selector {
            switch self {
            case .moreApps: return #selector(moreAppsClicked)
            case .preferences: return #selector(preferencesClicked)
            case .quit: return #selector(quitClicked)
            }
        }
    }
    
}

private extension Fan {
    
    // MARK: - Fan
    func menuItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        
        if let currentRPM = self.currentRPM {
            let item = NSMenuItem()
            item.title = "Current: \(String(currentRPM)) RPM"
            items.append(item)
        }
        
        if let minimumRPM = self.minimumRPM {
            let item = NSMenuItem()
            item.title = "Min: \(String(minimumRPM)) RPM"
            items.append(item)
        }
        
        if let maximumRPM = self.maximumRPM {
            let item = NSMenuItem()
            item.title = "Max: \(String(maximumRPM)) RPM"
            items.append(item)
        }
        
        if let targetRPM = self.targetRPM {
            let item = NSMenuItem()
            item.title = "Target: \(String(targetRPM)) RPM"
            items.append(item)
        }
        
        if !items.isEmpty {
            let item = NSMenuItem()
            item.title = "Fan: #\(String(self.identifier + 1))"
            items.insert(item, at: 0)
        }
        
        return items
    }
    
}
