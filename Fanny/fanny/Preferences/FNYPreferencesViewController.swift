//
//  FNYPreferencesViewController.swift
//  Fanny
//
//  Created by Daniel Storm on 9/21/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Cocoa

class FNYPreferencesViewController: NSViewController {
    
    @IBOutlet private weak var temperatureUnitPopUpButton: NSPopUpButton!
    
    @IBOutlet private weak var gitHubButton: NSButton!
    @IBOutlet private weak var versionTextField: FNYTextField! {
        didSet { versionTextField.stringValue = "v\(Bundle.appVersion)" }
    }
    
    static let storyboardName: String = "FNYPreferencesWindow"
    
    // MARK: - View Cycle
    override func viewWillAppear() {
        super.viewWillAppear()
        prepareTemperatureUnitPopUpButton()
    }
    
    // MARK: - Setup
    private func prepareTemperatureUnitPopUpButton() {
        temperatureUnitPopUpButton.removeAllItems()
        temperatureUnitPopUpButton.addItems(withTitles: FNYUserPreferences.temperatureUnitOptions.map({ $0.title }))
        temperatureUnitPopUpButton.selectItem(at: FNYUserPreferences.temperatureUnitOption().index)
    }
    
    // MARK: - Preference Actions
    @IBAction private func temperatureUnitPopUpButtonOptionClicked(_ sender: NSPopUpButton) {
        let selectedIndex: Int = sender.indexOfSelectedItem
        guard let selectedTemperatureUnitOption = FNYUserPreferences.temperatureUnitOptions.first(where: { $0.index == selectedIndex }) else { return }
        FNYUserPreferences.save(temperatureUnitOption: selectedTemperatureUnitOption)
    }
    
    // MARK: - Actions
    @IBAction private func gitHubButtonClicked(_ sender: NSButton) {
        guard let url = URL(string: "https://github.com/DanielStormApps/Fanny") else { return }
        NSWorkspace.shared.open(url)
    }
    
}
