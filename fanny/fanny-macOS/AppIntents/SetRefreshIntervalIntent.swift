//
//  SetRefreshIntervalIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Choose how often Fanny reads the fans and temperatures.
struct SetRefreshIntervalIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Set Fanny Refresh Interval"
    static var description: IntentDescription = IntentDescription("Choose how often Fanny reads the fans and temperatures.", categoryName: "Settings")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    @Parameter(title: "Seconds", inclusiveRange: (1, 60))
    var seconds: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Refresh every \(\.$seconds) seconds")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 SetRefreshIntervalIntent -> perform, seconds: \(seconds)")
        
        AppIntentSupport.track("appIntentSetRefreshInterval")
        let timeInterval: TimeInterval = FannySettings.clampedRefreshTimeInterval(TimeInterval(seconds))
        FannySettingsManager.shared.update({ $0.refreshTimeInterval = timeInterval })
        let message: String = AppIntentSupport.refreshIntervalChangedText(timeInterval)
        return .result(dialog: IntentDialog("\(message)"))
    }
}
