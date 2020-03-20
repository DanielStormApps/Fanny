//
//  FNYWidgetViewController.swift
//  FannyWidget
//
//  Created by Daniel Storm on 9/15/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Cocoa
import NotificationCenter

class FNYWidgetViewController: NSViewController, NCWidgetProviding {
    
    @IBOutlet private weak var containerView: NSView!
    
    @IBOutlet private weak var headerTextField: FNYTextField!
    @IBOutlet private weak var radioButtonStackView: NSStackView! {
        didSet {
            radioButtonStackView.translatesAutoresizingMaskIntoConstraints = false
            radioButtonStackView.alphaValue = 0.0
            radioButtonStackView.spacing = 8.0
        }
    }
    
    @IBOutlet private weak var currentRPMTextField: FNYTextField!
    @IBOutlet private weak var minimumRPMTextField: FNYTextField!
    @IBOutlet private weak var maximumRPMTextField: FNYTextField!
    @IBOutlet private weak var targetRPMTextField: FNYTextField!

    @IBOutlet private weak var cpuTemperatureTextField: FNYTextField!
    @IBOutlet private weak var gpuTemperatureTextField: FNYTextField!
    
    private let widgetNibName: String = "FNYWidgetViewController"
    private var selectedRadioButtonTag: Int = 0
    
    override var nibName: NSNib.Name? {
        return NSNib.Name(widgetNibName)
    }
    
    // MARK: - View Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        updateWidget()
        
        FNYMonitor.shared.start()
        FNYMonitor.shared.delegate.add(self)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        FNYLauncher.shared.launchParentApplicationIfNeeded()
    }
    
    // MARK: - Widget Cycle
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        updateWidget()
        completionHandler(.newData)
    }
    
    // MARK: - Update Widget
    private func updateWidget() {
        updateStackViewIfNeeded()
        
        let fans: [Fan] = FNYLocalStorage.fans()
        guard fans.indices.contains(selectedRadioButtonTag) else { return }
        let selectedFan: Fan = fans[selectedRadioButtonTag]
        
        currentRPMTextField.stringValue = "\(selectedFan.currentRPM ?? 0) RPM"
        minimumRPMTextField.stringValue = "\(selectedFan.minimumRPM ?? 0) RPM"
        maximumRPMTextField.stringValue = "\(selectedFan.maximumRPM ?? 0) RPM"
        targetRPMTextField.stringValue = "\(selectedFan.targetRPM ?? 0) RPM"

        cpuTemperatureTextField.stringValue = FNYLocalStorage.cpuTemperature()?.formattedTemperature() ?? String()
        gpuTemperatureTextField.stringValue = FNYLocalStorage.gpuTemperature()?.formattedTemperature() ?? String()
    }
    
    // MARK: - Radio Button Action
    @objc private func radioButtonClicked(sender: FNYRadioButton) {
        selectedRadioButtonTag = sender.tag
        updateWidget()
    }
    
    // MARK: - Helpers
    private func updateStackViewIfNeeded() {
        guard
            let numberOfFans: Int = FNYLocalStorage.numberOfFans(),
            numberOfFans > 1,
            radioButtonStackView.subviews.count != numberOfFans
            else { return }
        
        for subview in radioButtonStackView.subviews {
            radioButtonStackView.removeArrangedSubview(subview)
        }
        
        for i in 0..<numberOfFans {
            let radioButton: FNYRadioButton = FNYRadioButton(tag: i,
                                                             state: i == 0 ? .on : .off,
                                                             target: self,
                                                             action: #selector(radioButtonClicked(sender:)))
            
            radioButtonStackView.addArrangedSubview(radioButton)
        }
        
        radioButtonStackView.alphaValue = 1.0
    }
    
}

extension FNYWidgetViewController: FNYMonitorDelegate {
    
    // MARK: - FNYMonitorDelegate
    func monitorDidRefreshSystemStats(_ monitor: FNYMonitor) {
        updateWidget()
    }
    
}
