//
//  AnalyticsEvent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

// MARK: - AnalyticsEvent
protocol AnalyticsEvent {
    /// Amount of time that must pass between sending identical events.
    /// - Note: `nil` equals no rate limiting.
    var rateLimitTimeInterval: TimeInterval? { get set }
}

// MARK: - AppEvent
struct AppEvent: AnalyticsEvent {
    var eventType: AppEvent.EventType?
    var rateLimitTimeInterval: TimeInterval?
    
    enum EventType {
        case launch
    }
}

// MARK: - PageViewEvent
struct PageViewEvent: AnalyticsEvent {
    var title: String?
    var rateLimitTimeInterval: TimeInterval?
}

// MARK: - HeartbeatEvent
struct HeartbeatEvent: AnalyticsEvent {
    var rateLimitTimeInterval: TimeInterval?
}

// MARK: - FAQFeedbackEvent
struct FAQFeedbackEvent: AnalyticsEvent {
    
    enum FeedbackType {
        case helpful
        case notHelpful
    }
    
    var articleID: String?
    var feedbackType: FeedbackType?
    var rateLimitTimeInterval: TimeInterval?
}
