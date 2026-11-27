//
//  GetFanSpeedIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Speaks one fan's speed and returns it in RPM, 0 when the fan is off.
struct GetFanSpeedIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Get Fan Speed"
    static var description: IntentDescription = IntentDescription("Get how fast one fan is spinning, in revolutions per minute.", categoryName: "Readings")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    @Parameter(title: "Fan")
    var fan: FanEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get the speed of \(\.$fan)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 GetFanSpeedIntent -> perform, fan: \(fan.id)")
        
        AppIntentSupport.track("appIntentGetFanSpeed")
        let snapshot: ReadingsSnapshot = await SensorMonitor.shared.refreshNow()
        let answer: AppIntentSupport.FanSpeedAnswer = try AppIntentSupport.fanSpeedAnswer(fanID: fan.id, snapshot: snapshot, settings: FannySettingsManager.shared.settings)
        return .result(value: answer.rpm, dialog: IntentDialog("\(answer.spokenText)"))
    }
}
