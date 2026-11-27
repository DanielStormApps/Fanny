//
//  AnalyticsEventRateLimiter.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A shared instance class that decides if a rate limited analytics event should send.
final class AnalyticsEventRateLimiter {
    
    // MARK: - Init
    private init() {}
    static let shared: AnalyticsEventRateLimiter = AnalyticsEventRateLimiter()
    
    func shouldSendAnalyticsEvent(key: String, rateLimitTimeInterval: TimeInterval?) -> Bool {
        guard let rateLimitTimeInterval: TimeInterval = rateLimitTimeInterval else { return true }
        
        guard let lastSentDate: Date = lastSentDate(key: key) else {
            updateLastSentDate(key: key)
            return true
        }
        
        let shouldSend: Bool
        
        if hasRateLimitExpired(lastSentDate: lastSentDate, rateLimitTimeInterval: rateLimitTimeInterval) {
            updateLastSentDate(key: key)
            shouldSend = true
        }
        else {
            shouldSend = false
        }
        
        return shouldSend
    }
    
    private func lastSentDate(key: String) -> Date? {
        return Storage.date(forKey: .custom(value: key))
    }
    
    private func updateLastSentDate(key: String) {
        let currentDate: Date = Date()
        Storage.save(currentDate, forKey: .custom(value: key))
    }
    
    private func hasRateLimitExpired(lastSentDate: Date, rateLimitTimeInterval: TimeInterval) -> Bool {
        let currentDate: Date = Date()
        let timeIntervalSinceLastSentDate: TimeInterval = currentDate.timeIntervalSince(lastSentDate)
        return timeIntervalSinceLastSentDate > rateLimitTimeInterval
    }
}
