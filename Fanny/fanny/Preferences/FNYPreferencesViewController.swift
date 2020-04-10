//
//  FNYPreferencesViewController.swift
//  Fanny
//
//  Created by Daniel Storm on 9/21/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Cocoa

class FNYPreferencesViewController: NSViewController {
    
    @IBOutlet private weak var monitorRefreshTimeIntervalPopUpButton: NSPopUpButton!
    @IBOutlet private weak var temperatureUnitPopUpButton: NSPopUpButton!
    @IBOutlet private weak var menuBarIconPopUpButton: NSPopUpButton!
    
    @IBOutlet private weak var gitHubButton: NSButton!
    @IBOutlet private weak var versionTextField: FNYTextField! {
        didSet { versionTextField.stringValue = "v\(Bundle.appVersion)" }
    }
    
    static let storyboardName: String = "FNYPreferencesWindow"
    
    private lazy var gitHubURL: URL! = {
        return URL(string: "https://github.com/DanielStormApps/Fanny")
    }()
    
    // MARK: - View Cycle
    override func viewWillAppear() {
        super.viewWillAppear()
        prepareMonitorRefreshTimeIntervalPopUpButton()
        prepareTemperatureUnitPopUpButton()
        prepareIconPopUpButton()
    }
    
    // MARK: - Setup
    private func prepareMonitorRefreshTimeIntervalPopUpButton() {
        monitorRefreshTimeIntervalPopUpButton.removeAllItems()
        monitorRefreshTimeIntervalPopUpButton.addItems(withTitles: FNYUserPreferences.monitorRefreshTimeIntervalOptions.map({ $0.title }))
        monitorRefreshTimeIntervalPopUpButton.selectItem(at: FNYUserPreferences.monitorRefreshTimeIntervalOption().index)
    }
    
    private func prepareTemperatureUnitPopUpButton() {
        temperatureUnitPopUpButton.removeAllItems()
        temperatureUnitPopUpButton.addItems(withTitles: FNYUserPreferences.temperatureUnitOptions.map({ $0.title }))
        temperatureUnitPopUpButton.selectItem(at: FNYUserPreferences.temperatureUnitOption().index)
    }
    
    private func prepareIconPopUpButton() {
        menuBarIconPopUpButton.removeAllItems()
        menuBarIconPopUpButton.addItems(withTitles: FNYUserPreferences.menuBarIconOptions.map({ $0.title }))
        menuBarIconPopUpButton.selectItem(at: FNYUserPreferences.menuBarIconOption().index)
    }
    
    // MARK: - Preference Actions
    @IBAction private func monitorRefreshTimeIntervalPopUpButtonOptionClicked(_ sender: NSPopUpButton) {
        let selectedIndex: Int = sender.indexOfSelectedItem
        guard let selectedMonitorRefreshTimeIntervalOption: MonitorRefreshTimeIntervalOption = FNYUserPreferences.monitorRefreshTimeIntervalOptions.first(where: { $0.index == selectedIndex }) else { return }
        FNYUserPreferences.save(monitorRefreshTimeIntervalOption: selectedMonitorRefreshTimeIntervalOption)
        FNYMonitor.shared.refreshSystemStats()
        FNYMonitor.shared.refreshTimeInterval = selectedMonitorRefreshTimeIntervalOption.timeInterval
    }
    
    @IBAction private func temperatureUnitPopUpButtonOptionClicked(_ sender: NSPopUpButton) {
        let selectedIndex: Int = sender.indexOfSelectedItem
        guard let selectedTemperatureUnitOption: TemperatureUnitOption = FNYUserPreferences.temperatureUnitOptions.first(where: { $0.index == selectedIndex }) else { return }
        FNYUserPreferences.save(temperatureUnitOption: selectedTemperatureUnitOption)
        FNYMonitor.shared.refreshSystemStats()
    }
    
    @IBAction private func menuBarIconPopUpButtonOptionClicked(_ sender: NSPopUpButton) {
        let selectedIndex: Int = sender.indexOfSelectedItem
        guard let selectedMenuBarIconIconOption: MenuBarIconOption = FNYUserPreferences.menuBarIconOptions.first(where: { $0.index == selectedIndex }) else { return }
        FNYUserPreferences.save(menuBarIconOption: selectedMenuBarIconIconOption)
        FNYMonitor.shared.refreshSystemStats()
    }
    
    // MARK: - Actions
    @IBAction private func gitHubButtonClicked(_ sender: NSButton) {
        NSWorkspace.shared.open(gitHubURL)
    }
    
}
