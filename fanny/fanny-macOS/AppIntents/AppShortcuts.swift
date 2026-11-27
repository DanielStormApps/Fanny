//
//  AppShortcuts.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Registers the App Shortcuts that Siri and Spotlight offer right after install.
/// - Note: Every phrase carries the application name, or the metadata step fails.
struct AppShortcuts: AppShortcutsProvider {
    
    static var appShortcuts: [AppShortcut] {
        return [AppShortcut(intent: GetFanSpeedsIntent(),
                            phrases: ["What's my \(.applicationName) fan speed",
                                      "How fast are my fans in \(.applicationName)"],
                            shortTitle: "Get Fan Speeds",
                            systemImageName: "fan"),
                AppShortcut(intent: GetCPUTemperatureIntent(),
                            phrases: ["What's my CPU temperature in \(.applicationName)"],
                            shortTitle: "Get CPU Temperature",
                            systemImageName: "cpu"),
                AppShortcut(intent: GetGPUTemperatureIntent(),
                            phrases: ["What's my GPU temperature in \(.applicationName)"],
                            shortTitle: "Get GPU Temperature",
                            systemImageName: "thermometer.medium"),
                AppShortcut(intent: GetReadingsIntent(),
                            phrases: ["What are my \(.applicationName) readings",
                                      "How hot is my Mac in \(.applicationName)"],
                            shortTitle: "Get Readings",
                            systemImageName: "gauge.with.dots.needle.67percent"),
                AppShortcut(intent: GetFanSpeedIntent(),
                            phrases: ["What's the speed of \(\.$fan) in \(.applicationName)"],
                            shortTitle: "Get Fan Speed",
                            systemImageName: "fan"),
                AppShortcut(intent: ShowFloatingWindowIntent(),
                            phrases: ["Show \(.applicationName) floating window"],
                            shortTitle: "Show Floating Window",
                            systemImageName: "eye"),
                AppShortcut(intent: HideFloatingWindowIntent(),
                            phrases: ["Hide \(.applicationName) floating window"],
                            shortTitle: "Hide Floating Window",
                            systemImageName: "eye.slash"),
                AppShortcut(intent: CheckForUpdatesIntent(),
                            phrases: ["Check for \(.applicationName) updates"],
                            shortTitle: "Check for Updates",
                            systemImageName: "arrow.down.circle"),
                AppShortcut(intent: OpenSettingsIntent(),
                            phrases: ["Open \(.applicationName) settings"],
                            shortTitle: "Open Fanny Settings",
                            systemImageName: "gearshape")]
    }
}
