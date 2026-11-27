//
//  GetFanSpeedsIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Speaks every fan's speed and returns them as text.
struct GetFanSpeedsIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Get Fan Speeds"
    static var description: IntentDescription = IntentDescription("Hear how fast each fan is spinning.", categoryName: "Readings")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    /// - Note: Dialog text is resolved to a `String` first; an unresolved `LocalizedStringResource` is looked
    ///         up in the presenting process, so every language would fall back to English.
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 GetFanSpeedsIntent -> perform")
        
        AppIntentSupport.track("appIntentGetFanSpeeds")
        let snapshot: ReadingsSnapshot = await SensorMonitor.shared.refreshNow()
        let answer: ReadingFormatter.SpokenText = try AppIntentSupport.fanSpeedsAnswer(snapshot: snapshot, settings: FannySettingsManager.shared.settings)
        return .result(value: answer.text, dialog: IntentDialog("\(answer.spokenText)"))
    }
}
