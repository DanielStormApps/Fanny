//
//  Config.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

// MARK: - Config
struct Config: Codable {
    let externalConfigPath: String?
    let app: AppConfig?
    let analytics: AnalyticsConfig?
}

// MARK: - App
struct AppConfig: Codable {
    /// Suffixes the per-app storage keys. Fanny has no App Store ID, so this is a fixed string that must never change.
    let identifier: String?
    let name: String?
    let positivePath: String?
    let contactEmailAddress: String?
    let privacyPolicyPath: String?
    let gitHubPath: String?
}

// MARK: - Analytics
struct AnalyticsConfig: Codable {
    let heartbeatTimeInterval: Int?
    let services: AnalyticsServicesConfig?
}

struct AnalyticsServicesConfig: Codable {
    let firebase: AnalyticsServiceConfig?
    let telemetryDeck: AnalyticsServiceConfig?
}

struct AnalyticsServiceConfig: Codable {
    let enabled: Bool?
    let trackingIDs: AnalyticsServiceTrackingIDsConfig?
}

struct AnalyticsServiceTrackingIDsConfig: Codable {
    let production: [String]?
    let development: [String]?
}
