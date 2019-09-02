//
//  FNYMenu.swift
//  Fanny
//
//  Created by Daniel Storm on 9/2/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation
import Cocoa

protocol FNYMenuDefaultItemDelegate: class {
    func menu(_ menu: FNYMenu, didReceiveClickOnItem item: FNYMenu.Item)
}

class FNYMenu: NSMenu {
    
    enum Item {
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
        
    }
    
    weak var defaultItemDelegate: FNYMenuDefaultItemDelegate?
    
    private(set) var fans: [SMC.Fan] = []
    private(set) var cpuTemperature: Temperature?
    private(set) var gpuTemperature: Temperature?

    private lazy var defaultItems: [NSMenuItem] = {
        return [NSMenuItem(title: Item.moreApps.title, action: #selector(moreAppsClicked), keyEquivalent: Item.moreApps.keyEquivalent),
                NSMenuItem(title: Item.preferences.title, action: #selector(preferencesClicked), keyEquivalent: Item.preferences.keyEquivalent),
                NSMenuItem(title: Item.quit.title, action: #selector(quitClicked), keyEquivalent: Item.quit.keyEquivalent)]
    }()
    
    // MARK: - Init
    init() {
        super.init(title: String())
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Update
    func update(fans: [SMC.Fan], cpuTemperature: Temperature?, gpuTemperature: Temperature?) {
        self.fans = fans
        self.cpuTemperature = cpuTemperature
        self.gpuTemperature = gpuTemperature
        updateItems()
    }
    
    private func updateItems() {
        items = []
        
        for fan in fans {
            for item in fan.menuItems() {
                addItem(item)
            }
            
            addItem(NSMenuItem.separator())
        }
        
        if let cpuTemperature = cpuTemperature {
            let item = NSMenuItem()
            item.title = String(format: "CPU: %.02f °C", cpuTemperature.celsius)
            addItem(item)
        }
        
        if let gpuTemperature = gpuTemperature {
            let item = NSMenuItem()
            item.title = String(format: "GPU: %.02f °C", gpuTemperature.celsius)
            addItem(item)
        }
        
        addItem(NSMenuItem.separator())
        
        for defaultItem in defaultItems {
            defaultItem.target = self
            addItem(defaultItem)
        }
    }
    
    // MARK: - Default Item Actions
    @objc private func moreAppsClicked() {
        defaultItemDelegate?.menu(self, didReceiveClickOnItem: .moreApps)
    }
    
    @objc private func preferencesClicked() {
        defaultItemDelegate?.menu(self, didReceiveClickOnItem: .preferences)
    }
    
    @objc private func quitClicked() {
        defaultItemDelegate?.menu(self, didReceiveClickOnItem: .quit)
    }
    
}

private extension SMC.Fan {
    
    // MARK: - SMC.Fan
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
            item.title = "Fan: #\(String(self.identifier))"
            items.insert(item, at: 0)
        }
        
        return items
    }
    
}
