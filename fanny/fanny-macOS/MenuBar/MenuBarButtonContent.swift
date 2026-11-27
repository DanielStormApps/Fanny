//
//  MenuBarButtonContent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// What the menu bar button shows for the chosen items: its values, whether the fan icon shows, its tooltip, and what VoiceOver reads.
struct MenuBarButtonContent: Equatable {
    
    /// One value in the menu bar, with a small label under it that names its fan or sensor.
    struct Segment: Equatable {
        let label: String
        let value: String
    }
    
    /// The readings after the icon, in the user's order. Empty when the button shows only the icon.
    let segments: [Segment]
    let showsIcon: Bool
    let toolTip: String
    let accessibilityValue: String
    
    // MARK: - Init
    /// - Parameter snapshot: `nil` until the first read finishes, which shows a dash in place of each value.
    init(snapshot: ReadingsSnapshot?, settings: FannySettings, locale: Locale = Locale.current) {
        let rows: MenuReadingRows = MenuReadingRows.rows(snapshot: snapshot, settings: settings, locale: locale)
        let unit: FannySettings.TemperatureUnit = settings.temperatureUnit
        let fans: [FanReading] = snapshot?.fanStatus == ReadingsSnapshot.FanStatus.fans ? snapshot?.fans ?? [] : []
        let kinds: [MenuBarLayout.ItemKind] = MenuBarButtonContent.visibleKinds(snapshot: snapshot, layout: settings.menuBarLayout, fans: fans)
        var segments: [Segment] = []
        var spokenTexts: [String] = []
        var showsIcon: Bool = false
        
        for kind in kinds {
            switch kind {
            case .icon:
                showsIcon = true
            case .fastestFan:
                // A Mac with no fans has no fastest fan to show.
                guard snapshot?.fanStatus != ReadingsSnapshot.FanStatus.noFans else { continue }
                let fastestFan: FanReading? = snapshot?.fastestFan
                let fastestFanTitle: String = String(localized: "Fastest fan", comment: "Spoken by VoiceOver before the speed of the fastest fan, which the menu bar shows.")
                let label: String = String(localized: "RPM", comment: "Menu bar: small label under the speed of the fastest fan, the unit revolutions per minute.")
                segments.append(Segment(label: label, value: ReadingFormatter.compactFanSpeedText(fastestFan, locale: locale)))
                spokenTexts.append("\(fastestFanTitle), \(ReadingFormatter.spokenFanSpeedText(fastestFan, locale: locale))")
            case .fan(let fanID):
                // Until a read finds the fans, a chosen fan keeps its place with a dash.
                let fan: FanReading? = fans.first(where: { $0.id == fanID })
                let name: String = ReadingFormatter.fanName(id: fanID, settings: settings)
                segments.append(Segment(label: name, value: ReadingFormatter.compactFanSpeedText(fan, locale: locale)))
                spokenTexts.append("\(name), \(ReadingFormatter.spokenFanSpeedText(fan, locale: locale))")
            case .cpu:
                // A temperature turned off in Sensors is not read, so it leaves the menu bar like it leaves the menu.
                guard settings.showsCPUTemperature else { continue }
                segments.append(Segment(label: ReadingFormatter.cpuTitle, value: ReadingFormatter.temperatureText(snapshot?.cpuTemperature, unit: unit, style: .compact, locale: locale)))
                spokenTexts.append("\(ReadingFormatter.cpuTitle), \(ReadingFormatter.spokenTemperatureText(snapshot?.cpuTemperature, unit: unit, style: .compact, locale: locale))")
            case .gpu:
                guard settings.showsGPUTemperature else { continue }
                segments.append(Segment(label: ReadingFormatter.gpuTitle, value: ReadingFormatter.temperatureText(snapshot?.gpuTemperature, unit: unit, style: .compact, locale: locale)))
                spokenTexts.append("\(ReadingFormatter.gpuTitle), \(ReadingFormatter.spokenTemperatureText(snapshot?.gpuTemperature, unit: unit, style: .compact, locale: locale))")
            }
        }
        
        self.segments = segments
        // The icon comes back when nothing else would show, so the item never disappears from the menu bar.
        self.showsIcon = showsIcon || segments.isEmpty
        accessibilityValue = spokenTexts.isEmpty ? rows.summaryRows.map({ $0.accessibilityText }).joined(separator: ". ") : spokenTexts.joined(separator: ". ")
        toolTip = rows.summaryRows.map({ MenuBarButtonContent.toolTipLine(for: $0) }).joined(separator: "\n")
    }
    
    // MARK: - Items
    /// The fans a read found, none on a Mac without fans, and every saved fan before the fans are known, so a launch or a failed read never drops them.
    private static func visibleKinds(snapshot: ReadingsSnapshot?, layout: MenuBarLayout, fans: [FanReading]) -> [MenuBarLayout.ItemKind] {
        let kinds: [MenuBarLayout.ItemKind]
        
        switch snapshot?.fanStatus {
        case .fans:
            kinds = layout.visibleKinds(fanIDs: fans.map({ $0.id }))
        case .noFans:
            kinds = layout.visibleKinds(fanIDs: [])
        case .unavailable, .none:
            kinds = layout.normalized(fanIDs: []).items.filter({ $0.isVisible }).map({ $0.kind })
        }
        
        return kinds
    }
    
    // MARK: - Tooltip
    private static func toolTipLine(for row: MenuReadingRows.Row) -> String {
        let line: String
        
        if let value: String = row.value {
            let title: String = row.title
            line = String(localized: "\(title): \(value)", comment: "Menu bar tooltip: one line per reading, such as Fan 1: 1350 RPM or CPU: 45.2°C. The first argument is the name, the second the value.")
        }
        else {
            line = row.title
        }
        
        return line
    }
}
