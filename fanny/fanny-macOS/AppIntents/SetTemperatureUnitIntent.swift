//
//  SetTemperatureUnitIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Choose the unit Fanny shows temperatures in.
struct SetTemperatureUnitIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Set Fanny Temperature Unit"
    static var description: IntentDescription = IntentDescription("Choose the unit Fanny shows temperatures in.", categoryName: "Settings")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    @Parameter(title: "Unit")
    var unit: TemperatureUnitAppEnum
    
    static var parameterSummary: some ParameterSummary {
        Summary("Show temperatures in \(\.$unit)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 SetTemperatureUnitIntent -> perform, unit: \(unit.rawValue)")
        
        AppIntentSupport.track("appIntentSetTemperatureUnit")
        FannySettingsManager.shared.update({ $0.temperatureUnit = unit.unit })
        let message: String = AppIntentSupport.temperatureUnitChangedText(unit.unit)
        return .result(dialog: IntentDialog("\(message)"))
    }
}
