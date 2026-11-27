//
//  Storage.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A wrapper around the shared app group `UserDefaults` that saves and reads values with typed keys.
struct Storage {
    
    enum Key {
        // Analytics
        case clientUUID
        case widgetExtension
        // Preferences
        case fannySettings
        case lastSettingsPane
        // Positive
        case positiveInstallInitialSessionDate
        case appThemeSettings
        // Readings
        case readingsSnapshot
        // Updates
        case lastUpdateCheckDate
        case updateCheckETag
        case availableUpdate
        // About
        case gitHubStarCount
        // Privacy
        case analyticsDisabled
        case crashReportsDisabled
        case crashReportsOffReportPending
        case logsDisabled
        // Custom
        case custom(value: String)
        
        private var rawValue: String {
            let value: String
            
            switch self {
            case .clientUUID: value = "Analytics_clientUUID"
            case .widgetExtension: value = "Analytics_widgetExtension"
            case .fannySettings: value = "Preferences_fannySettings"
            case .lastSettingsPane: value = "Preferences_lastSettingsPane"
            case .positiveInstallInitialSessionDate: value = "PositiveInstall_initialSessionDate"
            case .appThemeSettings: value = "AppTheme_settings"
            case .readingsSnapshot: value = "Readings_snapshot"
            case .lastUpdateCheckDate: value = "Updates_lastCheckDate"
            case .updateCheckETag: value = "Updates_eTag"
            case .availableUpdate: value = "Updates_availableUpdate"
            case .gitHubStarCount: value = "About_gitHubStarCount"
            case .analyticsDisabled: value = "Privacy_analyticsDisabled"
            case .crashReportsDisabled: value = "Privacy_crashReportsDisabled"
            case .crashReportsOffReportPending: value = "Privacy_crashReportsOffReportPending"
            case .logsDisabled: value = "Privacy_logsDisabled"
            case .custom(let rawValue): value = rawValue
            }
            
            return value
        }
        
        var keyValue: String {
            let value: String
            
            switch self {
            case .widgetExtension,
                 .fannySettings,
                 .lastSettingsPane,
                 .positiveInstallInitialSessionDate,
                 .appThemeSettings,
                 .readingsSnapshot,
                 .lastUpdateCheckDate,
                 .updateCheckETag,
                 .availableUpdate,
                 .gitHubStarCount,
                 .analyticsDisabled,
                 .crashReportsDisabled,
                 .crashReportsOffReportPending,
                 .logsDisabled,
                 .custom:
                value = "\(self.rawValue)_\(ConfigManager.shared.config.app!.identifier!)"
            
            default:
                value = self.rawValue
            }
            
            return value
        }
    }
    
    /// The app group comes from the build, so the signing team never appears in the source.
    /// - Note: Built from `FANNY_APP_GROUP_IDENTIFIER` in `Signing.xcconfig` into both Info.plist files.
    private static let localStorage: UserDefaults = {
        guard
            let groupIdentifier: String = Bundle.main.object(forInfoDictionaryKey: "FannyAppGroupIdentifier") as? String,
            groupIdentifier.hasPrefix(".") == false,
            let defaults: UserDefaults = UserDefaults(suiteName: groupIdentifier)
        else {
            fatalError("Missing FannyAppGroupIdentifier. Set DEVELOPMENT_TEAM in fanny/Xcode Config/Local.xcconfig.")
        }
        
        return defaults
    }()
    
    // MARK: - Local Storage
    static func save(_ value: Bool, forKey key: Storage.Key) {
        localStorage.set(value, forKey: key.keyValue)
    }
    
    static func bool(forKey key: Storage.Key) -> Bool {
        return localStorage.bool(forKey: key.keyValue)
    }
    
    static func save(_ value: Date?, forKey key: Storage.Key) {
        localStorage.set(value, forKey: key.keyValue)
    }
    
    static func date(forKey key: Storage.Key) -> Date? {
        return localStorage.object(forKey: key.keyValue) as? Date
    }
    
    static func save(_ value: String?, forKey key: Storage.Key) {
        localStorage.set(value, forKey: key.keyValue)
    }
    
    static func string(forKey key: Storage.Key) -> String? {
        return localStorage.object(forKey: key.keyValue) as? String
    }
    
    static func save(_ value: Data, forKey key: Storage.Key) {
        localStorage.set(value, forKey: key.keyValue)
    }
    
    static func data(forKey key: Storage.Key) -> Data? {
        return localStorage.data(forKey: key.keyValue)
    }
    
    static func removeObject(forKey key: Storage.Key) {
        localStorage.removeObject(forKey: key.keyValue)
    }
}
