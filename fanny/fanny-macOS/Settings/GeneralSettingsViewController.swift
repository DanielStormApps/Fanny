//
//  GeneralSettingsViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout
import SFSafeSymbols

/// The General pane: anything that needs the user to act, then launch at login, the floating window, and update checks.
final class GeneralSettingsViewController: ViewController {
    
    private let settingsScrollView: SettingsScrollView = SettingsScrollView()
    private let warningGroup: SettingsGroupView = SettingsGroupView()
    private let group: SettingsGroupView = SettingsGroupView()
    
    private let launchAtLoginSwitch: NSSwitch = NSSwitch()
    private let floatingWindowSwitch: NSSwitch = NSSwitch()
    private let automaticUpdateChecksSwitch: NSSwitch = NSSwitch()
    private let checkNowButton: NSButton = NSButton(title: GeneralSettingsViewController.checkNowTitle, target: nil, action: nil)
    private let approvalButton: NSButton = NSButton(title: String(localized: "Open System Settings", comment: "Settings button that opens System Settings."), target: nil, action: nil)
    private var approvalRow: SettingsRowView?
    private var updateStatusRow: SettingsRowView?
    private let checkProgressIndicator: NSProgressIndicator = NSProgressIndicator()
    /// Set by Check Now, so VoiceOver hears the result of the check the person asked for.
    private var isAwaitingCheckResult: Bool = false
    /// Set while Check Now's spinner shows, which lasts at least `minimumCheckDuration` so a fast check still reads as a check.
    private var isShowingCheckProgress: Bool = false
    
    private static let minimumCheckDuration: Duration = Duration.seconds(1)
    
    private static let checkNowTitle: String = String(localized: "Check Now", comment: "Settings button that checks GitHub for a newer version of Fanny right away.")
    private static let downloadTitle: String = String(localized: "Download", comment: "Settings button that opens the GitHub page of the newer Fanny version.")
    private static let checkForUpdatesTitle: String = String(localized: "Check for Updates", comment: "Settings row title for checking GitHub for a newer version of Fanny.")
    private static let updateAvailableTitle: String = String(localized: "Update Available", comment: "Settings row title shown when a newer version of Fanny is on GitHub.")
    private static let approvalSubtitle: String = String(localized: "Allow Fanny in Login Items to open it at login.", comment: "Settings subtitle explaining how to approve the login item (keep Fanny).")
    
    // MARK: - View Cycle
    override func loadView() {
        view = settingsScrollView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analytics(title: "general")
        setupRows()
        FannySettingsManager.shared.delegate.add(self)
        UpdateChecker.shared.delegate.add(self)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        reload()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        reload()
    }
    
    // MARK: - Setup
    private func setupRows() {
        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(launchAtLoginChanged)
        floatingWindowSwitch.target = self
        floatingWindowSwitch.action = #selector(floatingWindowChanged)
        automaticUpdateChecksSwitch.target = self
        automaticUpdateChecksSwitch.action = #selector(automaticUpdateChecksChanged)
        checkNowButton.target = self
        checkNowButton.action = #selector(checkNowButtonClicked)
        
        approvalButton.target = self
        approvalButton.action = #selector(openLoginItemSettings)
        
        setupWarningRows()
        
        group.addRow(SettingsRowView(title: String(localized: "Launch at Login", comment: "Settings switch: opens Fanny automatically when the user logs in."), control: launchAtLoginSwitch))
        group.addRow(SettingsRowView(title: String(localized: "Floating Window", comment: "Accessibility label of the floating window. Also the menu item and Settings pane that show or customize it."), control: floatingWindowSwitch))
        group.addRow(SettingsRowView(title: String(localized: "Check for Updates Automatically", comment: "Settings switch: Fanny checks GitHub once a day for a newer version (keep GitHub)."), control: automaticUpdateChecksSwitch))
        
        checkProgressIndicator.style = .spinning
        checkProgressIndicator.controlSize = .small
        checkProgressIndicator.isDisplayedWhenStopped = false
        // The spinner hangs off the button's leading edge, outside the layout, so the button never moves when it appears.
        let checkNowContainerView: NSView = NSView()
        checkNowContainerView.addSubview(checkNowButton)
        checkNowButton.autoPinEdgesToSuperviewEdges()
        checkNowContainerView.addSubview(checkProgressIndicator)
        checkProgressIndicator.autoAlignAxis(.horizontal, toSameAxisOf: checkNowButton)
        checkProgressIndicator.autoPinEdge(.trailing, to: .leading, of: checkNowButton, withOffset: -8.0)
        
        let updateStatusRow: SettingsRowView = SettingsRowView(title: GeneralSettingsViewController.checkForUpdatesTitle, subtitle: UpdateChecker.shared.statusText, control: checkNowContainerView)
        group.addRow(updateStatusRow)
        self.updateStatusRow = updateStatusRow
        
        settingsScrollView.addGroup(group)
    }
    
    /// Rows that need the user to change a system setting go in a tinted group at the top, hidden until there is one.
    private func setupWarningRows() {
        warningGroup.isWarning = true
        
        let approvalRow: SettingsRowView = SettingsRowView(title: String(localized: "Approval Needed", comment: "Settings row shown when macOS needs the user to approve Fanny as a login item."), subtitle: GeneralSettingsViewController.approvalSubtitle, control: approvalButton)
        warningGroup.addRow(approvalRow)
        warningGroup.setRowHidden(approvalRow, hidden: true)
        self.approvalRow = approvalRow
        
        settingsScrollView.addGroup(warningGroup, header: String(localized: "Action Needed", comment: "Settings section header above rows that need the user to change a system setting."))
        settingsScrollView.setGroupHidden(warningGroup, hidden: true)
    }
    
    // MARK: - Reload
    private func reload() {
        let settings: FannySettings = FannySettingsManager.shared.settings
        floatingWindowSwitch.state = settings.showsFloatingWindow ? .on : .off
        automaticUpdateChecksSwitch.state = settings.checksForUpdatesAutomatically ? .on : .off
        reloadLaunchAtLogin()
        reloadUpdateStatus()
    }
    
    /// The button downloads a found update, and checks again otherwise.
    private func reloadUpdateStatus() {
        let updateChecker: UpdateChecker = UpdateChecker.shared
        let hasUpdate: Bool = updateChecker.availableUpdate != nil
        let buttonTitle: String = hasUpdate ? GeneralSettingsViewController.downloadTitle : GeneralSettingsViewController.checkNowTitle
        
        if checkNowButton.title != buttonTitle {
            GeneralSettingsViewController.addCrossfade(to: checkNowButton)
            checkNowButton.title = buttonTitle
            checkNowButton.image = hasUpdate ? NSImage(systemSymbol: .arrowDownCircle, accessibilityDescription: nil) : nil
            checkNowButton.imagePosition = hasUpdate ? .imageLeading : .noImage
        }
        
        updateStatusRow?.updateTitle(hasUpdate ? GeneralSettingsViewController.updateAvailableTitle : GeneralSettingsViewController.checkForUpdatesTitle)
        
        // Keeps saying it is checking until the spinner stops, so the text and the spinner change together.
        updateStatusRow?.updateSubtitle(UpdateChecker.statusText(isChecking: updateChecker.isChecking || isShowingCheckProgress, didFailManualCheck: updateChecker.didFailManualCheck, availableUpdate: updateChecker.availableUpdate, lastCheckDate: updateChecker.lastCheckDate), animated: true)
        checkNowButton.isEnabled = updateChecker.isChecking == false && isShowingCheckProgress == false
        
        guard isAwaitingCheckResult, updateChecker.isChecking == false, isShowingCheckProgress == false else { return }
        isAwaitingCheckResult = false
        NSAccessibility.post(element: checkNowButton, notification: .announcementRequested, userInfo: [.announcement: updateChecker.statusText, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
    
    /// Fades the spinner in and out at the same quick speed as the status text. Reduce Motion shows and hides it at once.
    private func setCheckProgressVisible(_ isVisible: Bool) {
        let duration: TimeInterval = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.0 : SettingsRowView.subtitleTransitionDuration
        
        if isVisible {
            checkProgressIndicator.alphaValue = 0.0
            checkProgressIndicator.startAnimation(nil)
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            self.checkProgressIndicator.animator().alphaValue = isVisible ? 1.0 : 0.0
        } completionHandler: {
            guard isVisible == false, self.isShowingCheckProgress == false else { return }
            self.checkProgressIndicator.stopAnimation(nil)
        }
    }
    
    private static func addCrossfade(to view: NSView) {
        guard NSWorkspace.shared.accessibilityDisplayShouldReduceMotion == false else { return }
        view.wantsLayer = true
        
        let transition: CATransition = CATransition()
        transition.type = .fade
        transition.duration = SettingsRowView.subtitleTransitionDuration
        view.layer?.add(transition, forKey: "titleCrossfade")
    }
    
    /// A login item waiting for approval still counts as on, because the user already asked for it.
    private func reloadLaunchAtLogin() {
        let requiresApproval: Bool = LaunchAtLoginManager.shared.requiresApproval
        launchAtLoginSwitch.state = (LaunchAtLoginManager.shared.isEnabled || requiresApproval) ? .on : .off
        
        if let approvalRow: SettingsRowView = approvalRow {
            let approvalWasPending: Bool = approvalRow.isHidden == false
            warningGroup.setRowHidden(approvalRow, hidden: requiresApproval == false)
            updateWarningGroup()
            
            // The switch reads as on while approval is pending, so say why it is not yet active.
            let approvalHelp: String? = requiresApproval ? GeneralSettingsViewController.approvalSubtitle : nil
            launchAtLoginSwitch.setAccessibilityHelp(approvalHelp)
            
            if requiresApproval && approvalWasPending == false {
                NSAccessibility.post(element: launchAtLoginSwitch, notification: .layoutChanged)
                NSAccessibility.post(element: launchAtLoginSwitch, notification: .announcementRequested, userInfo: [.announcement: GeneralSettingsViewController.approvalSubtitle, .priority: NSAccessibilityPriorityLevel.high.rawValue])
            }
        }
    }
    
    private func updateWarningGroup() {
        settingsScrollView.setGroupHidden(warningGroup, hidden: warningGroup.hasVisibleRows == false)
    }
    
    // MARK: - Actions
    @objc private func launchAtLoginChanged() {
        LaunchAtLoginManager.shared.setEnabled(launchAtLoginSwitch.state == .on)
        reloadLaunchAtLogin()
        trackAction("general_LaunchAtLogin")
    }
    
    @objc private func floatingWindowChanged() {
        let isOn: Bool = floatingWindowSwitch.state == .on
        FannySettingsManager.shared.update({ $0.showsFloatingWindow = isOn })
        trackAction("general_FloatingWindow")
    }
    
    @objc private func automaticUpdateChecksChanged() {
        let isOn: Bool = automaticUpdateChecksSwitch.state == .on
        FannySettingsManager.shared.update({ $0.checksForUpdatesAutomatically = isOn })
        trackAction("general_AutomaticUpdateChecks")
    }
    
    @objc private func checkNowButtonClicked() {
        if UpdateChecker.shared.availableUpdate == nil {
            guard isShowingCheckProgress == false else { return }
            trackAction("general_CheckForUpdates")
            isAwaitingCheckResult = true
            isShowingCheckProgress = true
            setCheckProgressVisible(true)
            reloadUpdateStatus()
            
            Task { @MainActor [weak self] in
                async let minimumDuration: Void? = try? Task.sleep(for: GeneralSettingsViewController.minimumCheckDuration)
                await UpdateChecker.shared.checkNow()
                _ = await minimumDuration
                
                guard let strongSelf: GeneralSettingsViewController = self else { return }
                strongSelf.isShowingCheckProgress = false
                strongSelf.setCheckProgressVisible(false)
                strongSelf.reloadUpdateStatus()
            }
        }
        else {
            trackAction("general_DownloadUpdate")
            UpdateChecker.shared.openAvailableUpdate()
        }
    }
    
    @objc private func openLoginItemSettings() {
        trackAction("general_OpenLoginItems")
        LaunchAtLoginManager.shared.openSystemSettings()
    }
    
    @objc private func applicationDidBecomeActive() {
        reloadLaunchAtLogin()
    }
    
    // MARK: - Analytics
    private func trackAction(_ title: String) {
        let event: PageViewEvent = PageViewEvent(title: title)
        Analytics.shared.track(event: event)
    }
}

// MARK: - FannySettingsManagerDelegate
extension GeneralSettingsViewController: FannySettingsManagerDelegate {
    
    func fannySettingsManager(_ manager: FannySettingsManager, didUpdateSettings settings: FannySettings) {
        reload()
    }
}

// MARK: - UpdateCheckerDelegate
extension GeneralSettingsViewController: UpdateCheckerDelegate {
    
    func updateCheckerDidUpdateStatus(_ checker: UpdateChecker) {
        reloadUpdateStatus()
    }
}
