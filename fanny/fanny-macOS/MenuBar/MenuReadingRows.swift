//
//  MenuReadingRows.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation
import SFSafeSymbols

/// The read only rows at the top of the menu, built from one snapshot so the menu, tooltip, and VoiceOver always agree.
struct MenuReadingRows: Equatable {
    
    /// One disabled menu row.
    struct Row: Equatable {
        
        enum Style: Equatable {
            /// A title with a right aligned value, such as "Fan 1" and "1350 RPM".
            case reading
            /// A secondary line under a fan, such as its minimum and maximum.
            case detail
            /// A single line in place of the fan rows, such as "This Mac Has No Fans".
            case message
        }
        
        let style: Style
        let title: String
        /// `nil` for detail and message rows.
        let value: String?
        let accessibilityText: String
        let symbol: SFSymbol?
    }
    
    let fanRows: [Row]
    let temperatureRows: [Row]
    
    // MARK: - Rows
    /// - Parameter snapshot: `nil` until the first read finishes.
    static func rows(snapshot: ReadingsSnapshot?, settings: FannySettings, locale: Locale = Locale.current) -> MenuReadingRows {
        return MenuReadingRows(fanRows: fanRows(snapshot: snapshot, settings: settings, locale: locale), temperatureRows: temperatureRows(snapshot: snapshot, settings: settings, locale: locale))
    }
    
    /// The rows that carry a value, plus any message, so the tooltip and the menu bar's VoiceOver value skip the detail lines.
    var summaryRows: [Row] {
        return (fanRows + temperatureRows).filter({ $0.style != Row.Style.detail })
    }
    
    /// The same rows in the same order, so an open menu can update its values in place instead of being rebuilt.
    /// - Note: Detail titles hold values, so only reading and message titles have to match.
    func hasSameLayout(as rows: MenuReadingRows) -> Bool {
        return MenuReadingRows.layoutKeys(of: self) == MenuReadingRows.layoutKeys(of: rows)
    }
    
    private static func layoutKeys(of rows: MenuReadingRows) -> [String] {
        return (rows.fanRows + rows.temperatureRows).map({ $0.style == Row.Style.detail ? "detail" : $0.title })
    }
    
    private static func fanRows(snapshot: ReadingsSnapshot?, settings: FannySettings, locale: Locale) -> [Row] {
        var rows: [Row] = []
        
        guard let snapshot: ReadingsSnapshot = snapshot else {
            let title: String = String(localized: "Reading Sensors...", comment: "Menu: disabled row shown for a moment at launch, before the first fan and temperature read finishes.")
            rows.append(Row(style: .message, title: title, value: nil, accessibilityText: title, symbol: .fan))
            return rows
        }
        
        switch snapshot.fanStatus {
        case .fans:
            for fan in snapshot.fans {
                rows.append(fanRow(fan, settings: settings, locale: locale))
                
                if let detailRow: Row = fanDetailRow(fan, locale: locale) {
                    rows.append(detailRow)
                }
            }
        case .noFans:
            let title: String = String(localized: "This Mac Has No Fans", comment: "Menu: disabled row on a Mac without fans, such as a MacBook Air.")
            rows.append(Row(style: .message, title: title, value: nil, accessibilityText: title, symbol: .fan))
        case .unavailable:
            let title: String = String(localized: "Readings Unavailable", comment: "Menu: disabled row when the fan speeds could not be read.")
            rows.append(Row(style: .message, title: title, value: nil, accessibilityText: title, symbol: .exclamationmarkTriangle))
        }
        
        return rows
    }
    
    private static func fanRow(_ fan: FanReading, settings: FannySettings, locale: Locale) -> Row {
        let title: String = ReadingFormatter.fanName(id: fan.id, settings: settings)
        let spokenValue: String = ReadingFormatter.spokenFanSpeedText(fan, locale: locale)
        return Row(style: .reading, title: title, value: ReadingFormatter.fanSpeedText(fan, locale: locale), accessibilityText: "\(title), \(spokenValue)", symbol: .fan)
    }
    
    /// Shows only the limits the fan reports, and no row at all when it reports none.
    private static func fanDetailRow(_ fan: FanReading, locale: Locale) -> Row? {
        guard let limitsText: ReadingFormatter.SpokenText = ReadingFormatter.fanLimitsText(fan, locale: locale) else { return nil }
        return Row(style: .detail, title: limitsText.text, value: nil, accessibilityText: limitsText.spokenText, symbol: nil)
    }
    
    /// Hidden temperatures disappear entirely rather than showing a dash.
    private static func temperatureRows(snapshot: ReadingsSnapshot?, settings: FannySettings, locale: Locale) -> [Row] {
        var rows: [Row] = []
        let unit: FannySettings.TemperatureUnit = settings.temperatureUnit
        
        if settings.showsCPUTemperature {
            let title: String = ReadingFormatter.cpuTitle
            let spokenValue: String = ReadingFormatter.spokenTemperatureText(snapshot?.cpuTemperature, unit: unit, style: .full, locale: locale)
            rows.append(Row(style: .reading, title: title, value: ReadingFormatter.temperatureText(snapshot?.cpuTemperature, unit: unit, style: .full, locale: locale), accessibilityText: "\(title), \(spokenValue)", symbol: .cpu))
        }
        
        if settings.showsGPUTemperature {
            let title: String = ReadingFormatter.gpuTitle
            let spokenValue: String = ReadingFormatter.spokenTemperatureText(snapshot?.gpuTemperature, unit: unit, style: .full, locale: locale)
            rows.append(Row(style: .reading, title: title, value: ReadingFormatter.temperatureText(snapshot?.gpuTemperature, unit: unit, style: .full, locale: locale), accessibilityText: "\(title), \(spokenValue)", symbol: .thermometerMedium))
        }
        
        return rows
    }
}
