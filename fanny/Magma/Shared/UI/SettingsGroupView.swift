//
//  SettingsGroupView.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout

/// A rounded card that stacks rows with hairline separators, like a group in System Settings.
final class SettingsGroupView: NSView {
    
    /// Tints the card so rows that need the user to act stand out.
    var isWarning: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    var hasVisibleRows: Bool {
        return rows.contains(where: { $0.isHidden == false })
    }
    
    private let stackView: NSStackView = NSStackView()
    private var rows: [NSView] = []
    private var separators: [ObjectIdentifier: NSView] = [:]
    
    private static let cornerRadius: CGFloat = 10.0
    private static let separatorInset: CGFloat = 16.0
    private static let warningBackgroundAlpha: CGFloat = 0.14
    private static let warningBorderAlpha: CGFloat = 0.7
    
    override var wantsUpdateLayer: Bool {
        return true
    }
    
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
        wantsLayer = true
        layer?.cornerRadius = SettingsGroupView.cornerRadius
        layer?.borderWidth = 1.0
        layer?.masksToBounds = true
        
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0.0
        addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
    }
    
    // MARK: - Rows
    func addRow(_ row: NSView) {
        if stackView.arrangedSubviews.isEmpty == false {
            let separator: NSView = SettingsGroupView.makeSeparator()
            stackView.addArrangedSubview(separator)
            separator.autoPinEdge(toSuperviewEdge: .leading)
            separator.autoPinEdge(toSuperviewEdge: .trailing)
            separators[ObjectIdentifier(row)] = separator
        }
        
        stackView.addArrangedSubview(row)
        row.autoPinEdge(toSuperviewEdge: .leading)
        row.autoPinEdge(toSuperviewEdge: .trailing)
        rows.append(row)
    }
    
    /// Hides a row together with its separator, so the first visible row never has a line above it.
    func setRowHidden(_ row: NSView, hidden: Bool) {
        row.isHidden = hidden
        updateSeparators()
    }
    
    private func updateSeparators() {
        var hasVisibleRowAbove: Bool = false
        
        for row in rows {
            separators[ObjectIdentifier(row)]?.isHidden = (row.isHidden || hasVisibleRowAbove == false)
            
            if row.isHidden == false {
                hasVisibleRowAbove = true
            }
        }
    }
    
    // MARK: - Appearance
    override func updateLayer() {
        super.updateLayer()
        
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if isWarning {
                layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(SettingsGroupView.warningBackgroundAlpha).cgColor
                layer?.borderColor = NSColor.systemOrange.withAlphaComponent(SettingsGroupView.warningBorderAlpha).cgColor
            }
            else {
                layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
                layer?.borderColor = NSColor.separatorColor.cgColor
            }
        }
    }
    
    // MARK: - Helpers
    private static func makeSeparator() -> NSView {
        let container: NSView = NSView()
        let box: NSBox = NSBox()
        box.boxType = .separator
        container.addSubview(box)
        box.autoPinEdge(toSuperviewEdge: .leading, withInset: separatorInset)
        box.autoPinEdge(toSuperviewEdge: .trailing)
        box.autoPinEdge(toSuperviewEdge: .top)
        box.autoPinEdge(toSuperviewEdge: .bottom)
        container.autoSetDimension(.height, toSize: 1.0)
        return container
    }
}
