//
//  DeveloperSensorsViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/25/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout

/// The Developer Menu's Sensors pane: the keys Fanny reads on this Mac, then a table each for the fans, CPU, and GPU, with every key Fanny can read on any Mac and its raw value here.
/// - Note: A key this Mac does not have reads --, so the same tables work for debugging on any Mac.
final class DeveloperSensorsViewController: ViewController {
    
    private let settingsScrollView: SettingsScrollView = SettingsScrollView()
    private let loadingIndicator: NSProgressIndicator = NSProgressIndicator()
    private let inUseSummaryLabel: NSTextField = NSTextField(wrappingLabelWithString: "")
    private var inUseTable: SensorTableView?
    private var fansTable: SensorTableView?
    private var cpuTable: SensorTableView?
    private var gpuTable: SensorTableView?
    private var refreshTimer: Timer?
    
    /// Quick enough to watch values move under load, slow enough that hundreds of keys never strain the SMC.
    private static let refreshTimeInterval: TimeInterval = 2.0
    private static let loadingFadeDuration: TimeInterval = 0.2
    
    // MARK: - View Cycle
    override func loadView() {
        let containerView: NSView = NSView()
        containerView.addSubview(settingsScrollView)
        settingsScrollView.autoPinEdgesToSuperviewEdges()
        view = containerView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analytics(title: "developerSensors")
        setupLoadingIndicator()
        refresh()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        startRefreshTimer()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Setup
    /// Spins over the empty pane while the first read lists and reads every key, which takes a moment.
    private func setupLoadingIndicator() {
        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .regular
        loadingIndicator.isDisplayedWhenStopped = false
        loadingIndicator.setAccessibilityLabel(String(localized: "Reading Sensors...", comment: "Developer Menu: VoiceOver name of the spinner shown while the sensor tables load."))
        view.addSubview(loadingIndicator)
        loadingIndicator.autoCenterInSuperview()
        loadingIndicator.startAnimation(nil)
        // Starts hidden, so the tables can fade in as the spinner fades out.
        settingsScrollView.alphaValue = 0.0
    }
    
    /// Crossfades the spinner out and the tables in, then stops the spinner.
    private func hideLoadingIndicator() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DeveloperSensorsViewController.loadingFadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.loadingIndicator.animator().alphaValue = 0.0
            self.settingsScrollView.animator().alphaValue = 1.0
        } completionHandler: {
            self.loadingIndicator.stopAnimation(nil)
            self.loadingIndicator.removeFromSuperview()
            NSAccessibility.post(element: self.view, notification: .layoutChanged)
        }
    }
    
    // MARK: - Refresh
    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        let timer: Timer = Timer(timeInterval: DeveloperSensorsViewController.refreshTimeInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }
    
    private func refresh() {
        SensorMonitor.shared.readDiagnostics { [weak self] diagnostics in
            self?.show(diagnostics)
        }
    }
    
    /// Builds the tables on the first read, then updates their values in place so the scroll position stays put.
    private func show(_ diagnostics: SensorReader.Diagnostics) {
        let allReadings: [SensorReader.DiagnosticReading] = diagnostics.fans + diagnostics.cpu + diagnostics.gpu
        inUseSummaryLabel.attributedStringValue = DeveloperSensorsViewController.bulletedText(DeveloperSensorsViewController.inUseSummary(settings: FannySettingsManager.shared.settings, diagnostics: diagnostics))
        
        if let inUseTable: SensorTableView = inUseTable, let fansTable: SensorTableView = fansTable, let cpuTable: SensorTableView = cpuTable, let gpuTable: SensorTableView = gpuTable {
            inUseTable.update(allReadings)
            fansTable.update(diagnostics.fans)
            cpuTable.update(diagnostics.cpu)
            gpuTable.update(diagnostics.gpu)
        }
        else {
            let fanKeyNames: Set<String> = Set(diagnostics.fans.map({ $0.name }))
            let inUseTable: SensorTableView = SensorTableView(readings: allReadings, showsOnlyUsed: true, title: { name in
                return fanKeyNames.contains(name) ? DeveloperSensorsViewController.fanTitle(forKeyName: name) : SensorCatalog.title(forKeyName: name)
            }, valueText: { reading in
                return fanKeyNames.contains(reading.name) ? DeveloperSensorsViewController.fanValueText(reading) : DeveloperSensorsViewController.temperatureValueText(reading)
            })
            let fansTable: SensorTableView = SensorTableView(readings: diagnostics.fans, showsOnlyUsed: false, title: DeveloperSensorsViewController.fanTitle(forKeyName:), valueText: DeveloperSensorsViewController.fanValueText)
            let cpuTable: SensorTableView = SensorTableView(readings: diagnostics.cpu, showsOnlyUsed: false, title: SensorCatalog.title(forKeyName:), valueText: DeveloperSensorsViewController.temperatureValueText)
            let gpuTable: SensorTableView = SensorTableView(readings: diagnostics.gpu, showsOnlyUsed: false, title: SensorCatalog.title(forKeyName:), valueText: DeveloperSensorsViewController.temperatureValueText)
            inUseSummaryLabel.isSelectable = false
            settingsScrollView.addGroup(inUseTable.groupView, header: String(localized: "In Use", comment: "Developer Menu: header above the table of sensor keys Fanny reads with the current settings."), headerDetail: inUseSummaryLabel, footer: String(localized: "The keys Fanny reads on this Mac for the menu bar, widgets, and floating window with the current settings. Fan count and limits are read once at launch, the rest on every refresh.", comment: "Developer Menu: footnote under the In Use table."))
            settingsScrollView.addGroup(fansTable.groupView, header: String(localized: "Fans", comment: "Developer Menu: header above the table of fan keys."), footer: String(localized: "-- means this Mac has no such key.", comment: "Developer Menu: footnote under the Fans table (keep --)."))
            settingsScrollView.addGroup(cpuTable.groupView, header: String(localized: "CPU (\(DeveloperSensorsViewController.countText(diagnostics.cpu)))", comment: "Developer Menu: header above the table of CPU keys. The argument reads like 48 of 277 on this Mac."), footer: String(localized: "Raw values in Celsius, including idle placeholders such as 0.0 that Fanny skips.", comment: "Developer Menu: footnote under the CPU table."))
            settingsScrollView.addGroup(gpuTable.groupView, header: String(localized: "GPU (\(DeveloperSensorsViewController.countText(diagnostics.gpu)))", comment: "Developer Menu: header above the table of GPU keys. The argument reads like 12 of 40 on this Mac."))
            self.inUseTable = inUseTable
            self.fansTable = fansTable
            self.cpuTable = cpuTable
            self.gpuTable = gpuTable
            hideLoadingIndicator()
        }
    }
    
    // MARK: - Text
    /// What the In Use keys produce, one bullet per shown reading, such as "CPU Average: the mean of the hottest live key in each core group (Te0, Tp0)".
    private static func inUseSummary(settings: FannySettings, diagnostics: SensorReader.Diagnostics) -> String {
        let usedCPUNames: [String] = diagnostics.cpu.filter({ $0.isUsed }).map({ $0.name })
        let coreFamilies: String = familiesText(usedCPUNames.filter({ TemperatureSelector.isCPUCoreKey($0) }))
        let gpuFamilies: String = familiesText(diagnostics.gpu.filter({ $0.isUsed }).map({ $0.name }))
        let fanIndexes: [Int] = diagnostics.fans.filter({ $0.isUsed && $0.name.hasSuffix("Ac") }).compactMap({ Int(String(Array($0.name)[1])) })
        var lines: [String] = []
        
        if fanIndexes.isEmpty == false {
            let fanNames: String = fanIndexes.map({ String(localized: "Fan \($0 + 1)", comment: "A fan's default name, such as Fan 1. The argument is its number.") }).joined(separator: ", ")
            lines.append(String(localized: "\(fanNames): speed and target every refresh, minimum and maximum once at launch", comment: "Developer Menu: In Use summary line for the fans. The argument lists fans, such as Fan 1, Fan 2."))
        }
        
        for mode in FannySettings.CPUSensorMode.allCases where settings.cpuModesToRead.contains(mode) {
            switch mode {
            case .average:
                lines.append(String(localized: "CPU Average: the mean of the hottest live key in each core group (\(coreFamilies)), or TCMb when no core is live", comment: "Developer Menu: In Use summary line (keep TCMb). The argument lists key groups, such as Te0, Tp0."))
            case .hottest:
                lines.append(String(localized: "CPU Hottest: TCMz, or the hottest live core key", comment: "Developer Menu: In Use summary line (keep TCMz)."))
            case .die:
                lines.append(String(localized: "CPU Die: TCMb", comment: "Developer Menu: In Use summary line (keep TCMb)."))
            }
        }
        
        if settings.showsCPUTemperature == false {
            lines.append(String(localized: "CPU temperature: turned off, so no CPU keys are read", comment: "Developer Menu: In Use summary line when the CPU temperature is off."))
        }
        
        for mode in FannySettings.GPUSensorMode.allCases where settings.gpuModesToRead.contains(mode) {
            switch mode {
            case .average:
                lines.append(String(localized: "GPU Average: the mean of the hottest live key in each GPU group (\(gpuFamilies))", comment: "Developer Menu: In Use summary line. The argument lists key groups, such as Tg0, Tg1."))
            case .hottest:
                lines.append(String(localized: "GPU Hottest: the hottest live GPU key", comment: "Developer Menu: In Use summary line."))
            }
        }
        
        if settings.showsGPUTemperature == false {
            lines.append(String(localized: "GPU temperature: turned off, so no GPU keys are read", comment: "Developer Menu: In Use summary line when the GPU temperature is off."))
        }
        
        return lines.map({ "• \($0)" }).joined(separator: "\n")
    }
    
    /// Indents wrapped lines past the bullet, so each item reads as one block.
    private static func bulletedText(_ text: String) -> NSAttributedString {
        let font: NSFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = ("• " as NSString).size(withAttributes: [.font: font]).width
        paragraphStyle.paragraphSpacing = 2.0
        return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraphStyle])
    }
    
    /// Such as "Te0, Tp0, Tp1", the three character groups Average takes the hottest key from.
    private static func familiesText(_ names: [String]) -> String {
        return Set(names.map({ String($0.prefix(3)) })).sorted().joined(separator: ", ")
    }
    
    /// Such as "F0Ac (Fan 1 Speed)" or "FNum (Fan Count)".
    private static func fanTitle(forKeyName name: String) -> String {
        let characters: [Character] = Array(name)
        let title: String
        
        if name == SMCKey.fanCount.name {
            title = String(localized: "Fan Count", comment: "Developer Menu: name of the key that holds how many fans this Mac has.")
        }
        else if characters.count == 4, let index: Int = Int(String(characters[1])) {
            let suffix: String = String(characters[2...])
            let kinds: [String: String] = ["Ac": String(localized: "Speed", comment: "Developer Menu: the kind of a fan key, as in Fan 1 Speed."),
                                           "Mn": String(localized: "Minimum", comment: "Developer Menu: the kind of a fan key, as in Fan 1 Minimum."),
                                           "Mx": String(localized: "Maximum", comment: "Developer Menu: the kind of a fan key, as in Fan 1 Maximum."),
                                           "Tg": String(localized: "Target", comment: "Developer Menu: the kind of a fan key, as in Fan 1 Target."),]
            let kind: String = kinds[suffix] ?? suffix
            title = String(localized: "Fan \(index + 1) \(kind)", comment: "Developer Menu: the name of a fan key, such as Fan 1 Speed. The arguments are the fan's number and the key's kind.")
        }
        else {
            title = String(localized: "Fan", comment: "Developer Menu: the name of an unrecognized fan key.")
        }
        
        return "\(name) (\(title))"
    }
    
    private static func fanValueText(_ reading: SensorReader.DiagnosticReading) -> String {
        let text: String
        
        if let value: Double = reading.value {
            text = reading.name == SMCKey.fanCount.name ? String(format: "%.0f", value) : String(localized: "\(String(format: "%.0f", value)) RPM", comment: "A fan speed with its unit, such as 1350 RPM. The argument is a number.")
        }
        else {
            text = ReadingFormatter.missingText
        }
        
        return text
    }
    
    private static func temperatureValueText(_ reading: SensorReader.DiagnosticReading) -> String {
        return reading.value.map({ String(localized: "\(String(format: "%.1f", $0))°C", comment: "A temperature in degrees Celsius, such as 45.2°C. The argument is a number.") }) ?? ReadingFormatter.missingText
    }
    
    /// Such as "48 of 277 on this Mac".
    private static func countText(_ readings: [SensorReader.DiagnosticReading]) -> String {
        let readCount: Int = readings.filter({ $0.value != nil }).count
        return String(localized: "\(readCount) of \(readings.count) on this Mac", comment: "Developer Menu: how many of the known keys this Mac has, such as 48 of 277 on this Mac.")
    }
}

// MARK: - SensorTableView
/// A grouped table of SMC keys: a column header, then one row per key with its title and value.
/// - Note: Keys with a reading come first, in the order of the first read, so a key never jumps rows while the values refresh.
private final class SensorTableView {
    
    let groupView: SettingsGroupView = SettingsGroupView()
    private var valueLabels: [String: NSTextField] = [:]
    private var rows: [String: NSView] = [:]
    private let showsOnlyUsed: Bool
    private let valueText: (SensorReader.DiagnosticReading) -> String
    
    private static let rowHeight: CGFloat = 24.0
    private static let horizontalInset: CGFloat = 16.0
    private static let valueColumnWidth: CGFloat = 90.0
    private static let columnSpacing: CGFloat = 12.0
    
    // MARK: - Init
    /// - Parameter showsOnlyUsed: Builds a row for every key but shows only the ones Fanny uses, so a key Fanny starts or stops using appears or hides in place.
    init(readings: [SensorReader.DiagnosticReading], showsOnlyUsed: Bool, title: (String) -> String, valueText: @escaping (SensorReader.DiagnosticReading) -> String) {
        self.showsOnlyUsed = showsOnlyUsed
        self.valueText = valueText
        groupView.addRow(SensorTableView.makeRow(title: String(localized: "Sensor", comment: "Developer Menu: column header for the key names."), value: String(localized: "Value", comment: "Developer Menu: column header for the key readings."), isHeader: true).row)
        let sortedReadings: [SensorReader.DiagnosticReading] = readings.filter({ $0.value != nil }) + readings.filter({ $0.value == nil })
        
        for reading in sortedReadings {
            let row: (row: NSView, valueLabel: NSTextField) = SensorTableView.makeRow(title: title(reading.name), value: valueText(reading), isHeader: false)
            rows[reading.name] = row.row
            valueLabels[reading.name] = row.valueLabel
            groupView.addRow(row.row)
        }
        
        update(readings)
    }
    
    // MARK: - Update
    func update(_ readings: [SensorReader.DiagnosticReading]) {
        for reading in readings {
            valueLabels[reading.name]?.stringValue = valueText(reading)
            
            if showsOnlyUsed, let row: NSView = rows[reading.name] {
                groupView.setRowHidden(row, hidden: reading.isUsed == false)
            }
        }
    }
    
    // MARK: - Rows
    private static func makeRow(title: String, value: String, isHeader: Bool) -> (row: NSView, valueLabel: NSTextField) {
        let row: NSView = NSView()
        let font: NSFont = isHeader ? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold) : NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let color: NSColor = isHeader ? NSColor.secondaryLabelColor : NSColor.labelColor
        let titleLabel: NSTextField = makeLabel(title, font: font, color: color, alignment: .left)
        let valueLabel: NSTextField = makeLabel(value, font: font, color: color, alignment: .right)
        
        row.autoSetDimension(.height, toSize: SensorTableView.rowHeight)
        
        for label in [titleLabel, valueLabel] {
            row.addSubview(label)
            label.autoAlignAxis(toSuperviewAxis: .horizontal)
        }
        
        valueLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: SensorTableView.horizontalInset)
        valueLabel.autoSetDimension(.width, toSize: SensorTableView.valueColumnWidth)
        titleLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: SensorTableView.horizontalInset)
        titleLabel.autoPinEdge(.trailing, to: .leading, of: valueLabel, withOffset: -SensorTableView.columnSpacing)
        
        return (row: row, valueLabel: valueLabel)
    }
    
    private static func makeLabel(_ text: String, font: NSFont, color: NSColor, alignment: NSTextAlignment) -> NSTextField {
        let label: NSTextField = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.alignment = alignment
        label.lineBreakMode = .byTruncatingTail
        return label
    }
}
