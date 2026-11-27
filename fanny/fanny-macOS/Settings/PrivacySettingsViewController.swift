//
//  PrivacySettingsViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/26/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

/// The Privacy pane: the analytics and crash reports switches, and the logs switch with the saved logs' size, Show in Finder, and Delete.
final class PrivacySettingsViewController: ViewController {
    
    private let settingsScrollView: SettingsScrollView = SettingsScrollView()
    private let analyticsGroup: SettingsGroupView = SettingsGroupView()
    private let crashReportsGroup: SettingsGroupView = SettingsGroupView()
    private let logsGroup: SettingsGroupView = SettingsGroupView()
    
    private let analyticsSwitch: NSSwitch = NSSwitch()
    private let crashReportsSwitch: NSSwitch = NSSwitch()
    private let logsSwitch: NSSwitch = NSSwitch()
    private let showInFinderButton: NSButton = NSButton(title: String(localized: "Show in Finder", comment: "Settings, Privacy: button that opens the folder of saved logs in Finder (keep Finder)."), target: nil, action: nil)
    private let deleteButton: NSButton = NSButton(title: String(localized: "Delete…", comment: "Settings, Privacy: button that asks to delete every saved log file."), target: nil, action: nil)
    private var logFilesRow: SettingsRowView?
    
    private static let buttonSpacing: CGFloat = 8.0
    
    // MARK: - View Cycle
    override func loadView() {
        view = settingsScrollView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analytics(title: "privacy")
        setupAnalyticsGroup()
        setupCrashReportsGroup()
        setupLogsGroup()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        reload()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        reload()
    }
    
    // MARK: - Setup
    private func setupAnalyticsGroup() {
        analyticsSwitch.target = self
        analyticsSwitch.action = #selector(analyticsChanged)
        
        analyticsGroup.addRow(SettingsRowView(title: String(localized: "Analytics", comment: "Settings, Privacy: switch that lets Fanny send anonymous usage data."), subtitle: String(localized: "Send anonymous usage data to help improve Fanny.", comment: "Settings, Privacy: subtitle of the Analytics switch (keep Fanny)."), control: analyticsSwitch))
        settingsScrollView.addGroup(analyticsGroup, header: String(localized: "Analytics", comment: "Settings, Privacy: section header above the analytics switch."))
    }
    
    private func setupCrashReportsGroup() {
        crashReportsSwitch.target = self
        crashReportsSwitch.action = #selector(crashReportsChanged)
        
        crashReportsGroup.addRow(SettingsRowView(title: String(localized: "Crash Reports", comment: "Settings, Privacy: switch that lets Fanny send anonymous crash reports."), subtitle: String(localized: "Send anonymous crash reports to help fix problems. Requires restarting Fanny to take effect.", comment: "Settings, Privacy: subtitle of the Crash Reports switch (keep Fanny)."), control: crashReportsSwitch))
        settingsScrollView.addGroup(crashReportsGroup, header: String(localized: "Crash Reports", comment: "Settings, Privacy: section header above the crash reports switch."))
    }
    
    private func setupLogsGroup() {
        logsSwitch.target = self
        logsSwitch.action = #selector(logsChanged)
        showInFinderButton.target = self
        showInFinderButton.action = #selector(showInFinder)
        deleteButton.target = self
        deleteButton.action = #selector(deleteLogs)
        
        logsGroup.addRow(SettingsRowView(title: String(localized: "Logs", comment: "Settings, Privacy: switch that saves a record of what Fanny does to files on this Mac."), subtitle: String(localized: "Saved only on this Mac.", comment: "Settings, Privacy: subtitle of the Logs switch (keep Mac)."), control: logsSwitch))
        
        let buttonStackView: NSStackView = NSStackView(views: [showInFinderButton, deleteButton])
        buttonStackView.orientation = .horizontal
        buttonStackView.spacing = PrivacySettingsViewController.buttonSpacing
        // Keeps the buttons at the trailing edge, instead of the stack widening toward the title.
        buttonStackView.setHuggingPriority(.required, for: .horizontal)
        
        let logFilesRow: SettingsRowView = SettingsRowView(title: String(localized: "Log Files", comment: "Settings, Privacy: row title above how much space the saved log files take up."), subtitle: PrivacySettingsViewController.sizeText(byteCount: 0), control: buttonStackView)
        logsGroup.addRow(logFilesRow)
        self.logFilesRow = logFilesRow
        
        settingsScrollView.addGroup(logsGroup, header: String(localized: "Logs", comment: "Settings, Privacy: section header above the log settings."))
    }
    
    // MARK: - Reload
    private func reload() {
        analyticsSwitch.state = Analytics.shared.isEnabled ? .on : .off
        crashReportsSwitch.state = FirebaseManager.shared.isCrashReportsEnabled ? .on : .off
        logsSwitch.state = FileLogger.shared.isEnabled ? .on : .off
        reloadLogFiles()
    }
    
    private func reloadLogFiles() {
        let byteCount: Int64 = FileLogger.shared.totalByteCount()
        logFilesRow?.updateSubtitle(PrivacySettingsViewController.sizeText(byteCount: byteCount), animated: true)
        deleteButton.isEnabled = byteCount > 0
    }
    
    private static func sizeText(byteCount: Int64) -> String {
        let size: String = ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
        return String(localized: "Using \(size)", comment: "Settings, Privacy: how much disk space the saved log files take up, such as Using 1.2 MB.")
    }
    
    // MARK: - Actions
    @objc private func analyticsChanged() {
        let isOn: Bool = analyticsSwitch.state == .on
        let event: PageViewEvent = PageViewEvent(title: isOn ? "privacy_AnalyticsOn" : "privacy_AnalyticsOff")
        Analytics.shared.setEnabled(isOn, event: event)
    }
    
    @objc private func crashReportsChanged() {
        let isOn: Bool = crashReportsSwitch.state == .on
        let event: PageViewEvent = PageViewEvent(title: isOn ? "privacy_CrashReportsOn" : "privacy_CrashReportsOff")
        FirebaseManager.shared.setCrashReportsEnabled(isOn, event: event)
    }
    
    @objc private func logsChanged() {
        let isOn: Bool = logsSwitch.state == .on
        FileLogger.shared.setEnabled(isOn)
        trackAction(isOn ? "privacy_LogsOn" : "privacy_LogsOff")
        reloadLogFiles()
    }
    
    /// Opens the log folder in a Finder window, creating it first so Finder never shows an error before the first log is written.
    @objc private func showInFinder() {
        let logDirectoryURL: URL = LogArchiver.logDirectoryURL()
        try? FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
        trackAction("privacy_ShowLogsInFinder")
        NSWorkspace.shared.open(logDirectoryURL)
    }
    
    @objc private func deleteLogs() {
        guard let window: NSWindow = view.window else { return }
        
        let alert: NSAlert = NSAlert()
        alert.messageText = String(localized: "Delete All Logs?", comment: "Settings, Privacy: title of the alert that confirms deleting every saved log file.")
        alert.informativeText = String(localized: "This can’t be undone.", comment: "Settings, Privacy: message of the alert that confirms deleting every saved log file.")
        let deleteAlertButton: NSButton = alert.addButton(withTitle: String(localized: "Delete", comment: "Settings, Privacy: alert button that deletes every saved log file."))
        deleteAlertButton.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Cancel", comment: "Settings, Privacy: alert button that keeps the saved log files."))
        
        alert.beginSheetModal(for: window) { [weak self] response in
            guard
                response == NSApplication.ModalResponse.alertFirstButtonReturn,
                let strongSelf: PrivacySettingsViewController = self
            else { return }
            strongSelf.deleteAllLogs()
        }
    }
    
    /// Logs the delete first, so the line is removed with the rest instead of starting a new file.
    private func deleteAllLogs() {
        Log.info("🔒 deleteAllLogs")
        trackAction("privacy_DeleteLogs")
        FileLogger.shared.deleteAllLogs { [weak self] in
            self?.reloadLogFiles()
        }
    }
    
    @objc private func applicationDidBecomeActive() {
        reloadLogFiles()
    }
    
    // MARK: - Analytics
    private func trackAction(_ title: String) {
        let event: PageViewEvent = PageViewEvent(title: title)
        Analytics.shared.track(event: event)
    }
}
