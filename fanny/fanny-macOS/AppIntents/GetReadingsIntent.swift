//
//  GetReadingsIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Speaks every reading Fanny shows and returns them as text, one per line.
struct GetReadingsIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Get Readings"
    static var description: IntentDescription = IntentDescription("Hear every fan speed and temperature Fanny shows.", categoryName: "Readings")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 GetReadingsIntent -> perform")
        
        AppIntentSupport.track("appIntentGetReadings")
        let snapshot: ReadingsSnapshot = await SensorMonitor.shared.refreshNow()
        let answer: ReadingFormatter.SpokenText = try AppIntentSupport.readingsAnswer(snapshot: snapshot, settings: FannySettingsManager.shared.settings)
        return .result(value: answer.text, dialog: IntentDialog("\(answer.spokenText)"))
    }
}
