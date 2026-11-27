//
//  FirebaseReporter.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation
import FirebaseAnalytics

/// A reporter that logs analytics events with Firebase.
final class FirebaseReporter {
    
    /// Firebase rejects event names longer than this, so names are trimmed before sending.
    private static let maximumEventNameLength: Int = 40
    
    // MARK: - Content View
    func contentView(name: String) {
        let parameters: [String: String] = [AnalyticsParameter.hitType: AnalyticsHitType.contentView,
                                            AnalyticsParameter.contentName: name]
        
        report(name: name, parameters: parameters)
    }
    
    // MARK: - Event
    func event(name: String, action: String, description: String) {
        let parameters: [String: String] = [AnalyticsParameter.hitType: AnalyticsHitType.event,
                                            AnalyticsParameter.eventName: name,
                                            AnalyticsParameter.eventAction: action,
                                            AnalyticsParameter.eventDescription: description]
        
        report(name: name, parameters: parameters)
    }
    
    // MARK: - Report
    private func report(name: String, parameters: [String: String]) {
        var combinedParameters: [String: String] = AnalyticsSharedParameters.parameters()
        combinedParameters.combine(with: parameters)
        send(name: name, parameters: combinedParameters)
    }
    
    private func send(name: String, parameters: [String: String]) {
        let trimmedName: String = String(name.prefix(FirebaseReporter.maximumEventNameLength))
        FirebaseAnalytics.Analytics.logEvent(trimmedName, parameters: parameters)
    }
}
