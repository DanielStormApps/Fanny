//
//  CheckForUpdatesIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Checks GitHub for a newer Fanny and says what it found.
struct CheckForUpdatesIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Check for Fanny Updates"
    static var description: IntentDescription = IntentDescription("Check GitHub for a newer version of Fanny.", categoryName: "Settings")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 CheckForUpdatesIntent -> perform")
        
        AppIntentSupport.track("appIntentCheckForUpdates")
        await UpdateChecker.shared.checkNow()
        let updateChecker: UpdateChecker = UpdateChecker.shared
        let message: String = updateChecker.statusText
        
        // A failed check is an error, so a Shortcut never reads it as "no update".
        guard updateChecker.didFailManualCheck == false else { throw ReadingUnavailableError(message: message) }
        
        return .result(value: updateChecker.availableUpdate != nil, dialog: IntentDialog("\(message)"))
    }
}
