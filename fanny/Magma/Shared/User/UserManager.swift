//
//  UserManager.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A shared instance class that provides the current user.
final class UserManager {
    
    let currentUser: User = User()
    
    // MARK: - Init
    private init() {}
    static let shared: UserManager = UserManager()
    
    // MARK: - Feature Usage
    func userUsedWidgetExtension() {
        guard shouldSaveUserProperty(key: Storage.Key.widgetExtension.keyValue, rateLimitTimeInterval: UserPropertyRateLimit.widgetExtension.timeInterval) else { return }
        Storage.save(true, forKey: .widgetExtension)
    }
}

/// Limits how often a feature's usage is written, so a widget that redraws often does not write to disk each time.
private enum UserPropertyRateLimit {
    case widgetExtension
    
    var timeInterval: TimeInterval {
        let timeInterval: TimeInterval
        
        switch self {
        case .widgetExtension: timeInterval = 86_400.0 // 24 hours
        }
        
        return timeInterval
    }
}

private extension UserManager {
    
    func shouldSaveUserProperty(key: String, rateLimitTimeInterval: TimeInterval) -> Bool {
        let shouldSave: Bool
        
        if let lastSaveDate: Date = lastSaveDate(key: key),
           hasRateLimitExpired(lastSaveDate: lastSaveDate, rateLimitTimeInterval: rateLimitTimeInterval) == false {
            shouldSave = false
        }
        else {
            updateLastSaveDate(key: key)
            shouldSave = true
        }
        
        return shouldSave
    }
    
    private func lastSaveDate(key: String) -> Date? {
        return Storage.date(forKey: .custom(value: "\(String(describing: UserManager.self))_\(key)"))
    }
    
    private func updateLastSaveDate(key: String) {
        Storage.save(Date(), forKey: .custom(value: "\(String(describing: UserManager.self))_\(key)"))
    }
    
    private func hasRateLimitExpired(lastSaveDate: Date, rateLimitTimeInterval: TimeInterval) -> Bool {
        let timeIntervalSinceLastSaveDate: TimeInterval = Date().timeIntervalSince(lastSaveDate)
        return timeIntervalSinceLastSaveDate > rateLimitTimeInterval
    }
}
