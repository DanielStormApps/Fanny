//
//  ReadingsTimeline.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// Turns a saved `ReadingsSnapshot` into the moments the widget should draw.
enum ReadingsTimeline {
    
    /// The app reloads the widget itself when values change, so WidgetKit only needs to ask again as often as the app would.
    static let reloadTimeInterval: TimeInterval = 900.0
    /// The footer stays empty until the readings are this old, so it never reads now or 1 minute ago.
    static let ageShownTimeInterval: TimeInterval = 120.0
    /// The footer's age is plain text, so an entry each minute moves it on.
    static let ageStepTimeInterval: TimeInterval = 60.0
    
    // MARK: - Dates
    /// Now, plus each whole minute from the moment the footer's age first shows to the moment the snapshot turns stale, so the age counts up and the stale look arrives on time even when no reload comes.
    /// - Note: Timeline entries don't count against WidgetKit's reload budget.
    static func entryDates(for snapshot: ReadingsSnapshot?, now: Date) -> [Date] {
        var dates: [Date] = [now]
        
        guard let snapshot: ReadingsSnapshot = snapshot, snapshot.stoppedDate == nil else { return dates }
        
        let staleDate: Date = snapshot.capturedDate.addingTimeInterval(ReadingsSnapshot.staleTimeInterval)
        var minuteDate: Date = snapshot.capturedDate.addingTimeInterval(ReadingsTimeline.ageShownTimeInterval)
        
        while minuteDate <= staleDate {
            if minuteDate > now {
                dates.append(minuteDate)
            }
            
            minuteDate = minuteDate.addingTimeInterval(ReadingsTimeline.ageStepTimeInterval)
        }
        
        return dates
    }
    
    /// True once the readings are old enough for the footer to show their age.
    static func showsAge(of snapshot: ReadingsSnapshot, at date: Date) -> Bool {
        return date.timeIntervalSince(snapshot.capturedDate) >= ReadingsTimeline.ageShownTimeInterval
    }
    
    static func reloadDate(now: Date) -> Date {
        return now.addingTimeInterval(ReadingsTimeline.reloadTimeInterval)
    }
}
