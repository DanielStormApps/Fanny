//
//  AnalyticsParameter.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// Shared parameter keys used by all analytics reporters.
enum AnalyticsParameter {
    
    // MARK: - Application
    static let applicationDidFinishLaunchingTimestamp: String = "applicationDidFinishLaunchingTimestamp"
    
    // MARK: - Device
    static let deviceTheme: String = "deviceTheme"
    static let appTheme: String = "appTheme"
    static let voiceOver: String = "voiceOver"
    
    // MARK: - Settings
    static let menuBarItems: String = "menuBarItems"
    static let fanNameStyle: String = "fanNameStyle"
    static let customFanNames: String = "customFanNames"
    static let refreshInterval: String = "refreshInterval"
    static let temperatureUnit: String = "temperatureUnit"
    static let cpuTemperature: String = "cpuTemperature"
    static let cpuSensor: String = "cpuSensor"
    static let gpuTemperature: String = "gpuTemperature"
    static let gpuSensor: String = "gpuSensor"
    static let automaticUpdateChecks: String = "automaticUpdateChecks"
    static let launchAtLogin: String = "launchAtLogin"
    static let floatingWindow: String = "floatingWindow"
    static let floatingWindowLayout: String = "floatingWindowLayout"
    static let floatingWindowCards: String = "floatingWindowCards"
    static let glassTint: String = "glassTint"
    
    // MARK: - Hardware
    static let fanCount: String = "fanCount"
    
    // MARK: - User
    static let clientUUID: String = "clientUUID"
    
    // MARK: - Feature Usage
    static let usesWidgetExtension: String = "usesWidgetExtension"
    
    // MARK: - Hit Type
    static let hitType: String = "hitType"
    
    // MARK: - Content View
    static let contentName: String = "contentName"
    
    // MARK: - Event
    static let eventName: String = "eventName"
    static let eventAction: String = "eventAction"
    static let eventDescription: String = "eventDescription"
}

/// Hit type values for analytics events.
enum AnalyticsHitType {
    static let contentView: String = "contentView"
    static let event: String = "event"
}
