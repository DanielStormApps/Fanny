//
//  SensorMonitor.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

// MARK: - SensorMonitorDelegate
/// Listeners told when the readings change in a way the menu bar, menu, or widget shows.
protocol SensorMonitorDelegate: AnyObject {
    func sensorMonitor(_ monitor: SensorMonitor, didUpdateSnapshot snapshot: ReadingsSnapshot)
}

// MARK: - SensorMonitor
/// Singleton that reads the sensors on a timer, keeps the latest snapshot, and saves it for the widget.
/// - Note: Everything runs on the main thread. The reader reads on its own queue and calls back on the main thread.
final class SensorMonitor {
    
    /// The values a person can see, so a change below what the UI rounds to tells no one.
    struct DisplayedReadings: Equatable {
        
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
        let cpuTemperatures: [FannySettings.CPUSensorMode: Double]
        let gpuTemperatures: [FannySettings.GPUSensorMode: Double]
        
        // MARK: - Init
        /// Whole RPM, and temperatures to one decimal in the chosen unit, like the menu rows and the floating window.
        init(snapshot: ReadingsSnapshot, unit: FannySettings.TemperatureUnit) {
            fanStatus = snapshot.fanStatus
            fans = snapshot.fans.map({ Fan(id: $0.id, isStopped: $0.isStopped, currentRPM: $0.currentRPM.rounded(), minimumRPM: $0.minimumRPM?.rounded(), maximumRPM: $0.maximumRPM?.rounded(), targetRPM: $0.targetRPM?.rounded()) })
            cpuTemperature = snapshot.cpuTemperature.map({ DisplayedReadings.roundedTemperature($0, unit: unit) })
            gpuTemperature = snapshot.gpuTemperature.map({ DisplayedReadings.roundedTemperature($0, unit: unit) })
            cpuTemperatures = (snapshot.cpuTemperatures ?? [:]).mapValues({ DisplayedReadings.roundedTemperature($0, unit: unit) })
            gpuTemperatures = (snapshot.gpuTemperatures ?? [:]).mapValues({ DisplayedReadings.roundedTemperature($0, unit: unit) })
        }
        
        private static func roundedTemperature(_ temperature: TemperatureReading, unit: FannySettings.TemperatureUnit) -> Double {
            return (temperature.value(in: unit) * 10.0).rounded() / 10.0
        }
    }
    
    let delegate: DelegateMulticast<SensorMonitorDelegate> = DelegateMulticast<SensorMonitorDelegate>()
    
    /// `nil` until the first read finishes.
    private(set) var snapshot: ReadingsSnapshot?
    
    private var isStarted: Bool = false
    private var isSleeping: Bool = false
    private var isMenuOpen: Bool = false
    private var isReading: Bool = false
    private var needsAnotherRead: Bool = false
    private var refreshTimer: Timer?
    private var lastSavedDate: Date?
    private var previousSettings: FannySettings?
    /// Set by a settings change that alters what is read, so the read it starts reaches the delegates even when the values look the same.
    private var notifiesNextSnapshot: Bool = false
    private var pendingCompletions: [(ReadingsSnapshot) -> Void] = []
    
    private let reader: SensorReader = SensorReader()
    
    private static let menuRefreshTimeInterval: TimeInterval = 1.0
    private static let refreshToleranceRatio: Double = 0.1
    /// The widget shows minutes, so an unchanged snapshot is saved again only this often to keep its date current.
    private static let unchangedSnapshotSaveTimeInterval: TimeInterval = 60.0
    
    // MARK: - Init
    private init() {}
    static let shared: SensorMonitor = SensorMonitor()
    
    // MARK: - Start
    /// Starts the first read and the refresh timer. Later calls do nothing.
    func start() {
        guard isStarted == false else {
            Log.debug("🌀 SensorMonitor start -> already started")
            return
        }
        
        isStarted = true
        let settings: FannySettings = FannySettingsManager.shared.settings
        previousSettings = settings
        FannySettingsManager.shared.delegate.add(self)
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willTerminate(_:)), name: NSApplication.willTerminateNotification, object: nil)
        
        Log.info("🌀 SensorMonitor start -> refreshTimeInterval: \(settings.refreshTimeInterval)")
        refresh()
        startRefreshTimer()
    }
    
    // MARK: - Refresh
    /// Reads now instead of waiting for the timer, and calls `completion` on the main thread.
    private func refreshNow(completion: @escaping (ReadingsSnapshot) -> Void) {
        pendingCompletions.append(completion)
        refresh()
    }
    
    /// Reads now for Shortcuts instead of waiting for the timer. A read already in flight answers instead of starting another.
    @MainActor
    func refreshNow() async -> ReadingsSnapshot {
        return await withCheckedContinuation { continuation in
            refreshNow { snapshot in
                continuation.resume(returning: snapshot)
            }
        }
    }
    
    /// A read already in flight finishes first, then one more read picks up any settings change made meanwhile.
    private func refresh() {
        guard isReading == false else {
            needsAnotherRead = true
            return
        }
        
        isReading = true
        reader.readSnapshot(settings: FannySettingsManager.shared.settings) { [weak self] snapshot in
            guard let strongSelf: SensorMonitor = self else { return }
            strongSelf.isReading = false
            strongSelf.handleSnapshot(snapshot)
            
            if strongSelf.needsAnotherRead {
                strongSelf.needsAnotherRead = false
                strongSelf.refresh()
            }
        }
    }
    
    private func handleSnapshot(_ updatedSnapshot: ReadingsSnapshot) {
        let previousSnapshot: ReadingsSnapshot? = snapshot
        let unit: FannySettings.TemperatureUnit = FannySettingsManager.shared.settings.temperatureUnit
        let isVisibleChange: Bool = SensorMonitor.isVisibleChange(from: previousSnapshot, to: updatedSnapshot, unit: unit)
        snapshot = updatedSnapshot
        
        if previousSnapshot?.fanStatus != updatedSnapshot.fanStatus {
            Log.info("🌀 fanStatus -> \(updatedSnapshot.fanStatus.rawValue), count: \(updatedSnapshot.fans.count)")
        }
        
        #if DEBUG
            let fanText: String = updatedSnapshot.fans.map({ "\(Int($0.currentRPM.rounded()))" }).joined(separator: ", ")
            Log.debug("🌡️ read -> fans: [\(fanText)], cpu: \(updatedSnapshot.cpuTemperature?.celsius ?? -1.0), gpu: \(updatedSnapshot.gpuTemperature?.celsius ?? -1.0), changed: \(isVisibleChange)")
        #endif
        
        if SensorMonitor.shouldSaveSnapshot(isVisibleChange: isVisibleChange, lastSavedDate: lastSavedDate, date: updatedSnapshot.capturedDate) {
            updatedSnapshot.save()
            lastSavedDate = updatedSnapshot.capturedDate
        }
        
        // After the save, because the widget reads the saved snapshot. A change held back by the throttle is picked up by a later read.
        WidgetRefresher.shared.refreshReadingsIfNeeded(snapshot: updatedSnapshot)
        
        let completions: [(ReadingsSnapshot) -> Void] = pendingCompletions
        pendingCompletions = []
        
        for completion in completions {
            completion(updatedSnapshot)
        }
        
        let isSettingsRead: Bool = notifiesNextSnapshot
        notifiesNextSnapshot = false
        guard isVisibleChange || isSettingsRead else { return }
        delegate.invoke({ $0.sensorMonitor(self, didUpdateSnapshot: updatedSnapshot) })
    }
    
    // MARK: - Developer Menu
    /// Reads every known fan, CPU, and GPU key, alongside the regular reads, for the Developer Menu.
    func readDiagnostics(completion: @escaping (SensorReader.Diagnostics) -> Void) {
        reader.readDiagnostics(settings: FannySettingsManager.shared.settings, completion: completion)
    }
    
    // MARK: - Menu
    /// The open menu refreshes every second, so it doubles as a manual refresh.
    func menuWillOpen() {
        guard isMenuOpen == false else { return }
        isMenuOpen = true
        refresh()
        startRefreshTimer()
    }
    
    func menuDidClose() {
        guard isMenuOpen else { return }
        isMenuOpen = false
        startRefreshTimer()
    }
    
    // MARK: - Timer
    private func startRefreshTimer() {
        stopRefreshTimer()
        guard isStarted, isSleeping == false else { return }
        
        let timeInterval: TimeInterval = SensorMonitor.refreshTimeInterval(settingsTimeInterval: FannySettingsManager.shared.settings.refreshTimeInterval, isMenuOpen: isMenuOpen)
        let timer: Timer = Timer(timeInterval: timeInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = timeInterval * SensorMonitor.refreshToleranceRatio
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Notifications
    @objc private func willSleep(_ notification: Notification) {
        isSleeping = true
        stopRefreshTimer()
        Log.info("🌀 SensorMonitor willSleep -> reads stopped")
    }
    
    /// The SMC connection can go stale across sleep, so the reader reopens it and lists the keys again.
    @objc private func didWake(_ notification: Notification) {
        isSleeping = false
        reader.reset()
        Log.info("🌀 SensorMonitor didWake -> reads restarted")
        refresh()
        startRefreshTimer()
    }
    
    /// Marks the saved snapshot as stopped, so the widget dims and asks for a click to refresh instead of counting up forever.
    @objc private func willTerminate(_ notification: Notification) {
        guard var stoppedSnapshot: ReadingsSnapshot = snapshot else { return }
        stoppedSnapshot.stoppedDate = Date()
        stoppedSnapshot.save()
        WidgetRefresher.shared.reloadForTermination()
        Log.info("🌀 SensorMonitor willTerminate -> snapshot marked stopped")
    }
    
    // MARK: - Helpers
    static func refreshTimeInterval(settingsTimeInterval: TimeInterval, isMenuOpen: Bool) -> TimeInterval {
        return isMenuOpen ? min(settingsTimeInterval, SensorMonitor.menuRefreshTimeInterval) : settingsTimeInterval
    }
    
    /// The first snapshot always counts as a change.
    static func isVisibleChange(from previousSnapshot: ReadingsSnapshot?, to snapshot: ReadingsSnapshot, unit: FannySettings.TemperatureUnit) -> Bool {
        guard let previousSnapshot: ReadingsSnapshot = previousSnapshot else { return true }
        return DisplayedReadings(snapshot: previousSnapshot, unit: unit) != DisplayedReadings(snapshot: snapshot, unit: unit)
    }
    
    /// A clock that moved backward also saves, so the widget never keeps a snapshot dated in the future.
    static func shouldSaveSnapshot(isVisibleChange: Bool, lastSavedDate: Date?, date: Date) -> Bool {
        guard isVisibleChange == false, let lastSavedDate: Date = lastSavedDate else { return true }
        let elapsedTimeInterval: TimeInterval = date.timeIntervalSince(lastSavedDate)
        return elapsedTimeInterval < 0.0 || elapsedTimeInterval >= SensorMonitor.unchangedSnapshotSaveTimeInterval
    }
}

// MARK: - FannySettingsManagerDelegate
extension SensorMonitor: FannySettingsManagerDelegate {
    
    func fannySettingsManager(_ manager: FannySettingsManager, didUpdateSettings settings: FannySettings) {
        let previousSettings: FannySettings? = self.previousSettings
        self.previousSettings = settings
        
        if settings.refreshTimeInterval != previousSettings?.refreshTimeInterval {
            Log.info("🌀 SensorMonitor refreshTimeInterval -> \(settings.refreshTimeInterval)")
            startRefreshTimer()
        }
        
        guard SensorMonitor.changesReadings(from: previousSettings, to: settings) else { return }
        notifiesNextSnapshot = true
        refresh()
    }
    
    /// Sensor modes, hidden temperatures, and floating window cards change what the reader reads, so they need a new read right away.
    static func changesReadings(from previousSettings: FannySettings?, to settings: FannySettings) -> Bool {
        guard let previousSettings: FannySettings = previousSettings else { return true }
        
        return settings.cpuSensorMode != previousSettings.cpuSensorMode ||
               settings.gpuSensorMode != previousSettings.gpuSensorMode ||
               settings.showsCPUTemperature != previousSettings.showsCPUTemperature ||
               settings.showsGPUTemperature != previousSettings.showsGPUTemperature ||
               settings.cpuModesToRead != previousSettings.cpuModesToRead ||
               settings.gpuModesToRead != previousSettings.gpuModesToRead
    }
}
