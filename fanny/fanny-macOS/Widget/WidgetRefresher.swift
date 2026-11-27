//
//  WidgetRefresher.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import WidgetKit

/// Asks WidgetKit to redraw the readings widget when its values change, only while one is placed, and paced to WidgetKit's daily budget.
/// - Note: Everything runs on the main thread, which is where the monitor and the settings manager call it.
final class WidgetRefresher {
    
    /// The values the widget draws: whole RPM and whole degrees in the chosen unit, so a change below that redraws nothing.
    struct WidgetReadings: Equatable {
        
        struct Fan: Equatable {
            let id: Int
            let isStopped: Bool
            let currentRPM: Double
            let minimumRPM: Double?
            let maximumRPM: Double?
            let targetRPM: Double?
        }
        
        let fanStatus: ReadingsSnapshot.FanStatus
        let fans: [Fan]
        let cpuTemperature: Double?
        let gpuTemperature: Double?
        
        // MARK: - Init
        init(snapshot: ReadingsSnapshot, unit: FannySettings.TemperatureUnit) {
            fanStatus = snapshot.fanStatus
            fans = snapshot.fans.map({ Fan(id: $0.id, isStopped: $0.isStopped, currentRPM: $0.currentRPM.rounded(), minimumRPM: $0.minimumRPM?.rounded(), maximumRPM: $0.maximumRPM?.rounded(), targetRPM: $0.targetRPM?.rounded()) })
            cpuTemperature = snapshot.cpuTemperature.map({ $0.value(in: unit).rounded() })
            gpuTemperature = snapshot.gpuTemperature.map({ $0.value(in: unit).rounded() })
        }
    }
    
    private var isStarted: Bool = false
    private var isCheckingConfigurations: Bool = false
    private var lastReloadDate: Date?
    private var lastReloadedReadings: WidgetReadings?
    private var previousSettings: FannySettings?
    
    /// WidgetKit gives a widget about 40 to 70 reloads a day, so reloading on every read would spend the day's budget in minutes and freeze the widget for hours.
    private static let backgroundReloadTimeInterval: TimeInterval = 900.0
    
    // MARK: - Init
    private init() {}
    static let shared: WidgetRefresher = WidgetRefresher()
    
    // MARK: - Start
    /// Listens for the settings the widget draws with. Later calls do nothing.
    func start() {
        guard isStarted == false else { return }
        isStarted = true
        previousSettings = FannySettingsManager.shared.settings
        FannySettingsManager.shared.delegate.add(self)
    }
    
    // MARK: - Refresh
    /// Call after every read, once the snapshot is saved. Reloads when what the widget draws changed since its last reload.
    func refreshReadingsIfNeeded(snapshot: ReadingsSnapshot) {
        let settings: FannySettings = FannySettingsManager.shared.settings
        let readings: WidgetReadings = WidgetReadings(snapshot: snapshot, unit: settings.temperatureUnit)
        let minimumTimeInterval: TimeInterval = WidgetRefresher.minimumReloadTimeInterval(isAppActive: NSApplication.shared.isActive, refreshTimeInterval: settings.refreshTimeInterval)
        let date: Date = Date()
        
        guard
            isCheckingConfigurations == false,
            WidgetRefresher.shouldReloadReadings(readings: readings, lastReloadedReadings: lastReloadedReadings, lastReloadDate: lastReloadDate, date: date, minimumTimeInterval: minimumTimeInterval)
        else { return }
        
        // Recorded before the check, so a Mac with no widget placed asks WidgetKit no more often than one with a widget.
        lastReloadDate = date
        lastReloadedReadings = readings
        isCheckingConfigurations = true
        
        reloadIfReadingsWidgetPlaced(reason: "readings") { [weak self] in
            self?.isCheckingConfigurations = false
        }
    }
    
    /// The unit or a shown temperature changed, which the widget draws right away. The next read reloads again with fresh values.
    private func refreshReadingsForSettingsChange() {
        lastReloadDate = nil
        lastReloadedReadings = nil
        reloadIfReadingsWidgetPlaced(reason: "settings", completion: nil)
    }
    
    /// A failed check reloads anyway, since a missed redraw would leave the widget showing old values.
    private func reloadIfReadingsWidgetPlaced(reason: String, completion: (() -> Void)?) {
        WidgetCenter.shared.getCurrentConfigurations { result in
            let kinds: [String]?
            let errorDescription: String?
            
            switch result {
            case .success(let widgetInfos):
                kinds = widgetInfos.map({ $0.kind })
                errorDescription = nil
            case .failure(let error):
                kinds = nil
                errorDescription = error.localizedDescription
            }
            
            DispatchQueue.main.async {
                if let errorDescription: String = errorDescription {
                    Log.warn("🌅 getCurrentConfigurations -> error: \(errorDescription)")
                    WidgetRefresher.reloadReadingsTimelines(reason: reason)
                }
                else if WidgetRefresher.containsReadingsWidget(kinds: kinds ?? []) {
                    WidgetRefresher.reloadReadingsTimelines(reason: reason)
                }
                
                completion?()
            }
        }
    }
    
    /// Fanny is quitting, so there is no time to check what is placed. The snapshot already says Fanny stopped.
    func reloadForTermination() {
        WidgetRefresher.reloadReadingsTimelines(reason: "terminate")
    }
    
    private static func reloadReadingsTimelines(reason: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: ReadingsSnapshot.widgetKind)
        Log.info("🌅 Readings widget reloaded -> reason: \(reason)")
    }
    
    // MARK: - Helpers
    /// Apple does not count reloads while the app is in the foreground, so with Fanny active, such as with Settings open, the widget keeps up with every read.
    static func minimumReloadTimeInterval(isAppActive: Bool, refreshTimeInterval: TimeInterval) -> TimeInterval {
        return isAppActive ? refreshTimeInterval : WidgetRefresher.backgroundReloadTimeInterval
    }
    
    /// Unchanged values still reload every 15 minutes, so the widget's age never counts far past Fanny's last read.
    /// A clock that moved backward also reloads, so the throttle never waits on a date in the future.
    static func shouldReloadReadings(readings: WidgetReadings, lastReloadedReadings: WidgetReadings?, lastReloadDate: Date?, date: Date, minimumTimeInterval: TimeInterval) -> Bool {
        guard let lastReloadDate: Date = lastReloadDate else { return true }
        
        let elapsedTimeInterval: TimeInterval = date.timeIntervalSince(lastReloadDate)
        let requiredTimeInterval: TimeInterval = readings == lastReloadedReadings ? WidgetRefresher.backgroundReloadTimeInterval : minimumTimeInterval
        return elapsedTimeInterval < 0.0 || elapsedTimeInterval >= requiredTimeInterval
    }
    
    static func containsReadingsWidget(kinds: [String]) -> Bool {
        return kinds.contains(ReadingsSnapshot.widgetKind)
    }
    
    /// The widget converts the unit and hides temperatures itself, so these redraw it before the next read.
    static func changesWidget(from previousSettings: FannySettings?, to settings: FannySettings) -> Bool {
        guard let previousSettings: FannySettings = previousSettings else { return true }
        
        return settings.temperatureUnit != previousSettings.temperatureUnit ||
               settings.showsCPUTemperature != previousSettings.showsCPUTemperature ||
               settings.showsGPUTemperature != previousSettings.showsGPUTemperature ||
               settings.fanNameStyle != previousSettings.fanNameStyle ||
               settings.customFanNames != previousSettings.customFanNames
    }
}

// MARK: - FannySettingsManagerDelegate
extension WidgetRefresher: FannySettingsManagerDelegate {
    
    func fannySettingsManager(_ manager: FannySettingsManager, didUpdateSettings settings: FannySettings) {
        let previousSettings: FannySettings? = self.previousSettings
        self.previousSettings = settings
        
        guard WidgetRefresher.changesWidget(from: previousSettings, to: settings) else { return }
        refreshReadingsForSettingsChange()
    }
}
