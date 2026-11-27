//
//  FannySettingsManager.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

// MARK: - FannySettingsManagerDelegate
/// Listeners told when the saved settings change.
protocol FannySettingsManagerDelegate: AnyObject {
    func fannySettingsManager(_ manager: FannySettingsManager, didUpdateSettings settings: FannySettings)
}

// MARK: - FannySettingsManager
/// Singleton that owns the settings and tells listeners when they change.
/// - Note: Settings load when `shared` is first used, because `Storage` needs the config and the legacy migration must run first.
final class FannySettingsManager {
    
    let delegate: DelegateMulticast<FannySettingsManagerDelegate> = DelegateMulticast<FannySettingsManagerDelegate>()
    
    private(set) var settings: FannySettings = FannySettings.load()
    
    // MARK: - Init
    static let shared: FannySettingsManager = FannySettingsManager()
    private init() {}
    
    // MARK: - Update
    /// Applies a change, then saves and broadcasts it only when a value actually changed.
    func update(_ change: (inout FannySettings) -> Void) {
        let previousSettings: FannySettings = settings
        var updatedSettings: FannySettings = previousSettings
        change(&updatedSettings)
        
        guard updatedSettings != previousSettings else {
            Log.debug("🎛️ update -> unchanged")
            return
        }
        
        settings = updatedSettings
        updatedSettings.save()
        Log.info("🎛️ update -> changed: \(FannySettingsManager.changedFieldNames(from: previousSettings, to: updatedSettings).joined(separator: ", "))")
        delegate.invoke({ $0.fannySettingsManager(self, didUpdateSettings: updatedSettings) })
    }
    
    // MARK: - Helpers
    /// Names the fields that differ, in declaration order, for the update log.
    /// - Note: Add a line here whenever `FannySettings` gains a field, or the log leaves it out.
    static func changedFieldNames(from previousSettings: FannySettings, to updatedSettings: FannySettings) -> [String] {
        var names: [String] = []
        
        if updatedSettings.refreshTimeInterval != previousSettings.refreshTimeInterval { names.append("refreshTimeInterval") }
        if updatedSettings.temperatureUnit != previousSettings.temperatureUnit { names.append("temperatureUnit") }
        if updatedSettings.menuBarLayout != previousSettings.menuBarLayout { names.append("menuBarLayout") }
        if updatedSettings.fanNameStyle != previousSettings.fanNameStyle { names.append("fanNameStyle") }
        if updatedSettings.customFanNames != previousSettings.customFanNames { names.append("customFanNames") }
        if updatedSettings.cpuSensorMode != previousSettings.cpuSensorMode { names.append("cpuSensorMode") }
        if updatedSettings.gpuSensorMode != previousSettings.gpuSensorMode { names.append("gpuSensorMode") }
        if updatedSettings.showsCPUTemperature != previousSettings.showsCPUTemperature { names.append("showsCPUTemperature") }
        if updatedSettings.showsGPUTemperature != previousSettings.showsGPUTemperature { names.append("showsGPUTemperature") }
        if updatedSettings.checksForUpdatesAutomatically != previousSettings.checksForUpdatesAutomatically { names.append("checksForUpdatesAutomatically") }
        if updatedSettings.showsFloatingWindow != previousSettings.showsFloatingWindow { names.append("showsFloatingWindow") }
        if updatedSettings.floatingWindowLayout != previousSettings.floatingWindowLayout { names.append("floatingWindowLayout") }
        
        return names
    }
}
