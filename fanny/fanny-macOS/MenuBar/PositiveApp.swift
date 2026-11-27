//
//  PositiveApp.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

/// Links to Positive, whose downloads help keep Fanny free.
enum PositiveApp {
    
    static let symbolName: String = "custom.app.icon.fill"
    
    private static let minimumDaysInstalled: Int = 1
    
    /// The menu items wait until Fanny has been installed for a day.
    static var isMenuItemAvailable: Bool {
        return daysExceeded(initialSessionDate: Storage.date(forKey: .positiveInstallInitialSessionDate), now: Date(), calendar: Calendar.current)
    }
    
    // MARK: - Launch
    /// Stamps the first session once, so the day count starts at install.
    static func trackLaunch() {
        guard Storage.date(forKey: .positiveInstallInitialSessionDate) == nil else { return }
        Storage.save(Date(), forKey: .positiveInstallInitialSessionDate)
    }
    
    // MARK: - Days
    /// Counts calendar days, so a first launch late at night qualifies the next morning.
    static func daysExceeded(initialSessionDate: Date?, now: Date, calendar: Calendar) -> Bool {
        guard let initialSessionDate: Date = initialSessionDate else { return false }
        
        let daysPassed: Int = calendar.dateComponents([.day], from: calendar.startOfDay(for: initialSessionDate), to: calendar.startOfDay(for: now)).day ?? 0
        return daysPassed >= PositiveApp.minimumDaysInstalled
    }
    
    // MARK: - App Store
    /// Every entry point shares the configured link, so all downloads report under one campaign.
    static func openAppStore() {
        guard
            let positivePath: String = ConfigManager.shared.config.app?.positivePath,
            let positiveURL: URL = URL(string: positivePath)
        else {
            Log.warn("📲 openAppStore -> missing Positive path")
            return
        }
        
        NSWorkspace.shared.open(positiveURL)
    }
}
