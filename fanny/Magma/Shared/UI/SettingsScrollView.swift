//
//  SettingsScrollView.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout

/// A scroll view that holds a vertical stack of settings groups at a fixed content width.
final class SettingsScrollView: NSScrollView {
    
    private let stackView: NSStackView = NSStackView()
    
    private static let contentWidth: CGFloat = 460.0
    
    private static let verticalInset: CGFloat = 20.0
    private static let sectionSpacing: CGFloat = 20.0
    private static let captionSpacing: CGFloat = 6.0
    private static let captionInset: CGFloat = 12.0
    
    // MARK: - Init
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setup() {
        hasVerticalScroller = true
        hasHorizontalScroller = false
        drawsBackground = false
        borderType = .noBorder
        autohidesScrollers = true
        
        let documentView: FlippedView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        self.documentView = documentView
        documentView.autoPinEdge(toSuperviewEdge: .top)
        documentView.autoPinEdge(toSuperviewEdge: .leading)
        documentView.autoPinEdge(toSuperviewEdge: .trailing)
        
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = SettingsScrollView.sectionSpacing
        documentView.addSubview(stackView)
        stackView.autoPinEdge(toSuperviewEdge: .top, withInset: SettingsScrollView.verticalInset)
        stackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: SettingsScrollView.verticalInset)
        stackView.autoAlignAxis(toSuperviewAxis: .vertical)
        stackView.autoSetDimension(.width, toSize: SettingsScrollView.contentWidth)
    }
    
    // MARK: - Groups
    /// Adds a group with an optional header above it and an optional footnote below it.
    /// - Parameter headerDetail: A view between the header and the group, such as a label the caller updates later.
    /// - Returns: The footnote label, so a caller can change or hide it later.
    @discardableResult
    func addGroup(_ group: NSView, header: String? = nil, headerDetail: NSView? = nil, footer: String? = nil) -> NSTextField? {
        var footerLabel: NSTextField?
        let sectionStackView: NSStackView = NSStackView()
        sectionStackView.orientation = .vertical
        sectionStackView.alignment = .leading
        sectionStackView.spacing = SettingsScrollView.captionSpacing
        
        if let header: String = header {
            let headerLabel: NSTextField = SettingsScrollView.makeCaptionLabel(header, font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold))
            headerLabel.setAccessibilityRole(NSAccessibility.Role(rawValue: "AXHeading"))
            sectionStackView.addArrangedSubview(headerLabel)
            headerLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: SettingsScrollView.captionInset)
            headerLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: SettingsScrollView.captionInset)
        }
        
        if let headerDetail: NSView = headerDetail {
            sectionStackView.addArrangedSubview(headerDetail)
            headerDetail.autoPinEdge(toSuperviewEdge: .leading, withInset: SettingsScrollView.captionInset)
            headerDetail.autoPinEdge(toSuperviewEdge: .trailing, withInset: SettingsScrollView.captionInset)
        }
        
        sectionStackView.addArrangedSubview(group)
        group.autoPinEdge(toSuperviewEdge: .leading)
        group.autoPinEdge(toSuperviewEdge: .trailing)
        
        if let footer: String = footer {
            let label: NSTextField = SettingsScrollView.makeCaptionLabel(footer, font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize))
            sectionStackView.addArrangedSubview(label)
            label.autoPinEdge(toSuperviewEdge: .leading, withInset: SettingsScrollView.captionInset)
            label.autoPinEdge(toSuperviewEdge: .trailing, withInset: SettingsScrollView.captionInset)
            footerLabel = label
        }
        
        stackView.addArrangedSubview(sectionStackView)
        sectionStackView.autoPinEdge(toSuperviewEdge: .leading)
        sectionStackView.autoPinEdge(toSuperviewEdge: .trailing)
        return footerLabel
    }
    
    /// Hides a group added with `addGroup` together with its header and footnote.
    func setGroupHidden(_ group: NSView, hidden: Bool) {
        group.superview?.isHidden = hidden
    }
    
    // MARK: - Helpers
    private static func makeCaptionLabel(_ text: String, font: NSFont) -> NSTextField {
        let label: NSTextField = NSTextField(wrappingLabelWithString: text)
        label.isSelectable = false
        label.font = font
        label.textColor = NSColor.secondaryLabelColor
        return label
    }
}

/// A view whose origin is at the top left, so scrolled content starts at the top.
private final class FlippedView: NSView {
    
    override var isFlipped: Bool {
        return true
    }
    
    /// A click on the pane's background ends text editing, so a typed value is saved like it is in System Settings.
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }
}
