//
//  FNYMonitor.swift
//  Fanny
//
//  Created by Daniel Storm on 9/15/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation

protocol FNYMonitorDelegate {
    func monitorDidRefreshSystemStats(_ monitor: FNYMonitor)
}

class FNYMonitor {
    
    var delegate: FNYDelegateMulticast<FNYMonitorDelegate> = FNYDelegateMulticast<FNYMonitorDelegate>()
    
    var refreshTimeInterval: TimeInterval = FNYUserPreferences.monitorRefreshTimeIntervalOption().timeInterval {
        didSet { restart() }
    }
    
    private var refreshTimer: Timer?
    
    // MARK: - Init
    private init() {}
    static let shared: FNYMonitor = FNYMonitor()
    
    // MARK: - Start
    func start() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(timeInterval: refreshTimeInterval,
                                            target: self,
                                            selector: #selector(refresh),
                                            userInfo: nil,
                                            repeats: true)
    }
    
    // MARK: - Stop
    func stop() {
        guard
            let timer: Timer = refreshTimer,
            timer.isValid
            else { return }
        
        timer.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Restart
    private func restart() {
        stop()
        start()
    }
    
    // MARK: - Refresh
    func refreshSystemStats() {
        refresh()
    }
    
    @objc private func refresh() {
        #if APP_EXTENSION
            //
        #else
            let fans: [Fan] = SMC.shared.fans()
            let cpuTemperature: Temperature? = .cpu()
            let gpuTemperature: Temperature? = .gpu()
        
            updateLocalStorageSystemStats((fans: fans, cpuTemperature: cpuTemperature, gpuTemperature: gpuTemperature))
        #endif
        
        delegate.invoke({ $0.monitorDidRefreshSystemStats(self) })
    }
    
    // MARK: - Save
    private func updateLocalStorageSystemStats(_ stats: (fans: [Fan], cpuTemperature: Temperature?, gpuTemperature: Temperature?)) {
        FNYLocalStorage.save(fans: stats.fans)
        FNYLocalStorage.save(cpuTemperature: stats.cpuTemperature)
        FNYLocalStorage.save(gpuTemperature: stats.gpuTemperature)
    }
    
}
