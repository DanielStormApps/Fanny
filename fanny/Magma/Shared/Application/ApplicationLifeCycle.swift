//
//  ApplicationLifeCycle.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A shared instance class that responds to application life cycle events.
final class ApplicationLifeCycle {
    
    private(set) var applicationDidFinishLaunchingTimestamp: String?
    
    private var heartbeatTimer: Timer?
    private var heartbeatTimeInterval: TimeInterval {
        return TimeInterval(ConfigManager.shared.config.analytics?.heartbeatTimeInterval ?? 600)
    }
    
    private static let dateFormatter: DateFormatter = {
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS Z"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        return dateFormatter
    }()
    
    // MARK: - Init
    private init() {}
    static let shared: ApplicationLifeCycle = ApplicationLifeCycle()
}

extension ApplicationLifeCycle {
    
    // MARK: - Heartbeat Analytics
    private func startHeartbeatTimer() {
        guard heartbeatTimer == nil else { return }
        heartbeatTimer = Timer.scheduledTimer(timeInterval: heartbeatTimeInterval,
                                              target: self,
                                              selector: #selector(trackHeartbeatEvent),
                                              userInfo: nil,
                                              repeats: true)
    }
    
    private func stopHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    @objc private func trackHeartbeatEvent() {
        Analytics.shared.track(event: HeartbeatEvent())
    }
}

// MARK: - ApplicationDelegate
extension ApplicationLifeCycle: ApplicationDelegate {
    
    func applicationDidFinishLaunching() {
        Log.info("📲 applicationDidFinishLaunching")
        applicationDidFinishLaunchingTimestamp = ApplicationLifeCycle.dateFormatter.string(from: Date())
        Analytics.shared.track(event: AppEvent(eventType: .launch))
    }
    
    func applicationDidBecomeActive() {
        Log.info("📲 applicationDidBecomeActive")
        startHeartbeatTimer()
    }
    
    func applicationWillResignActive() {
        Log.info("📲 applicationWillResignActive")
    }
    
    func applicationDidResignActive() {
        Log.info("📲 applicationDidResignActive")
        stopHeartbeatTimer()
    }
    
    func applicationWillTerminate() {
        Log.info("📲 applicationWillTerminate")
    }
}
