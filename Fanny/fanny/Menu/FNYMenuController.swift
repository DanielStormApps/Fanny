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
        return [NSMenuItem(title: Item.gitHub.title, action: Item.gitHub.action, keyEquivalent: Item.gitHub.keyEquivalent),
                NSMenuItem(title: Item.moreApps.title, action: Item.moreApps.action, keyEquivalent: Item.moreApps.keyEquivalent),
                NSMenuItem.separator(),
                NSMenuItem(title: Item.preferences.title, action: Item.preferences.action, keyEquivalent: Item.preferences.keyEquivalent),
                NSMenuItem(title: Item.quit.title, action: Item.quit.action, keyEquivalent: Item.quit.keyEquivalent)]
    }()
    
    private lazy var preferencesWindowController: NSWindowController? = {
        let storyboard: NSStoryboard = NSStoryboard(name: FNYPreferencesViewController.storyboardName, bundle: nil)
        return storyboard.instantiateInitialController() as? NSWindowController
    }()
    
    // MARK: - Init
    init() {
        updateMenuItems()
    }
    
    // MARK: - Update Menu
    @objc private func updateMenuItems() {
        let items: [NSMenuItem] = menuItems(fans: SMC.shared.fans(),
                                            cpuTemperature: SMC.shared.cpuTemperatureAverage(),
                                            gpuTemperature: SMC.shared.gpuTemperatureAverage())
        
        guard !items.isEmpty else { return }
        if #available(OSX 10.14, *) {
            // This property is only settable in macOS 10.14 and later.
            // Xcode does not throw a warning for this: https://stackoverflow.com/a/54682999/2108547
            statusBar.menu.items = items
        }
        else {
            statusBar.menu.removeAllItems()
            items.forEach({ statusBar.menu.addItem($0) })
        }
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
        
        if let cpuTemperature: Temperature = cpuTemperature {
            let item: NSMenuItem = NSMenuItem()
            item.title = "CPU: \(cpuTemperature.formattedTemperature())"
            items.append(item)
        }
        
        if let gpuTemperature: Temperature = gpuTemperature {
            let item: NSMenuItem = NSMenuItem()
            item.title = "GPU: \(gpuTemperature.formattedTemperature())"
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
    @objc private func gitHubClicked() {
        guard let url: URL = URL(string: "https://github.com/DanielStormApps/Fanny") else { return }
        NSWorkspace.shared.open(url)
    }
    
    @objc private func moreAppsClicked() {
        guard let url: URL = URL(string: "macappstore://itunes.apple.com/developer/daniel-storm/id432169230?mt=12&at=1l3vm3h&ct=FANNY") else { return }
        NSWorkspace.shared.open(url)
    }
    
    @objc private func preferencesClicked() {
        preferencesWindowController?.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitClicked() {
        NSApp.terminate(self)
    }
    
}

extension FNYMenuController: FNYMonitorDelegate {

    // MARK: - FNYMonitorDelegate
    func monitorDidRefreshSystemStats(_ monitor: FNYMonitor) {
        updateMenuItems()
        statusBar.updateStatusItem()
    }
    
}

extension FNYMenuController {
    
    // MARK: - Default Menu Items
    private enum Item {
        case gitHub
        case moreApps
        case preferences
        case quit
        
        var title: String {
            switch self {
            case .gitHub: return "GitHub"
            case .moreApps: return "More Apps"
            case .preferences: return "Preferences..."
            case .quit: return "Quit"
            }
        }
        
        var keyEquivalent: String {
            switch self {
            case .preferences: return ","
            case .quit: return "q"
            default: return String()
            }
        }
        
        var action: Selector {
            switch self {
            case .gitHub: return #selector(gitHubClicked)
            case .moreApps: return #selector(moreAppsClicked)
            case .preferences: return #selector(preferencesClicked)
            case .quit: return #selector(quitClicked)
            }
        }
    }
    
}

private extension Fan {
    
    private static let supplementaryItemFontAttributes: [NSAttributedString.Key: NSFont] = [.font: .menuBarFont(ofSize: 12.0)]
    
    // MARK: - Fan
    func menuItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        
        if let currentRPM: Int = self.currentRPM {
            let item: NSMenuItem = NSMenuItem()
            item.title = "Current: \(String(currentRPM)) RPM"
            items.append(item)
        }
        
        if let minimumRPM: Int = self.minimumRPM {
            let item: NSMenuItem = NSMenuItem()
            let title: String = "Min: \(String(minimumRPM)) RPM"
            item.attributedTitle = NSAttributedString(string: title, attributes: Fan.supplementaryItemFontAttributes)
            items.append(item)
        }
        
        if let maximumRPM: Int = self.maximumRPM {
            let item: NSMenuItem = NSMenuItem()
            let title: String = "Max: \(String(maximumRPM)) RPM"
            item.attributedTitle = NSAttributedString(string: title, attributes: Fan.supplementaryItemFontAttributes)
            items.append(item)
        }
        
        if let targetRPM: Int = self.targetRPM {
            let item: NSMenuItem = NSMenuItem()
            let title: String = "Target: \(String(targetRPM)) RPM"
            item.attributedTitle = NSAttributedString(string: title, attributes: Fan.supplementaryItemFontAttributes)
            items.append(item)
        }
        
        if !items.isEmpty {
            let item: NSMenuItem = NSMenuItem()
            item.title = "Fan: #\(String(self.identifier + 1))"
            items.insert(item, at: 0)
        }
        
        return items
    }
    
}
