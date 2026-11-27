//
//  TelemetryDeckAnalyticsBridge.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// An analytics bridge that sends events to TelemetryDeck.
final class TelemetryDeckAnalyticsBridge: AnalyticsBridge {
    
    private var reporter: TelemetryDeckReporter?
    private var isEnabled: Bool {
        return ConfigManager.shared.config.analytics?.services?.telemetryDeck?.enabled == true
    }
    
    // MARK: - AnalyticsBridge
    required init(trackingIDs: [String]) {
        guard
            isEnabled,
            let trackingID: String = trackingIDs.first
        else { return }
        
        let clientUUID: String = UserManager.shared.currentUser.clientUUID
        reporter = TelemetryDeckReporter(trackingID: trackingID, clientUUID: clientUUID, isEnabled: Analytics.shared.isEnabled)
    }
    
    func setEnabled(_ isEnabled: Bool) {
        reporter?.setEnabled(isEnabled)
    }
    
    func trackEvent(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        
        switch event {
        case let event as AppEvent:
            guard let name: String = event.name() else { return }
            reporter?.contentView(name: name)
        
        case let event as PageViewEvent:
            guard
                let name: String = event.name(),
                AnalyticsEventRateLimiter.shared.shouldSendAnalyticsEvent(key: event.rateLimitKey(name: name), rateLimitTimeInterval: event.rateLimitTimeInterval)
            else { return }
            reporter?.contentView(name: name)
        
        case let event as HeartbeatEvent:
            reporter?.event(name: event.name(), action: event.action(), description: event.description())
        
        case let event as FAQFeedbackEvent:
            guard
                let name: String = event.name(),
                let action: String = event.action(),
                let description: String = event.description()
            else { return }
            reporter?.event(name: name, action: action, description: description)
        
        default:
            return
        }
    }
}

// MARK: - AppEvent
private extension AppEvent {
    
    func name() -> String? {
        guard let eventType: EventType = self.eventType else { return nil }
        let name: String
        
        switch eventType {
        case .launch:
            name = "appLaunch"
        }
        
        return name
    }
}

// MARK: - PageViewEvent
private extension PageViewEvent {
    
    func name() -> String? {
        guard let name: String = self.title else { return nil }
        return Analytics.formatEventTitle(name)
    }
    
    func rateLimitKey(name: String) -> String {
        return "\(String(describing: TelemetryDeckAnalyticsBridge.self))_\(name)"
    }
}

// MARK: - HeartbeatEvent
private extension HeartbeatEvent {
    
    func name() -> String {
        return "heartbeat"
    }
    
    func action() -> String {
        return "heartbeat_Action"
    }
    
    func description() -> String {
        return "heartbeat_Description"
    }
}

// MARK: - FAQFeedbackEvent
private extension FAQFeedbackEvent {
    
    func name() -> String? {
        return "faqFeedback"
    }
    
    func action() -> String? {
        guard let feedbackType: FeedbackType = self.feedbackType else { return nil }
        let action: String
        
        switch feedbackType {
        case .helpful:
            action = "helpful"
        case .notHelpful:
            action = "notHelpful"
        }
        
        return action
    }
    
    func description() -> String? {
        return articleID ?? "faqFeedback_Description"
    }
}
