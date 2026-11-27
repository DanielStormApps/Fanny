//
//  AnalyticsSharedParameters.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppKit

/// Provides shared parameter values for all analytics reporters.
/// Each reporter calls `parameters()` to get the current parameter dictionary.
enum AnalyticsSharedParameters {
    
    /// Returns the current shared parameters dictionary.
    /// Values are computed fresh on each call to capture current state.
    static func parameters() -> [String: String] {
        let snapshot: ReadingsSnapshot? = SensorMonitor.shared.snapshot ?? ReadingsSnapshot.load()
        var parameters: [String: String] = [AnalyticsParameter.applicationDidFinishLaunchingTimestamp: applicationDidFinishLaunchingTimestamp,
                                            AnalyticsParameter.deviceTheme: deviceTheme,
                                            AnalyticsParameter.appTheme: appTheme,
                                            AnalyticsParameter.glassTint: glassTint,
                                            AnalyticsParameter.voiceOver: voiceOver,
                                            AnalyticsParameter.launchAtLogin: launchAtLogin,
                                            AnalyticsParameter.fanCount: fanCount(snapshot: snapshot),
                                            AnalyticsParameter.usesWidgetExtension: usesWidgetExtension]
        parameters.combine(with: settingsParameters(FannySettingsManager.shared.settings, fanIDs: fanIDs(snapshot: snapshot)))
        
        return parameters
    }
    
    /// Sends only the choices the user made, never a fan speed or temperature.
    /// - Parameter fanIDs: The fans this Mac has, so the menu bar items and floating window cards list only fans it can show.
    static func settingsParameters(_ settings: FannySettings, fanIDs: [Int] = []) -> [String: String] {
        // Counts the custom fan names, never their text.
        let parameters: [String: String] = [AnalyticsParameter.menuBarItems: settings.menuBarLayout.analyticsValue(fanIDs: fanIDs),
                                            AnalyticsParameter.fanNameStyle: settings.fanNameStyle.rawValue,
                                            AnalyticsParameter.customFanNames: String(settings.customFanNames.count),
                                            AnalyticsParameter.refreshInterval: String(Int(settings.refreshTimeInterval.rounded())),
                                            AnalyticsParameter.temperatureUnit: settings.temperatureUnit.rawValue,
                                            AnalyticsParameter.cpuTemperature: enabledString(settings.showsCPUTemperature),
                                            AnalyticsParameter.cpuSensor: settings.cpuSensorMode.rawValue,
                                            AnalyticsParameter.gpuTemperature: enabledString(settings.showsGPUTemperature),
                                            AnalyticsParameter.gpuSensor: settings.gpuSensorMode.rawValue,
                                            AnalyticsParameter.automaticUpdateChecks: enabledString(settings.checksForUpdatesAutomatically),
                                            AnalyticsParameter.floatingWindow: enabledString(settings.showsFloatingWindow),
                                            AnalyticsParameter.floatingWindowLayout: settings.floatingWindowLayout.orientation.rawValue,
                                            AnalyticsParameter.floatingWindowCards: settings.floatingWindowLayout.analyticsValue(fanIDs: fanIDs)]
        
        return parameters
    }
    
    /// Counts the Mac's fans, which tells fanless Macs apart, and is unspecified until a read finds them.
    /// - Note: Events sent before this launch's first read, such as the launch event, use the last saved snapshot.
    static func fanCount(snapshot: ReadingsSnapshot?) -> String {
        let fanCount: String
        
        switch snapshot?.fanStatus {
        case .fans:
            fanCount = String(snapshot?.fans.count ?? 0)
        case .noFans:
            fanCount = "0"
        case .unavailable, .none:
            fanCount = "unspecified"
        }
        
        return fanCount
    }
    
    private static func fanIDs(snapshot: ReadingsSnapshot?) -> [Int] {
        guard let snapshot: ReadingsSnapshot = snapshot, snapshot.fanStatus == ReadingsSnapshot.FanStatus.fans else { return [] }
        return snapshot.fans.map({ $0.id })
    }
    
    private static var applicationDidFinishLaunchingTimestamp: String {
        return ApplicationLifeCycle.shared.applicationDidFinishLaunchingTimestamp ?? "unspecified"
    }
    
    private static var deviceTheme: String {
        let appearanceName: NSAppearance.Name? = NSApplication.shared.effectiveAppearance.bestMatch(from: [NSAppearance.Name.aqua, NSAppearance.Name.darkAqua])
        let theme: String
        
        switch appearanceName {
        case NSAppearance.Name.aqua: theme = "light"
        case NSAppearance.Name.darkAqua: theme = "dark"
        default: theme = "unspecified"
        }
        
        return theme
    }
    
    private static var appTheme: String {
        return AppThemeManager.shared.themeAnalyticsValue
    }
    
    private static var glassTint: String {
        return AppThemeManager.shared.glassTintAnalyticsValue
    }
    
    private static var voiceOver: String {
        return NSWorkspace.shared.isVoiceOverEnabled
            ? "enabled"
            : "disabled"
    }
    
    private static var launchAtLogin: String {
        return enabledString(LaunchAtLoginManager.shared.isEnabled)
    }
    
    private static var usesWidgetExtension: String {
        return UserManager.shared.currentUser.usesWidgetExtension.stringValue
    }
    
    private static func enabledString(_ isEnabled: Bool) -> String {
        return isEnabled
            ? "enabled"
            : "disabled"
    }
}
