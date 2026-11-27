//
//  SettingsRowView.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout

/// A single row of a settings card with an optional leading icon, a title, an optional subtitle, and an optional trailing control.
final class SettingsRowView: NSView {
    
    private let titleLabel: NSTextField = NSTextField(wrappingLabelWithString: "")
    private let subtitleLabel: NSTextField = NSTextField(wrappingLabelWithString: "")
    private let labelStackView: NSStackView = NSStackView()
    
    private var control: NSView?
    
    private static let minimumHeight: CGFloat = 44.0
    private static let horizontalInset: CGFloat = 16.0
    private static let verticalInset: CGFloat = 10.0
    private static let controlSpacing: CGFloat = 12.0
    private static let infoButtonSpacing: CGFloat = 4.0
    private static let iconSize: CGFloat = 44.0
    private static let iconSpacing: CGFloat = 10.0
    /// A quick crossfade for a changed subtitle, button title, or spinner, so a status change is not jarring.
    static let subtitleTransitionDuration: TimeInterval = 0.12
    
    // MARK: - Init
    init(title: String, subtitle: String? = nil, icon: NSImage? = nil, control: NSView? = nil, infoButton: NSButton? = nil) {
        self.control = control
        super.init(frame: CGRect.zero)
        setup(title: title, subtitle: subtitle, icon: icon, infoButton: infoButton)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setup(title: String, subtitle: String?, icon: NSImage?, infoButton: NSButton?) {
        titleLabel.stringValue = title
        titleLabel.isSelectable = false
        subtitleLabel.isSelectable = false
        titleLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        titleLabel.textColor = NSColor.labelColor
        
        subtitleLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        setSubtitle(subtitle)
        
        labelStackView.orientation = .vertical
        labelStackView.alignment = .leading
        labelStackView.spacing = 2.0
        
        if let infoButton: NSButton = infoButton {
            infoButton.setContentHuggingPriority(.required, for: .horizontal)
            infoButton.setContentCompressionResistancePriority(.required, for: .horizontal)
            let titleStackView: NSStackView = NSStackView(views: [titleLabel, infoButton])
            titleStackView.orientation = .horizontal
            titleStackView.alignment = .centerY
            titleStackView.spacing = SettingsRowView.infoButtonSpacing
            labelStackView.addArrangedSubview(titleStackView)
        }
        else {
            labelStackView.addArrangedSubview(titleLabel)
        }
        
        labelStackView.addArrangedSubview(subtitleLabel)
        addSubview(labelStackView)
        
        autoSetDimension(.height, toSize: SettingsRowView.minimumHeight, relation: .greaterThanOrEqual)
        
        if let icon: NSImage = icon {
            let iconView: NSImageView = NSImageView(image: icon)
            iconView.imageScaling = .scaleProportionallyUpOrDown
            // Decorative, since the title already names what the icon shows.
            iconView.hideFromAccessibility()
            addSubview(iconView)
            iconView.autoSetDimensions(to: CGSize(width: SettingsRowView.iconSize, height: SettingsRowView.iconSize))
            iconView.autoPinEdge(toSuperviewEdge: .leading, withInset: SettingsRowView.horizontalInset)
            iconView.autoAlignAxis(toSuperviewAxis: .horizontal)
            labelStackView.autoPinEdge(.leading, to: .trailing, of: iconView, withOffset: SettingsRowView.iconSpacing)
        }
        else {
            labelStackView.autoPinEdge(toSuperviewEdge: .leading, withInset: SettingsRowView.horizontalInset)
        }
        
        labelStackView.autoPinEdge(toSuperviewEdge: .top, withInset: SettingsRowView.verticalInset, relation: .greaterThanOrEqual)
        labelStackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: SettingsRowView.verticalInset, relation: .greaterThanOrEqual)
        labelStackView.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        if let control: NSView = control {
            // The control carries the row's name and subtitle, so the separate labels would be read twice.
            titleLabel.hideFromAccessibility()
            subtitleLabel.hideFromAccessibility()
            
            for target in SettingsRowView.accessibilityTargets(of: control) where SettingsRowView.visibleButtonTitle(of: target).isEmpty {
                target.setAccessibilityLabel(title)
            }
            
            updateControlHelp(subtitle: subtitle)
            
            control.setContentHuggingPriority(.required, for: .horizontal)
            control.setContentCompressionResistancePriority(.required, for: .horizontal)
            addSubview(control)
            control.autoPinEdge(toSuperviewEdge: .trailing, withInset: SettingsRowView.horizontalInset)
            control.autoAlignAxis(toSuperviewAxis: .horizontal)
            labelStackView.autoPinEdge(.trailing, to: .leading, of: control, withOffset: -SettingsRowView.controlSpacing)
        }
        else {
            labelStackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: SettingsRowView.horizontalInset)
        }
    }
    
    // MARK: - Title
    /// Changes the title after setup, such as a fan's default name when its naming style changes.
    /// - Note: A control without its own visible title is renamed too, and a titled one gets the new title in its help, so VoiceOver reads it.
    func updateTitle(_ title: String) {
        titleLabel.stringValue = title
        
        if let control: NSView = control {
            for target in SettingsRowView.accessibilityTargets(of: control) where SettingsRowView.visibleButtonTitle(of: target).isEmpty {
                target.setAccessibilityLabel(title)
            }
        }
        
        updateControlHelp(subtitle: subtitleLabel.isHidden ? nil : subtitleLabel.stringValue)
    }
    
    // MARK: - Subtitle
    /// Changes the subtitle after setup, along with the control's help text that repeats it.
    /// - Parameter animated: Crossfades a changed subtitle quickly, so a status that changes on its own is not jarring.
    func updateSubtitle(_ subtitle: String?, animated: Bool = false) {
        if animated, subtitle != subtitleLabel.stringValue, NSWorkspace.shared.accessibilityDisplayShouldReduceMotion == false {
            subtitleLabel.wantsLayer = true
            let transition: CATransition = CATransition()
            transition.type = .fade
            transition.duration = SettingsRowView.subtitleTransitionDuration
            subtitleLabel.layer?.add(transition, forKey: "subtitleCrossfade")
        }
        
        setSubtitle(subtitle)
        updateControlHelp(subtitle: subtitle)
    }
    
    private func setSubtitle(_ subtitle: String?) {
        subtitleLabel.stringValue = subtitle ?? ""
        subtitleLabel.isHidden = (subtitle == nil)
    }
    
    /// A control named by its own button title also gets the row's title in its help, so neither is lost.
    private func updateControlHelp(subtitle: String?) {
        guard let control: NSView = control else { return }
        
        for target in SettingsRowView.accessibilityTargets(of: control) {
            let helpText: String?
            
            if SettingsRowView.visibleButtonTitle(of: target).isEmpty {
                helpText = subtitle
            }
            else {
                helpText = [titleLabel.stringValue, subtitle].compactMap({ $0 }).joined(separator: ". ")
            }
            
            target.setAccessibilityHelp(helpText)
        }
    }
    
    /// A plain container, such as a stack of buttons or a button beside a spinner, is not an accessibility element,
    /// so the row's title and subtitle go on the controls inside it.
    private static func accessibilityTargets(of control: NSView) -> [NSView] {
        let targets: [NSView]
        
        if control is NSControl {
            targets = [control]
        }
        else {
            targets = control.subviews.flatMap({ accessibilityTargets(of: $0) }).filter({ $0 is NSControl })
        }
        
        return targets
    }
    
    /// A titled button keeps its visible title as its name so Voice Control can match it. A pop-up's title is its
    /// selected item, not its name, so it takes the row's title.
    private static func visibleButtonTitle(of control: NSView) -> String {
        return (control is NSPopUpButton) ? "" : ((control as? NSButton)?.title ?? "")
    }
}
