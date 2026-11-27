//
//  SensorSettingsViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout

/// The Sensors pane: how often readings refresh, the temperature unit, the fans' names, and which CPU and GPU sensors are shown.
final class SensorSettingsViewController: ViewController {
    
    private let settingsScrollView: SettingsScrollView = SettingsScrollView()
    private let refreshSecondsControl: SettingsSecondsControl = SettingsSecondsControl(range: FannySettings.refreshSecondsRange)
    private let unitPopUpButton: NSPopUpButton = NSPopUpButton(frame: CGRect.zero, pullsDown: false)
    private let cpuTemperatureSwitch: NSSwitch = NSSwitch()
    private let cpuSensorPopUpButton: NSPopUpButton = NSPopUpButton(frame: CGRect.zero, pullsDown: false)
    private let gpuTemperatureSwitch: NSSwitch = NSSwitch()
    private let gpuSensorPopUpButton: NSPopUpButton = NSPopUpButton(frame: CGRect.zero, pullsDown: false)
    private let fanNameStylePopUpButton: NSPopUpButton = NSPopUpButton(frame: CGRect.zero, pullsDown: false)
    private let fanNamesGroup: SettingsGroupView = SettingsGroupView()
    /// One row per fan, added once a read finds the fans, by SMC fan index.
    private var fanNameRows: [Int: (row: SettingsRowView, textField: NSTextField)] = [:]
    
    private var pendingTrackWorkItems: [String: DispatchWorkItem] = [:]
    
    private static let settledTrackDelay: TimeInterval = 1.0
    private static let fanNameFieldWidth: CGFloat = 180.0
    
    // MARK: - View Cycle
    override func loadView() {
        view = settingsScrollView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analytics(title: "sensors")
        setupRows()
        FannySettingsManager.shared.delegate.add(self)
        SensorMonitor.shared.delegate.add(self)
        reload()
    }
    
    // MARK: - Setup
    private func setupRows() {
        refreshSecondsControl.onChange = { [weak self] seconds in
            let refreshTimeInterval: TimeInterval = TimeInterval(seconds)
            let didChange: Bool = refreshTimeInterval != FannySettingsManager.shared.settings.refreshTimeInterval
            
            FannySettingsManager.shared.update({ $0.refreshTimeInterval = refreshTimeInterval })
            
            if didChange {
                self?.trackActionWhenSettled("sensors_RefreshInterval")
            }
        }
        
        for unit in FannySettings.TemperatureUnit.allCases {
            unitPopUpButton.addItem(withTitle: SensorSettingsViewController.title(for: unit))
        }
        
        for mode in FannySettings.CPUSensorMode.allCases {
            cpuSensorPopUpButton.addItem(withTitle: SensorSettingsViewController.title(for: mode))
        }
        
        for mode in FannySettings.GPUSensorMode.allCases {
            gpuSensorPopUpButton.addItem(withTitle: SensorSettingsViewController.title(for: mode))
        }
        
        for control in [unitPopUpButton, cpuTemperatureSwitch, cpuSensorPopUpButton, gpuTemperatureSwitch, gpuSensorPopUpButton] as [NSControl] {
            control.target = self
        }
        
        unitPopUpButton.action = #selector(temperatureUnitChanged)
        cpuTemperatureSwitch.action = #selector(cpuTemperatureChanged)
        cpuSensorPopUpButton.action = #selector(cpuSensorChanged)
        gpuTemperatureSwitch.action = #selector(gpuTemperatureChanged)
        gpuSensorPopUpButton.action = #selector(gpuSensorChanged)
        
        let readingsGroup: SettingsGroupView = SettingsGroupView()
        readingsGroup.addRow(SettingsRowView(title: String(localized: "Refresh Interval", comment: "Settings row: how often, in seconds, Fanny reads the fans and temperatures."), subtitle: String(localized: "In seconds.", comment: "Settings subtitle: the number beside is in seconds."), control: refreshSecondsControl))
        readingsGroup.addRow(SettingsRowView(title: String(localized: "Temperature Unit", comment: "Settings pop-up: Celsius, Fahrenheit, or Kelvin."), control: unitPopUpButton))
        settingsScrollView.addGroup(readingsGroup, footer: String(localized: "Readings update every second while the menu bar menu is open.", comment: "Settings footnote under Refresh Interval and Temperature Unit."))
        
        setupFanNamesGroup()
        
        let cpuGroup: SettingsGroupView = SettingsGroupView()
        cpuGroup.addRow(SettingsRowView(title: String(localized: "CPU Temperature", comment: "Settings switch: shows the CPU temperature in the menu, menu bar, and widgets."), subtitle: String(localized: "When off, Fanny stops reading the CPU temperature.", comment: "Settings subtitle under the CPU Temperature switch: turning it off stops the reading entirely (keep Fanny)."), control: cpuTemperatureSwitch))
        cpuGroup.addRow(SettingsRowView(title: String(localized: "CPU Sensor", comment: "Settings pop-up: which CPU temperature sensor Fanny shows."), control: cpuSensorPopUpButton))
        settingsScrollView.addGroup(cpuGroup, footer: SensorSettingsViewController.sensorChoicesText(FannySettings.CPUSensorMode.allCases.map({ (title: SensorSettingsViewController.title(for: $0), description: SensorSettingsViewController.description(for: $0)) })))
        
        let gpuGroup: SettingsGroupView = SettingsGroupView()
        gpuGroup.addRow(SettingsRowView(title: String(localized: "GPU Temperature", comment: "Settings switch: shows the GPU temperature in the menu, menu bar, and widgets."), subtitle: String(localized: "When off, Fanny stops reading the GPU temperature.", comment: "Settings subtitle under the GPU Temperature switch: turning it off stops the reading entirely (keep Fanny)."), control: gpuTemperatureSwitch))
        gpuGroup.addRow(SettingsRowView(title: String(localized: "GPU Sensor", comment: "Settings pop-up: which GPU temperature sensor Fanny shows."), control: gpuSensorPopUpButton))
        settingsScrollView.addGroup(gpuGroup, footer: SensorSettingsViewController.sensorChoicesText(FannySettings.GPUSensorMode.allCases.map({ (title: SensorSettingsViewController.title(for: $0), description: SensorSettingsViewController.description(for: $0)) })))
    }
    
    private func setupFanNamesGroup() {
        for style in FannySettings.FanNameStyle.allCases {
            fanNameStylePopUpButton.addItem(withTitle: SensorSettingsViewController.title(for: style))
        }
        
        fanNameStylePopUpButton.target = self
        fanNameStylePopUpButton.action = #selector(fanNameStyleChanged)
        
        fanNamesGroup.addRow(SettingsRowView(title: String(localized: "Fan Names", comment: "Settings pop-up: whether fans are numbered (Fan 1) or lettered (Fan A)."), control: fanNameStylePopUpButton))
        settingsScrollView.addGroup(fanNamesGroup, footer: String(localized: "Give any fan its own name, up to \(FannySettings.fanNameMaxLength) characters. Names show in the menu bar, menu, floating window, widgets, and Siri. Leave a name empty to use the default.", comment: "Settings footnote under the fan name fields (keep Siri)."))
        reloadFanNameRows()
    }
    
    /// Adds a name field for each fan a read found, and hides the fields of fans this Mac does not report.
    private func reloadFanNameRows() {
        let settings: FannySettings = FannySettingsManager.shared.settings
        let fanIDs: [Int] = SensorSettingsViewController.currentFanIDs()
        
        for fanID in fanIDs where fanNameRows[fanID] == nil {
            let textField: NSTextField = NSTextField()
            textField.delegate = self
            textField.tag = fanID
            textField.lineBreakMode = .byTruncatingTail
            textField.usesSingleLineMode = true
            textField.autoSetDimension(.width, toSize: SensorSettingsViewController.fanNameFieldWidth)
            
            let row: SettingsRowView = SettingsRowView(title: "", control: textField)
            fanNamesGroup.addRow(row)
            fanNameRows[fanID] = (row: row, textField: textField)
        }
        
        for (fanID, fanNameRow) in fanNameRows {
            let defaultName: String = ReadingFormatter.defaultFanName(id: fanID, style: settings.fanNameStyle)
            fanNamesGroup.setRowHidden(fanNameRow.row, hidden: fanIDs.contains(fanID) == false)
            fanNameRow.row.updateTitle(defaultName)
            fanNameRow.textField.placeholderString = defaultName
            fanNameRow.textField.setAccessibilityLabel(String(localized: "\(defaultName) Name", comment: "VoiceOver label of the text field that renames a fan. The argument is the fan's default name, such as Fan 1."))
            
            // A field being typed in keeps its text, so a save never moves the cursor.
            if fanNameRow.textField.currentEditor() == nil {
                fanNameRow.textField.stringValue = settings.customFanNames[fanID] ?? ""
            }
        }
    }
    
    private static func currentFanIDs() -> [Int] {
        guard let snapshot: ReadingsSnapshot = SensorMonitor.shared.snapshot, snapshot.fanStatus == ReadingsSnapshot.FanStatus.fans else { return [] }
        return snapshot.fans.map({ $0.id })
    }
    
    // MARK: - Reload
    private func reload() {
        let settings: FannySettings = FannySettingsManager.shared.settings
        refreshSecondsControl.seconds = Int(settings.refreshTimeInterval.rounded())
        unitPopUpButton.selectItem(at: FannySettings.TemperatureUnit.allCases.firstIndex(of: settings.temperatureUnit) ?? 0)
        cpuTemperatureSwitch.state = settings.showsCPUTemperature ? .on : .off
        cpuSensorPopUpButton.selectItem(at: FannySettings.CPUSensorMode.allCases.firstIndex(of: settings.cpuSensorMode) ?? 0)
        cpuSensorPopUpButton.isEnabled = settings.showsCPUTemperature
        gpuTemperatureSwitch.state = settings.showsGPUTemperature ? .on : .off
        gpuSensorPopUpButton.selectItem(at: FannySettings.GPUSensorMode.allCases.firstIndex(of: settings.gpuSensorMode) ?? 0)
        gpuSensorPopUpButton.isEnabled = settings.showsGPUTemperature
        fanNameStylePopUpButton.selectItem(at: FannySettings.FanNameStyle.allCases.firstIndex(of: settings.fanNameStyle) ?? 0)
        reloadFanNameRows()
    }
    
    // MARK: - Actions
    // Each change is tracked after it is saved, so the shared parameters carry the new value.
    @objc private func temperatureUnitChanged() {
        guard let unit: FannySettings.TemperatureUnit = SensorSettingsViewController.selectedValue(of: unitPopUpButton, in: FannySettings.TemperatureUnit.allCases) else { return }
        
        FannySettingsManager.shared.update({ $0.temperatureUnit = unit })
        trackAction("sensors_TemperatureUnit")
    }
    
    @objc private func cpuTemperatureChanged() {
        let isOn: Bool = cpuTemperatureSwitch.state == .on
        FannySettingsManager.shared.update({ $0.showsCPUTemperature = isOn })
        trackAction("sensors_CPUTemperature")
    }
    
    @objc private func cpuSensorChanged() {
        guard let mode: FannySettings.CPUSensorMode = SensorSettingsViewController.selectedValue(of: cpuSensorPopUpButton, in: FannySettings.CPUSensorMode.allCases) else { return }
        
        FannySettingsManager.shared.update({ $0.cpuSensorMode = mode })
        trackAction("sensors_CPUSensor")
    }
    
    @objc private func gpuTemperatureChanged() {
        let isOn: Bool = gpuTemperatureSwitch.state == .on
        FannySettingsManager.shared.update({ $0.showsGPUTemperature = isOn })
        trackAction("sensors_GPUTemperature")
    }
    
    @objc private func fanNameStyleChanged() {
        guard let style: FannySettings.FanNameStyle = SensorSettingsViewController.selectedValue(of: fanNameStylePopUpButton, in: FannySettings.FanNameStyle.allCases) else { return }
        
        FannySettingsManager.shared.update({ $0.fanNameStyle = style })
        trackAction("sensors_FanNameStyle")
    }
    
    @objc private func gpuSensorChanged() {
        guard let mode: FannySettings.GPUSensorMode = SensorSettingsViewController.selectedValue(of: gpuSensorPopUpButton, in: FannySettings.GPUSensorMode.allCases) else { return }
        
        FannySettingsManager.shared.update({ $0.gpuSensorMode = mode })
        trackAction("sensors_GPUSensor")
    }
    
    // MARK: - Helpers
    private static func selectedValue<T>(of popUpButton: NSPopUpButton, in values: [T]) -> T? {
        let index: Int = popUpButton.indexOfSelectedItem
        guard index >= 0, index < values.count else { return nil }
        return values[index]
    }
    
    /// A spelled out duration such as "3 seconds" or "1 minute", in the user's language.
    static func refreshTitle(for timeInterval: TimeInterval, locale: Locale = Locale.current) -> String {
        var calendar: Calendar = Calendar.current
        calendar.locale = locale
        
        let formatter: DateComponentsFormatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.minute, .second]
        
        let seconds: Int = Int(timeInterval)
        return formatter.string(from: timeInterval) ?? String(localized: "\(seconds) seconds", comment: "Refresh interval in seconds, shown by Shortcuts and VoiceOver. The argument is the number of seconds.")
    }
    
    static func title(for unit: FannySettings.TemperatureUnit) -> String {
        let title: String
        
        switch unit {
        case .celsius:
            title = String(localized: "Celsius (°C)", comment: "Settings pop-up item: temperature unit.")
        case .fahrenheit:
            title = String(localized: "Fahrenheit (°F)", comment: "Settings pop-up item: temperature unit.")
        case .kelvin:
            title = String(localized: "Kelvin (K)", comment: "Settings pop-up item: temperature unit.")
        }
        
        return title
    }
    
    /// Such as "Numbers (Fan 1, Fan 2)", so each choice shows what it does.
    private static func title(for style: FannySettings.FanNameStyle) -> String {
        let examples: String = [0, 1].map({ ReadingFormatter.defaultFanName(id: $0, style: style) }).formatted(.list(type: .and, width: .narrow))
        let title: String
        
        switch style {
        case .numbers:
            title = String(localized: "Numbers (\(examples))", comment: "Settings pop-up item: fans are numbered. The argument lists examples, such as Fan 1, Fan 2.")
        case .letters:
            title = String(localized: "Letters (\(examples))", comment: "Settings pop-up item: fans are lettered. The argument lists examples, such as Fan A, Fan B.")
        }
        
        return title
    }
    
    /// One bullet per choice, in the pop-up's order, such as "• Average: the average of the CPU cores".
    private static func sensorChoicesText(_ choices: [(title: String, description: String)]) -> String {
        return choices.map({ choice in
            let title: String = choice.title
            let description: String = choice.description
            return "• " + String(localized: "\(title): \(description)", comment: "Settings footnote: one sensor choice and what it reads, such as Average: the average of the CPU cores. The first argument is the choice, the second its description.")
        }).joined(separator: "\n")
    }
    
    private static func description(for mode: FannySettings.CPUSensorMode) -> String {
        let description: String
        
        switch mode {
        case .average:
            description = String(localized: "The average of the CPU cores", comment: "Settings footnote: what the Average CPU sensor choice reads.")
        case .hottest:
            description = String(localized: "The hottest CPU core", comment: "Settings footnote: what the Hottest CPU sensor choice reads.")
        case .die:
            description = String(localized: "The CPU die sensor", comment: "Settings footnote: what the Die CPU sensor choice reads.")
        }
        
        return description
    }
    
    private static func description(for mode: FannySettings.GPUSensorMode) -> String {
        let description: String
        
        switch mode {
        case .average:
            description = String(localized: "The average of the GPU sensors", comment: "Settings footnote: what the Average GPU sensor choice reads.")
        case .hottest:
            description = String(localized: "The hottest GPU sensor", comment: "Settings footnote: what the Hottest GPU sensor choice reads.")
        }
        
        return description
    }
    
    static func title(for mode: FannySettings.CPUSensorMode) -> String {
        let title: String
        
        switch mode {
        case .average:
            title = String(localized: "Average", comment: "Settings pop-up item: the average of the temperature sensors.")
        case .hottest:
            title = String(localized: "Hottest", comment: "Settings pop-up item: the hottest temperature sensor.")
        case .die:
            title = String(localized: "Die", comment: "Settings pop-up item: the CPU die temperature sensor.")
        }
        
        return title
    }
    
    static func title(for mode: FannySettings.GPUSensorMode) -> String {
        let title: String
        
        switch mode {
        case .average:
            title = String(localized: "Average", comment: "Settings pop-up item: the average of the temperature sensors.")
        case .hottest:
            title = String(localized: "Hottest", comment: "Settings pop-up item: the hottest temperature sensor.")
        }
        
        return title
    }
    
    // MARK: - Analytics
    private func trackAction(_ title: String) {
        let event: PageViewEvent = PageViewEvent(title: title)
        Analytics.shared.track(event: event)
    }
    
    /// A held stepper changes the value many times, so the change is tracked once it stops changing.
    private func trackActionWhenSettled(_ title: String) {
        pendingTrackWorkItems[title]?.cancel()
        
        let workItem: DispatchWorkItem = DispatchWorkItem { [weak self] in
            self?.pendingTrackWorkItems[title] = nil
            self?.trackAction(title)
        }
        
        pendingTrackWorkItems[title] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + SensorSettingsViewController.settledTrackDelay, execute: workItem)
    }
}

// MARK: - FannySettingsManagerDelegate
extension SensorSettingsViewController: FannySettingsManagerDelegate {
    
    func fannySettingsManager(_ manager: FannySettingsManager, didUpdateSettings settings: FannySettings) {
        reload()
    }
}

// MARK: - SensorMonitorDelegate
extension SensorSettingsViewController: SensorMonitorDelegate {
    
    /// The fan name fields appear once the first read finds the fans.
    func sensorMonitor(_ monitor: SensorMonitor, didUpdateSnapshot snapshot: ReadingsSnapshot) {
        reloadFanNameRows()
    }
}

// MARK: - NSTextFieldDelegate
extension SensorSettingsViewController: NSTextFieldDelegate {
    
    /// Cuts the name to the limit as it is typed. Saving waits for the edit to end.
    func controlTextDidChange(_ notification: Notification) {
        guard let textField: NSTextField = notification.object as? NSTextField, fanNameRows[textField.tag]?.textField === textField else { return }
        
        // Waits for a composing input method, such as Japanese or the emoji picker, to finish before cutting the name.
        let isComposing: Bool = (textField.currentEditor() as? NSTextView)?.hasMarkedText() ?? false
        
        if isComposing == false, textField.stringValue.count > FannySettings.fanNameMaxLength {
            textField.stringValue = String(textField.stringValue.prefix(FannySettings.fanNameMaxLength))
        }
    }
    
    /// Saves once the name is set with Return, Tab, or a click elsewhere, so the menu bar, floating window, and widgets update once instead of on every keystroke.
    /// - Note: An empty field goes back to the default name.
    func controlTextDidEndEditing(_ notification: Notification) {
        guard let textField: NSTextField = notification.object as? NSTextField, fanNameRows[textField.tag]?.textField === textField else { return }
        
        textField.stringValue = String(textField.stringValue.prefix(FannySettings.fanNameMaxLength))
        let fanID: Int = textField.tag
        let name: String? = FannySettings.cleanedFanName(textField.stringValue)
        guard name != FannySettingsManager.shared.settings.customFanNames[fanID] else { return }
        
        FannySettingsManager.shared.update({ $0.customFanNames[fanID] = name })
        trackAction("sensors_FanName")
    }
}

// MARK: - SettingsSecondsControl
/// A whole-number seconds field beside a stepper, kept in sync and limited to a range.
final class SettingsSecondsControl: NSView {
    
    var onChange: ((Int) -> Void)?
    
    private let range: ClosedRange<Int>
    private let textField: NSTextField = NSTextField()
    private let stepper: NSStepper = NSStepper()
    
    private static let fieldWidth: CGFloat = 56.0
    /// Matches the whole text only, so "1.5" and "15abc" are rejected rather than read as 1 and 15.
    private static let parsingFormatter: NumberFormatter = {
        let formatter: NumberFormatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        return formatter
    }()
    
    /// Keeps the value on the trailing edge in both directions; `.natural` would put it on the leading side.
    private static var trailingAlignment: NSTextAlignment {
        return NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? NSTextAlignment.left : NSTextAlignment.right
    }
    
    var seconds: Int {
        get {
            return stepper.integerValue
        }
        set {
            stepper.integerValue = newValue
            
            // Rewriting the field mid-edit would clobber what the user is typing.
            if textField.currentEditor() == nil {
                textField.integerValue = newValue
            }
        }
    }
    
    // MARK: - Init
    init(range: ClosedRange<Int>) {
        self.range = range
        super.init(frame: CGRect.zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Accessibility
    /// The container is not an element, so the row's name and help go to the field and stepper VoiceOver actually reaches.
    override func setAccessibilityLabel(_ accessibilityLabel: String?) {
        textField.setAccessibilityLabel(accessibilityLabel)
        stepper.setAccessibilityLabel(accessibilityLabel)
    }
    
    override func setAccessibilityHelp(_ accessibilityHelp: String?) {
        textField.setAccessibilityHelp(accessibilityHelp)
        stepper.setAccessibilityHelp(accessibilityHelp)
    }
    
    // MARK: - Setup
    private func setup() {
        let formatter: NumberFormatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        formatter.minimum = NSNumber(value: range.lowerBound)
        formatter.maximum = NSNumber(value: range.upperBound)
        
        textField.formatter = formatter
        textField.alignment = SettingsSecondsControl.trailingAlignment
        textField.delegate = self
        addSubview(textField)
        
        stepper.minValue = Double(range.lowerBound)
        stepper.maxValue = Double(range.upperBound)
        stepper.increment = 1.0
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = #selector(stepperChanged)
        addSubview(stepper)
        
        textField.autoPinEdge(toSuperviewEdge: .leading)
        textField.autoPinEdge(toSuperviewEdge: .top)
        textField.autoPinEdge(toSuperviewEdge: .bottom)
        textField.autoSetDimension(.width, toSize: SettingsSecondsControl.fieldWidth)
        stepper.autoPinEdge(.leading, to: .trailing, of: textField, withOffset: 6.0)
        stepper.autoPinEdge(toSuperviewEdge: .trailing)
        stepper.autoAlignAxis(toSuperviewAxis: .horizontal)
    }
    
    // MARK: - Parsing
    /// - Returns: The whole number in the text, or `nil` when it is empty, not a whole number, or outside the range.
    static func parsedSeconds(from text: String, in range: ClosedRange<Int>) -> Int? {
        let trimmedText: String = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let parsedSeconds: Int?
        
        // The field shows the locale's digits, such as Arabic-Indic, so they are read back the same way, with Western digits as a fallback.
        let value: Int? = SettingsSecondsControl.parsingFormatter.number(from: trimmedText)?.intValue ?? Int(trimmedText)
        
        if let value: Int = value, range.contains(value) {
            parsedSeconds = value
        }
        else {
            parsedSeconds = nil
        }
        
        return parsedSeconds
    }
    
    // MARK: - Actions
    @objc private func stepperChanged() {
        let value: Int = stepper.integerValue
        textField.integerValue = value
        onChange?(value)
    }
}

// MARK: - NSTextFieldDelegate
extension SettingsSecondsControl: NSTextFieldDelegate {
    
    /// Accepts the raw text so a bad entry is restored on end of editing instead of showing a formatter alert.
    func control(_ control: NSControl, didFailToFormatString string: String, errorDescription error: String?) -> Bool {
        return true
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if let value: Int = SettingsSecondsControl.parsedSeconds(from: textField.stringValue, in: range) {
            let didChange: Bool = value != stepper.integerValue
            stepper.integerValue = value
            textField.integerValue = value
            
            if didChange {
                onChange?(value)
            }
        }
        else {
            textField.integerValue = stepper.integerValue
        }
    }
}
