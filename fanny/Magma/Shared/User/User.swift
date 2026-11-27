//
//  User.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// The current user of the app, identified by an anonymous ID.
final class User {
    
    // MARK: - ID
    let clientUUID: String = {
        guard let clientUUID: String = Storage.string(forKey: .clientUUID) else {
            let clientUUID: String = UUID().uuidString
            Storage.save(clientUUID, forKey: .clientUUID)
            return clientUUID
        }
        
        return clientUUID
    }()
    
    // MARK: - Feature Usage
    var usesWidgetExtension: Bool {
        return usesFeature(key: Storage.Key.widgetExtension.keyValue)
    }
    
    private func usesFeature(key: String) -> Bool {
        // No last save date means the feature has never been used.
        guard let lastSaveDate: Date = lastSaveDate(key: key) else { return false }
        
        // Usage older than 30 days counts as no longer used.
        return hasUsageExpired(lastSaveDate: lastSaveDate) == false
    }
    
    private func lastSaveDate(key: String) -> Date? {
        return Storage.date(forKey: .custom(value: "\(String(describing: UserManager.self))_\(key)"))
    }
    
    private func hasUsageExpired(lastSaveDate: Date) -> Bool {
        let usageTimeInterval: TimeInterval = 2_592_000.0 // 30 days
        let timeIntervalSinceLastSaveDate: TimeInterval = Date().timeIntervalSince(lastSaveDate)
        return timeIntervalSinceLastSaveDate > usageTimeInterval
    }
}
