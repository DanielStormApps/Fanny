//
//  FloatingWindowContent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation
import SFSafeSymbols

/// The cards and rows the floating window draws, built from the layout and the latest snapshot so the view only lays them out.
struct FloatingWindowContent: Equatable {
    
    struct Row: Equatable {
        
        enum Style: Equatable {
            case value(String)
            /// From 0.0 at the fan's minimum to 1.0 at its maximum. `nil` when the fan does not report both.
            case bar(Double?)
        }
        
        let stat: FloatingWindowLayout.Stat
        let title: String
        let style: Style
        let spokenText: String
    }
    
    struct Card: Equatable {
        let kind: FloatingWindowLayout.CardKind
        let title: String
        let symbol: SFSymbol
        let rows: [Row]
        /// The stats the card shows when its temperature is on, so a turned off card keeps the same height.
        let reservedStats: [FloatingWindowLayout.Stat]
        /// The temperature is turned off in the Sensors pane, so it is not read and the card says so instead of showing rows.
        let isTurnedOff: Bool
        
        var spokenText: String {
            let parts: [String] = isTurnedOff ? [FloatingWindowContent.turnedOffSpokenText] : rows.map({ $0.spokenText })
            return ([title] + parts).joined(separator: ", ")
        }
        
        init(kind: FloatingWindowLayout.CardKind, title: String, symbol: SFSymbol, rows: [Row], isTurnedOff: Bool = false) {
            self.kind = kind
            self.title = title
            self.symbol = symbol
            self.rows = isTurnedOff ? [] : rows
            reservedStats = rows.map({ $0.stat })
            self.isTurnedOff = isTurnedOff
        }
    }
    
    let orientation: FloatingWindowLayout.Orientation
    let cards: [Card]
    
    var spokenText: String {
        return cards.isEmpty ? FloatingWindowContent.emptyText : cards.map({ $0.spokenText }).joined(separator: ". ")
    }
    
    static var turnedOffText: String {
        return String(localized: "Turned Off", comment: "Floating window: shown on the CPU or GPU card when that temperature is turned off in the Sensors pane.")
    }
    
    private static var turnedOffSpokenText: String {
        return String(localized: "Turned off in Fanny's Sensors settings", comment: "Spoken by VoiceOver for a floating window card whose temperature is turned off in the Sensors pane (keep Fanny).")
    }
    
    static var emptyText: String {
        return String(localized: "No Readings Selected", comment: "Floating window: shown when every card or stat is hidden in Settings.")
    }
    
    // MARK: - Init
    init(orientation: FloatingWindowLayout.Orientation, cards: [Card]) {
        self.orientation = orientation
        self.cards = cards
    }
    
    /// Fan cards appear once a read finds the fans, so a Mac without fans never shows one.
    init(snapshot: ReadingsSnapshot?, settings: FannySettings, locale: Locale = Locale.current) {
        let fans: [FanReading] = snapshot?.fanStatus == ReadingsSnapshot.FanStatus.fans ? (snapshot?.fans ?? []) : []
        let layoutCards: [FloatingWindowLayout.Card] = settings.floatingWindowLayout.visibleCards(fanIDs: fans.map({ $0.id }))
        
        orientation = settings.floatingWindowLayout.orientation
        cards = layoutCards.map({ card in
            let fan: FanReading? = fans.first(where: { FloatingWindowLayout.CardKind.fan(id: $0.id) == card.kind })
            let rows: [Row] = card.visibleStats.map({ FloatingWindowContent.row(for: $0, fan: fan, snapshot: snapshot, settings: settings, locale: locale) })
            return Card(kind: card.kind, title: FloatingWindowContent.title(for: card.kind, settings: settings), symbol: FloatingWindowContent.symbol(for: card.kind), rows: rows, isTurnedOff: FloatingWindowContent.isTurnedOff(card.kind, settings: settings))
        })
    }
    
    /// A temperature turned off in the Sensors pane is never read, so its card reflects that rather than showing dashes.
    static func isTurnedOff(_ kind: FloatingWindowLayout.CardKind, settings: FannySettings) -> Bool {
        let isTurnedOff: Bool
        
        switch kind {
        case .cpu:
            isTurnedOff = settings.showsCPUTemperature == false
        case .gpu:
            isTurnedOff = settings.showsGPUTemperature == false
        case .fan:
            isTurnedOff = false
        }
        
        return isTurnedOff
    }
    
    // MARK: - Rows
    private static func row(for stat: FloatingWindowLayout.Stat, fan: FanReading?, snapshot: ReadingsSnapshot?, settings: FannySettings, locale: Locale) -> Row {
        let title: String = FloatingWindowContent.title(for: stat)
        let style: Row.Style
        let spokenValue: String
        
        switch stat {
        case .cpuTemperature, .cpuAverage, .cpuHottest, .cpuDie, .gpuTemperature, .gpuAverage, .gpuHottest:
            let temperature: TemperatureReading? = FloatingWindowContent.temperature(for: stat, snapshot: snapshot, settings: settings)
            style = Row.Style.value(ReadingFormatter.temperatureText(temperature, unit: settings.temperatureUnit, style: .compact, locale: locale))
            spokenValue = ReadingFormatter.spokenTemperatureText(temperature, unit: settings.temperatureUnit, style: .compact, locale: locale)
        case .fanSpeed:
            style = Row.Style.value(ReadingFormatter.fanSpeedText(fan, locale: locale))
            spokenValue = ReadingFormatter.spokenFanSpeedText(fan, locale: locale)
        case .fanSpeedBar:
            let fraction: Double? = fan?.speedFraction
            style = Row.Style.bar(fraction)
            spokenValue = fraction.map({ $0.formatted(FloatingPointFormatStyle<Double>.Percent(locale: locale).precision(.fractionLength(0))) }) ?? ReadingFormatter.spokenFanSpeedText(nil, locale: locale)
        case .fanTarget, .fanMinimum, .fanMaximum:
            let rpm: Double? = FloatingWindowContent.rpm(for: stat, fan: fan)
            style = Row.Style.value(rpm.map({ ReadingFormatter.rpmText($0, locale: locale) }) ?? ReadingFormatter.missingText)
            spokenValue = rpm.map({ ReadingFormatter.spokenRPMText($0, locale: locale) }) ?? ReadingFormatter.spokenFanSpeedText(nil, locale: locale)
        }
        
        return Row(stat: stat, title: title, style: style, spokenText: "\(title), \(spokenValue)")
    }
    
    private static func temperature(for stat: FloatingWindowLayout.Stat, snapshot: ReadingsSnapshot?, settings: FannySettings) -> TemperatureReading? {
        let cpuTemperatures: [FannySettings.CPUSensorMode: TemperatureReading] = snapshot?.cpuTemperatures ?? [:]
        let gpuTemperatures: [FannySettings.GPUSensorMode: TemperatureReading] = snapshot?.gpuTemperatures ?? [:]
        let temperature: TemperatureReading?
        
        if let mode: FannySettings.CPUSensorMode = stat.cpuSensorMode(selectedMode: settings.cpuSensorMode) {
            temperature = cpuTemperatures[mode]
        }
        else if let mode: FannySettings.GPUSensorMode = stat.gpuSensorMode(selectedMode: settings.gpuSensorMode) {
            temperature = gpuTemperatures[mode]
        }
        else {
            temperature = nil
        }
        
        return temperature
    }
    
    private static func rpm(for stat: FloatingWindowLayout.Stat, fan: FanReading?) -> Double? {
        let rpm: Double?
        
        switch stat {
        case .fanTarget: rpm = fan?.targetRPM
        case .fanMinimum: rpm = fan?.minimumRPM
        case .fanMaximum: rpm = fan?.maximumRPM
        default: rpm = nil
        }
        
        return rpm
    }
    
    // MARK: - Titles
    static func title(for kind: FloatingWindowLayout.CardKind, settings: FannySettings) -> String {
        let title: String
        
        switch kind {
        case .cpu:
            title = ReadingFormatter.cpuTitle
        case .gpu:
            title = ReadingFormatter.gpuTitle
        case .fan(let id):
            title = ReadingFormatter.fanName(id: id, settings: settings)
        }
        
        return title
    }
    
    /// Every symbol a card header can show, so the cards can share one symbol width.
    static var cardSymbols: [SFSymbol] {
        let kinds: [FloatingWindowLayout.CardKind] = [FloatingWindowLayout.CardKind.fan(id: 0),
                                                      FloatingWindowLayout.CardKind.cpu,
                                                      FloatingWindowLayout.CardKind.gpu,]
        return kinds.map({ symbol(for: $0) })
    }
    
    private static func symbol(for kind: FloatingWindowLayout.CardKind) -> SFSymbol {
        let symbol: SFSymbol
        
        switch kind {
        case .cpu:
            symbol = .cpu
        case .gpu:
            symbol = .thermometerMedium
        case .fan:
            symbol = .fan
        }
        
        return symbol
    }
    
    static func title(for stat: FloatingWindowLayout.Stat) -> String {
        let title: String
        
        switch stat {
        case .cpuTemperature, .gpuTemperature:
            title = String(localized: "Temperature", comment: "Floating window and its Settings: a card's temperature, using the sensor chosen in the Sensors pane.")
        case .cpuDie:
            title = String(localized: "Die", comment: "Settings pop-up item: the CPU die temperature sensor.")
        case .cpuAverage, .gpuAverage:
            title = String(localized: "Average", comment: "Settings pop-up item: the average of the temperature sensors.")
        case .cpuHottest, .gpuHottest:
            title = String(localized: "Hottest", comment: "Settings pop-up item: the hottest temperature sensor.")
        case .fanSpeed:
            title = String(localized: "Speed", comment: "Floating window and its Settings: a fan's current speed.")
        case .fanSpeedBar:
            title = String(localized: "Speed Bar", comment: "Floating window Settings: a bar showing a fan's speed between its minimum and maximum.")
        case .fanTarget:
            title = String(localized: "Target", comment: "Floating window and its Settings: the speed macOS is driving a fan toward.")
        case .fanMinimum:
            title = String(localized: "Minimum", comment: "Floating window and its Settings: a fan's minimum speed.")
        case .fanMaximum:
            title = String(localized: "Maximum", comment: "Floating window and its Settings: a fan's maximum speed.")
        }
        
        return title
    }
}
