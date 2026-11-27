//
//  SetCPUSensorIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Choose which sensor Fanny reads for the CPU temperature.
struct SetCPUSensorIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Set Fanny CPU Sensor"
    static var description: IntentDescription = IntentDescription("Choose which sensor Fanny reads for the CPU temperature.", categoryName: "Settings")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    @Parameter(title: "Sensor")
    var sensor: CPUSensorAppEnum
    
    static var parameterSummary: some ParameterSummary {
        Summary("Read the CPU temperature from \(\.$sensor)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 SetCPUSensorIntent -> perform, sensor: \(sensor.rawValue)")
        
        AppIntentSupport.track("appIntentSetCPUSensor")
        FannySettingsManager.shared.update({ $0.cpuSensorMode = sensor.mode })
        let message: String = AppIntentSupport.cpuSensorChangedText(sensor.mode)
        return .result(dialog: IntentDialog("\(message)"))
    }
}
