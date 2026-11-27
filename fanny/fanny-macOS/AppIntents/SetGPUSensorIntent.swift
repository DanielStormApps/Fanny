//
//  SetGPUSensorIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Choose which sensor Fanny reads for the GPU temperature.
struct SetGPUSensorIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Set Fanny GPU Sensor"
    static var description: IntentDescription = IntentDescription("Choose which sensor Fanny reads for the GPU temperature.", categoryName: "Settings")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    @Parameter(title: "Sensor")
    var sensor: GPUSensorAppEnum
    
    static var parameterSummary: some ParameterSummary {
        Summary("Read the GPU temperature from \(\.$sensor)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 SetGPUSensorIntent -> perform, sensor: \(sensor.rawValue)")
        
        AppIntentSupport.track("appIntentSetGPUSensor")
        FannySettingsManager.shared.update({ $0.gpuSensorMode = sensor.mode })
        let message: String = AppIntentSupport.gpuSensorChangedText(sensor.mode)
        return .result(dialog: IntentDialog("\(message)"))
    }
}
