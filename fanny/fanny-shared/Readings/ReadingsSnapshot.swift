//
//  ReadingsSnapshot.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// One read of every fan and temperature, shared by the menu bar, Settings, Shortcuts, and the widget.
struct ReadingsSnapshot: Codable, Equatable {
    
    enum FanStatus: String, Codable {
        case fans
        case noFans
        case unavailable
    }
    
    var capturedDate: Date
    var fanStatus: FanStatus
    var fans: [FanReading]
    var cpuTemperature: TemperatureReading?
    var gpuTemperature: TemperatureReading?
    /// Every CPU mode that was read, for the floating window. `cpuTemperature` is the menu's, and `nil` when the menu hides it.
    var cpuTemperatures: [FannySettings.CPUSensorMode: TemperatureReading]?
    var gpuTemperatures: [FannySettings.GPUSensorMode: TemperatureReading]?
    /// Set when Fanny quits, so the widget dims and asks for a click to refresh.
    var stoppedDate: Date?
    
    /// Never changes after shipping, because it ties placed widgets to this widget.
    static let widgetKind: String = "com.fannywidget.readings"
    /// A snapshot this old means Fanny stopped reading without quitting, such as after a crash, so the widget dims its values.
    /// - Note: A running Fanny reloads the widget at least every 15 minutes, so an hour leaves room for missed reloads.
    static let staleTimeInterval: TimeInterval = 3600.0
    
    /// - Returns: `nil` unless the snapshot has fans.
    var fastestFan: FanReading? {
        guard fanStatus == FanStatus.fans else { return nil }
        return fans.max(by: { $0.currentRPM < $1.currentRPM })
    }
    
    // MARK: - Init
    init(capturedDate: Date, fanStatus: FanStatus, fans: [FanReading] = [], cpuTemperature: TemperatureReading? = nil, gpuTemperature: TemperatureReading? = nil, cpuTemperatures: [FannySettings.CPUSensorMode: TemperatureReading]? = nil, gpuTemperatures: [FannySettings.GPUSensorMode: TemperatureReading]? = nil, stoppedDate: Date? = nil) {
        self.capturedDate = capturedDate
        self.fanStatus = fanStatus
        self.fans = fans
        self.cpuTemperature = cpuTemperature
        self.gpuTemperature = gpuTemperature
        self.cpuTemperatures = cpuTemperatures
        self.gpuTemperatures = gpuTemperatures
        self.stoppedDate = stoppedDate
    }
    
    static func unavailable(at date: Date) -> ReadingsSnapshot {
        return ReadingsSnapshot(capturedDate: date, fanStatus: FanStatus.unavailable)
    }
    
    // MARK: - Staleness
    /// A snapshot from a Fanny that quit is always stale. One dated after `date`, from a clock that moved backward, is not.
    func isStale(at date: Date) -> Bool {
        return stoppedDate != nil || date.timeIntervalSince(capturedDate) >= ReadingsSnapshot.staleTimeInterval
    }
    
    // MARK: - Storage
    /// - Returns: `nil` when the app has not saved a snapshot yet, or the saved one cannot be read.
    static func load() -> ReadingsSnapshot? {
        guard let data: Data = Storage.data(forKey: .readingsSnapshot) else { return nil }
        
        let snapshot: ReadingsSnapshot?
        do {
            snapshot = try JSONDecoder().decode(ReadingsSnapshot.self, from: data)
        }
        catch {
            Log.error("💾 ReadingsSnapshot load -> error: \(error.localizedDescription)")
            snapshot = nil
        }
        
        return snapshot
    }
    
    func save() {
        do {
            let data: Data = try JSONEncoder().encode(self)
            Storage.save(data, forKey: .readingsSnapshot)
        }
        catch {
            Log.error("💾 ReadingsSnapshot save -> error: \(error.localizedDescription)")
        }
    }
}
