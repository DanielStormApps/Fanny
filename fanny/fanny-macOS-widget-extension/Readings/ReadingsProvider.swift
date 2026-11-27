//
//  ReadingsProvider.swift
//  fanny-macOS-widget-extension
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import WidgetKit

/// Builds the widget's timeline from the snapshot the app saved.
struct ReadingsProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> ReadingsEntry {
        return ReadingsProvider.previewEntry()
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ReadingsEntry) -> Void) {
        let entry: ReadingsEntry
        
        if context.isPreview {
            entry = ReadingsProvider.previewEntry()
        }
        else {
            entry = ReadingsEntry(date: Date(), snapshot: ReadingsSnapshot.load(), settings: FannySettings.load(), isPreview: false)
        }
        
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingsEntry>) -> Void) {
        let now: Date = Date()
        let snapshot: ReadingsSnapshot? = ReadingsSnapshot.load()
        let settings: FannySettings = FannySettings.load()
        let entries: [ReadingsEntry] = ReadingsTimeline.entryDates(for: snapshot, now: now).map({ ReadingsEntry(date: $0, snapshot: snapshot, settings: settings, isPreview: false) })
        completion(Timeline(entries: entries, policy: .after(ReadingsTimeline.reloadDate(now: now))))
    }
    
    // MARK: - Preview
    /// Two fans and both temperatures, so the gallery shows everything the widget can.
    private static func previewEntry(date: Date = Date()) -> ReadingsEntry {
        let fans: [FanReading] = [FanReading(id: 0, currentRPM: 2140.0, minimumRPM: 1350.0, maximumRPM: 5349.0, targetRPM: 2140.0),
                                  FanReading(id: 1, currentRPM: 2310.0, minimumRPM: 1522.0, maximumRPM: 5777.0, targetRPM: 2310.0),]
        let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: date, fanStatus: .fans, fans: fans, cpuTemperature: TemperatureReading(celsius: 52.4), gpuTemperature: TemperatureReading(celsius: 47.1))
        return ReadingsEntry(date: date, snapshot: snapshot, settings: FannySettings(), isPreview: true)
    }
}
