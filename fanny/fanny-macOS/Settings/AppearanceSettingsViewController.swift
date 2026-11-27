//
//  AppearanceSettingsViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout

/// The Appearance pane: the app theme, and the floating window's glass tint with a live preview.
final class AppearanceSettingsViewController: ViewController {
    
    private let settingsScrollView: SettingsScrollView = SettingsScrollView()
    private let themeGroup: SettingsGroupView = SettingsGroupView()
    private let glassGroup: SettingsGroupView = SettingsGroupView()
    
    private let themePopUpButton: NSPopUpButton = NSPopUpButton(frame: CGRect.zero, pullsDown: false)
    private let previewView: FloatingWindowPreviewView = FloatingWindowPreviewView()
    private let matchSystemSwitch: NSSwitch = NSSwitch()
    private let tintSlider: NSSlider = NSSlider(value: 0.0, minValue: AppThemeSettings.glassTintAmountRange.lowerBound, maxValue: AppThemeSettings.glassTintAmountRange.upperBound, target: nil, action: nil)
    private let tintValueLabel: NSTextField = NSTextField(labelWithString: "")
    private var themeFooterLabel: NSTextField?
    private var tintRowView: SettingsRowView?
    
    private static let tintTickMarkCount: Int = 11
    private static let tintSliderWidth: CGFloat = 180.0
    private static let tintValueSpacing: CGFloat = 8.0
    private static let disabledRowAlpha: CGFloat = 0.4
    
    // MARK: - View Cycle
    override func loadView() {
        view = settingsScrollView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analytics(title: "appearance")
        setupThemeGroup()
        setupGlassGroup()
        reload()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        reload()
    }
    
    // MARK: - Setup
    private func setupThemeGroup() {
        for theme in AppTheme.allCases {
            themePopUpButton.addItem(withTitle: theme.title)
            themePopUpButton.lastItem?.representedObject = theme.rawValue
        }
        
        themePopUpButton.target = self
        themePopUpButton.action = #selector(themeChanged)
        
        themeGroup.addRow(SettingsRowView(title: String(localized: "Appearance", comment: "Settings, Appearance: title of the row that picks System, Light, or Dark."), control: themePopUpButton))
        themeFooterLabel = settingsScrollView.addGroup(themeGroup, footer: AppThemeManager.shared.selectedTheme.caption)
    }
    
    private func setupGlassGroup() {
        matchSystemSwitch.target = self
        matchSystemSwitch.action = #selector(matchSystemChanged)
        
        tintSlider.numberOfTickMarks = AppearanceSettingsViewController.tintTickMarkCount
        tintSlider.allowsTickMarkValuesOnly = true
        tintSlider.isContinuous = true
        tintSlider.target = self
        tintSlider.action = #selector(tintChanged)
        
        tintValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        tintValueLabel.textColor = NSColor.secondaryLabelColor
        tintValueLabel.alignment = .right
        tintValueLabel.hideFromAccessibility()
        
        glassGroup.addRow(previewView)
        glassGroup.addRow(SettingsRowView(title: String(localized: "Match System", comment: "Settings, Appearance: switch that makes the floating window glass follow the Liquid Glass setting in System Settings."), subtitle: String(localized: "Use the Liquid Glass setting in System Settings.", comment: "Settings, Appearance: subtitle of the Match System switch (keep Liquid Glass and System Settings as Apple names them)."), control: matchSystemSwitch))
        let tintTitle: String = String(localized: "Liquid Glass Tint", comment: "Settings, Appearance: slider that sets how tinted the floating window glass is (keep Liquid Glass as Apple names it).")
        tintSlider.setAccessibilityLabel(tintTitle)
        let tintRow: SettingsRowView = SettingsRowView(title: tintTitle, control: makeTintControl())
        tintRowView = tintRow
        glassGroup.addRow(tintRow)
        settingsScrollView.addGroup(glassGroup, header: String(localized: "Floating Window", comment: "Accessibility label of the floating window. Also the menu item and Settings pane that show or customize it."))
    }
    
    /// The slider with its percentage after it. The slider is the accessibility element, so the label is read as its value.
    private func makeTintControl() -> NSView {
        let containerView: NSView = NSView()
        containerView.addSubview(tintSlider)
        containerView.addSubview(tintValueLabel)
        
        tintSlider.autoPinEdge(toSuperviewEdge: .leading)
        tintSlider.autoAlignAxis(toSuperviewAxis: .horizontal)
        tintSlider.autoSetDimension(.width, toSize: AppearanceSettingsViewController.tintSliderWidth)
        tintSlider.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
        tintSlider.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        
        // Wide enough for "100%", so the slider does not shift as the value changes.
        tintValueLabel.stringValue = AppearanceSettingsViewController.percentText(for: 1.0)
        tintValueLabel.autoSetDimension(.width, toSize: tintValueLabel.intrinsicContentSize.width)
        tintValueLabel.autoPinEdge(.leading, to: .trailing, of: tintSlider, withOffset: AppearanceSettingsViewController.tintValueSpacing)
        tintValueLabel.autoPinEdge(toSuperviewEdge: .trailing)
        tintValueLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        return containerView
    }
    
    // MARK: - Reload
    private func reload() {
        let manager: AppThemeManager = AppThemeManager.shared
        
        if let index: Int = AppTheme.allCases.firstIndex(of: manager.selectedTheme) {
            themePopUpButton.selectItem(at: index)
        }
        
        themeFooterLabel?.stringValue = manager.selectedTheme.caption
        matchSystemSwitch.state = manager.glassTintMatchesSystem ? .on : .off
        tintSlider.doubleValue = manager.glassTintAmount
        tintSlider.isEnabled = manager.glassTintMatchesSystem == false
        // A disabled slider alone barely changes, so the whole row fades while Match System is on.
        tintRowView?.alphaValue = tintSlider.isEnabled ? 1.0 : AppearanceSettingsViewController.disabledRowAlpha
        reloadTintValueLabel()
    }
    
    private func reloadTintValueLabel() {
        let percentText: String = AppearanceSettingsViewController.percentText(for: tintSlider.doubleValue)
        tintValueLabel.stringValue = percentText
        tintSlider.setAccessibilityValueDescription(percentText)
    }
    
    private static func percentText(for amount: Double) -> String {
        return amount.formatted(FloatingPointFormatStyle<Double>.Percent().precision(.fractionLength(0)))
    }
    
    // MARK: - Actions
    @objc private func themeChanged() {
        guard
            let rawValue: String = themePopUpButton.selectedItem?.representedObject as? String,
            let theme: AppTheme = AppTheme(rawValue: rawValue)
        else { return }
        
        // Tracked after the change, so the shared parameters carry the new value.
        AppThemeManager.shared.setTheme(theme)
        trackAction("appearance_Theme")
        reload()
    }
    
    @objc private func matchSystemChanged() {
        AppThemeManager.shared.setGlassTintMatchesSystem(matchSystemSwitch.state == .on)
        trackAction("appearance_GlassMatchSystem")
        reload()
    }
    
    /// Applies every step while dragging so the glass changes live, and tracks the change once when the press ends.
    /// - Note: Keyboard and VoiceOver changes have no mouse event, so each one tracks.
    @objc private func tintChanged() {
        AppThemeManager.shared.setGlassTintAmount(tintSlider.doubleValue)
        reloadTintValueLabel()
        
        let eventType: NSEvent.EventType? = NSApplication.shared.currentEvent?.type
        
        if eventType != .leftMouseDown && eventType != .leftMouseDragged {
            trackAction("appearance_GlassTint")
        }
    }
    
    // MARK: - Analytics
    private func trackAction(_ title: String) {
        let event: PageViewEvent = PageViewEvent(title: title)
        Analytics.shared.track(event: event)
    }
}
