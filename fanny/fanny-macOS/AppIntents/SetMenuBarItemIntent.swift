//
//  SetMenuBarItemIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Show or hide one item in Fanny's menu bar item.
struct SetMenuBarItemIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Show or Hide in Fanny Menu Bar"
    static var description: IntentDescription = IntentDescription("Choose what Fanny shows in the menu bar.", categoryName: "Settings")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    @Parameter(title: "Show", displayName: Bool.IntentDisplayName(true: "Show", false: "Hide"))
    var isShown: Bool
    
    @Parameter(title: "Item")
    var item: MenuBarItemAppEnum
    
    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$isShown) \(\.$item) in the menu bar")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 SetMenuBarItemIntent -> perform, item: \(item.rawValue), isShown: \(isShown)")
        
        AppIntentSupport.track("appIntentSetMenuBarItem")
        let kind: MenuBarLayout.ItemKind = item.kind
        let isShown: Bool = isShown
        FannySettingsManager.shared.update({ $0.menuBarLayout.setVisible(isShown, kind: kind) })
        let message: String = AppIntentSupport.menuBarItemChangedText(kind, isShown: isShown)
        return .result(dialog: IntentDialog("\(message)"))
    }
}
