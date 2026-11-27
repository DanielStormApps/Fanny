//
//  GetCPUTemperatureIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Speaks the CPU temperature and returns it in the unit chosen in Settings.
struct GetCPUTemperatureIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Get CPU Temperature"
    static var description: IntentDescription = IntentDescription("Hear the CPU temperature in the unit chosen in Fanny's settings.", categoryName: "Readings")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    /// - Note: Dialog text is resolved to a `String` first; an unresolved `LocalizedStringResource` is looked
    ///         up in the presenting process, so every language would fall back to English.
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 GetCPUTemperatureIntent -> perform")
        
        AppIntentSupport.track("appIntentGetCPUTemperature")
        let snapshot: ReadingsSnapshot = await SensorMonitor.shared.refreshNow()
        let answer: AppIntentSupport.TemperatureAnswer = try AppIntentSupport.temperatureAnswer(.cpu, snapshot: snapshot, settings: FannySettingsManager.shared.settings)
        return .result(value: answer.value, dialog: IntentDialog("\(answer.spokenText)"))
    }
}
