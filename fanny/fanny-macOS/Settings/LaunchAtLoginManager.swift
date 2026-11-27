//
//  LaunchAtLoginManager.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import ServiceManagement

/// Registers Fanny as a login item through `SMAppService`.
final class LaunchAtLoginManager {
    
    /// Read from the system every time, so it reflects changes made in System Settings.
    var isEnabled: Bool {
        return SMAppService.mainApp.status == .enabled
    }
    
    var requiresApproval: Bool {
        return SMAppService.mainApp.status == .requiresApproval
    }
    
    // MARK: - Init
    private init() {}
    static let shared: LaunchAtLoginManager = LaunchAtLoginManager()
    
    // MARK: - Registration
    /// - Returns: `false` when the system refused the change.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        let didChange: Bool
        
        do {
            if enabled {
                try SMAppService.mainApp.register()
            }
            else {
                try SMAppService.mainApp.unregister()
            }
            
            Log.info("📲 setEnabled -> enabled: \(enabled), status: \(SMAppService.mainApp.status.rawValue)")
            didChange = true
        }
        catch {
            Log.error("📲 setEnabled -> enabled: \(enabled), error: \(error.localizedDescription)")
            didChange = false
        }
        
        return didChange
    }
    
    // MARK: - System Settings
    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
