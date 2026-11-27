//
//  FloatingWindowCardView.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout

/// One card of the floating window: a titled column of stats, with values that update in place.
final class FloatingWindowCardView: NSView {
    
    private var valueLabels: [FloatingWindowLayout.Stat: NSTextField] = [:]
    private var barViews: [FloatingWindowLayout.Stat: SpeedBarView] = [:]
    private var openSettingsImageView: NSImageView?
    
    /// Set on a turned off card, so a click opens the Sensors pane where the temperature can be turned back on.
    var onClick: (() -> Void)? {
        didSet {
            openSettingsImageView?.isHidden = onClick == nil
            window?.invalidateCursorRects(for: self)
        }
    }
    
    /// The window's glass corner radius minus its content inset, so the cells' corners run parallel to the window's.
    private static let cornerRadius: CGFloat = 10.0
    private static let padding: CGFloat = 10.0
    private static let rowSpacing: CGFloat = 4.0
    private static let headerSpacing: CGFloat = 5.0
    private static let titleValueSpacing: CGFloat = 12.0
    private static let iconSize: CGFloat = 13.0
    private static let iconConfiguration: NSImage.SymbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10.0, weight: .semibold)
    /// The widest card symbol, so every symbol centers in the same slot and the titles line up down the window.
    private static let iconWidth: CGFloat = {
        let widths: [CGFloat] = FloatingWindowContent.cardSymbols.compactMap({ NSImage(systemSymbol: $0, accessibilityDescription: nil).withSymbolConfiguration(iconConfiguration)?.size.width })
        return ceil(widths.max() ?? iconSize)
    }()
    /// Tight, so the symbol reads as part of the title rather than a separate item.
    private static let iconTitleSpacing: CGFloat = 3.0
    private static let barHeight: CGFloat = 4.0
    private static let barRowHeight: CGFloat = 10.0
    private static let titleFont: NSFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
    private static let statTitleFont: NSFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
    private static let valueFont: NSFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
    /// Every value row is this tall, whatever it holds, so a value, a dash, or the turned off note never changes the card's height.
    private static let valueRowHeight: CGFloat = (valueFont.ascender - valueFont.descender + valueFont.leading).rounded(.up)
    /// A quick crossfade, so a changed value eases in instead of jumping.
    private static let valueTransitionDuration: TimeInterval = 0.12
    
    /// How far the pointer moves while pressed before the press becomes a window drag instead of a click.
    private static let dragThreshold: CGFloat = 3.0
    
    // MARK: - Init
    init(card: FloatingWindowContent.Card, unit: FannySettings.TemperatureUnit) {
        super.init(frame: CGRect.zero)
        setup(card: card, unit: unit)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setup(card: FloatingWindowContent.Card, unit: FannySettings.TemperatureUnit) {
        // A soft fill one layer above the glass, so each card reads as its own cell.
        wantsLayer = true
        layer?.cornerRadius = FloatingWindowCardView.cornerRadius
        layer?.cornerCurve = .continuous
        
        let padding: CGFloat = FloatingWindowCardView.padding
        let headerView: NSView = makeHeader(card: card)
        addSubview(headerView)
        headerView.autoPinEdge(toSuperviewEdge: .top, withInset: padding)
        headerView.autoPinEdge(toSuperviewEdge: .leading, withInset: padding)
        headerView.autoPinEdge(toSuperviewEdge: .trailing, withInset: padding, relation: .greaterThanOrEqual)
        
        var rowViews: [NSView] = []
        
        if card.isTurnedOff {
            rowViews.append(makeTurnedOffRow())
        }
        
        for row in card.rows {
            rowViews.append(makeRow(row, valueWidth: FloatingWindowCardView.valueWidth(for: row.stat, unit: unit)))
        }
        
        var previousView: NSView = headerView
        var spacing: CGFloat = FloatingWindowCardView.headerSpacing
        
        for rowView in rowViews {
            addSubview(rowView)
            rowView.autoPinEdge(.top, to: .bottom, of: previousView, withOffset: spacing)
            rowView.autoPinEdge(toSuperviewEdge: .leading, withInset: padding)
            rowView.autoPinEdge(toSuperviewEdge: .trailing, withInset: padding)
            previousView = rowView
            spacing = FloatingWindowCardView.rowSpacing
        }
        
        // Rows sit at the top, so a card stretched to match a taller neighbor keeps its rows in place.
        previousView.autoPinEdge(toSuperviewEdge: .bottom, withInset: padding, relation: .greaterThanOrEqual)
        // As big as every row the card shows when its temperature is on, so turning it off or on never resizes the card.
        autoSetDimension(.height, toSize: FloatingWindowCardView.height(for: card), relation: .greaterThanOrEqual)
        autoSetDimension(.width, toSize: FloatingWindowCardView.width(for: card, unit: unit), relation: .greaterThanOrEqual)
        
        update(card: card)
    }
    
    private func makeHeader(card: FloatingWindowContent.Card) -> NSView {
        let headerView: NSView = NSView()
        
        let iconImageView: PassthroughImageView = PassthroughImageView()
        iconImageView.image = NSImage(systemSymbol: card.symbol, accessibilityDescription: nil)
        iconImageView.symbolConfiguration = FloatingWindowCardView.iconConfiguration
        iconImageView.contentTintColor = NSColor.secondaryLabelColor
        headerView.addSubview(iconImageView)
        
        let titleLabel: NSTextField = NSTextField(labelWithString: card.title)
        titleLabel.font = FloatingWindowCardView.titleFont
        titleLabel.textColor = NSColor.secondaryLabelColor
        headerView.addSubview(titleLabel)
        
        iconImageView.autoSetDimensions(to: CGSize(width: FloatingWindowCardView.iconWidth, height: FloatingWindowCardView.iconSize))
        iconImageView.autoPinEdge(toSuperviewEdge: .leading)
        iconImageView.autoPinEdge(toSuperviewEdge: .top)
        iconImageView.autoPinEdge(toSuperviewEdge: .bottom)
        titleLabel.autoPinEdge(.leading, to: .trailing, of: iconImageView, withOffset: FloatingWindowCardView.iconTitleSpacing)
        titleLabel.autoAlignAxis(.horizontal, toSameAxisOf: iconImageView)
        titleLabel.autoPinEdge(toSuperviewEdge: .trailing)
        
        return headerView
    }
    
    /// The turned off note, with an arrow where the temperature would be that shows once a click on the card opens Settings.
    private func makeTurnedOffRow() -> NSView {
        let rowView: NSView = NSView()
        
        let turnedOffLabel: NSTextField = NSTextField(labelWithString: FloatingWindowContent.turnedOffText)
        turnedOffLabel.font = FloatingWindowCardView.statTitleFont
        turnedOffLabel.textColor = NSColor.secondaryLabelColor
        turnedOffLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        rowView.addSubview(turnedOffLabel)
        
        let imageView: PassthroughImageView = PassthroughImageView()
        imageView.image = NSImage(systemSymbol: .arrowForwardCircleFill, accessibilityDescription: nil)
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: FloatingWindowCardView.valueFont.pointSize, weight: .semibold)
        imageView.contentTintColor = NSColor.secondaryLabelColor
        imageView.isHidden = onClick == nil
        rowView.addSubview(imageView)
        openSettingsImageView = imageView
        
        rowView.autoSetDimension(.height, toSize: FloatingWindowCardView.valueRowHeight)
        turnedOffLabel.autoPinEdge(toSuperviewEdge: .leading)
        turnedOffLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        imageView.autoAlignAxis(toSuperviewAxis: .horizontal)
        imageView.autoPinEdge(toSuperviewEdge: .trailing)
        imageView.autoPinEdge(.leading, to: .trailing, of: turnedOffLabel, withOffset: FloatingWindowCardView.titleValueSpacing, relation: .greaterThanOrEqual)
        
        return rowView
    }
    
    private func makeRow(_ row: FloatingWindowContent.Row, valueWidth: CGFloat) -> NSView {
        let rowView: NSView = NSView()
        
        switch row.style {
        case .value:
            let statTitleLabel: NSTextField = NSTextField(labelWithString: row.title)
            statTitleLabel.font = FloatingWindowCardView.statTitleFont
            statTitleLabel.textColor = NSColor.secondaryLabelColor
            statTitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            rowView.addSubview(statTitleLabel)
            
            let valueLabel: NSTextField = NSTextField(labelWithString: "")
            valueLabel.font = FloatingWindowCardView.valueFont
            valueLabel.textColor = NSColor.labelColor
            valueLabel.alignment = .right
            rowView.addSubview(valueLabel)
            valueLabels[row.stat] = valueLabel
            
            rowView.autoSetDimension(.height, toSize: FloatingWindowCardView.valueRowHeight)
            statTitleLabel.autoPinEdge(toSuperviewEdge: .leading)
            statTitleLabel.autoAlignAxis(.lastBaseline, toSameAxisOf: valueLabel)
            valueLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
            valueLabel.autoPinEdge(toSuperviewEdge: .trailing)
            // Wide enough for the widest value, so the card keeps its width as the readings change.
            valueLabel.autoSetDimension(.width, toSize: valueWidth, relation: .greaterThanOrEqual)
            valueLabel.autoPinEdge(.leading, to: .trailing, of: statTitleLabel, withOffset: FloatingWindowCardView.titleValueSpacing, relation: .greaterThanOrEqual)
        case .bar:
            let barView: SpeedBarView = SpeedBarView()
            rowView.addSubview(barView)
            barViews[row.stat] = barView
            rowView.autoSetDimension(.height, toSize: FloatingWindowCardView.barRowHeight)
            barView.autoAlignAxis(toSuperviewAxis: .horizontal)
            barView.autoPinEdge(toSuperviewEdge: .leading)
            barView.autoPinEdge(toSuperviewEdge: .trailing)
            barView.autoSetDimension(.height, toSize: FloatingWindowCardView.barHeight)
            barView.autoSetDimension(.width, toSize: valueWidth, relation: .greaterThanOrEqual)
        }
        
        return rowView
    }
    
    /// The padding and the widest row the card shows with its temperature on or off.
    private static func width(for card: FloatingWindowContent.Card, unit: FannySettings.TemperatureUnit) -> CGFloat {
        var rowWidths: [CGFloat] = card.reservedStats.map({ stat in
            let titleWidth: CGFloat = stat == FloatingWindowLayout.Stat.fanSpeedBar ? 0.0 : textWidth(FloatingWindowContent.title(for: stat), font: statTitleFont) + titleValueSpacing
            return titleWidth + valueWidth(for: stat, unit: unit)
        })
        
        if card.isTurnedOff {
            rowWidths.append(textWidth(FloatingWindowContent.turnedOffText, font: statTitleFont) + titleValueSpacing + valueFont.pointSize)
        }
        
        return padding * 2.0 + (rowWidths.max() ?? 0.0).rounded(.up)
    }
    
    /// The padding, header, and every row the card shows when its temperature is on.
    private static func height(for card: FloatingWindowContent.Card) -> CGFloat {
        let rowHeights: [CGFloat] = card.reservedStats.map({ $0 == FloatingWindowLayout.Stat.fanSpeedBar ? barRowHeight : valueRowHeight })
        let rowsHeight: CGFloat = rowHeights.reduce(0.0, +) + rowSpacing * CGFloat(max(rowHeights.count - 1, 0))
        let turnedOffHeight: CGFloat = card.isTurnedOff ? valueRowHeight : 0.0
        return padding * 2.0 + iconSize + headerSpacing + max(rowsHeight, turnedOffHeight)
    }
    
    // MARK: - Update
    /// Touches a label only when its text changed, so a refresh every second stays cheap.
    func update(card: FloatingWindowContent.Card) {
        for row in card.rows {
            switch row.style {
            case .value(let text):
                guard let valueLabel: NSTextField = valueLabels[row.stat], valueLabel.stringValue != text else { continue }
                FloatingWindowCardView.addCrossfade(to: valueLabel)
                valueLabel.stringValue = text
            case .bar(let fraction):
                barViews[row.stat]?.fraction = fraction
            }
        }
    }
    
    // MARK: - Drawing
    override var wantsUpdateLayer: Bool {
        return true
    }
    
    override func updateLayer() {
        super.updateLayer()
        // Resolved here, so the fill follows light and dark mode.
        layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
    }
    
    // MARK: - Mouse
    /// A clickable card takes the click itself, instead of its labels passing it on as a window drag.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard onClick != nil else { return super.hitTest(point) }
        return frame.contains(point) ? self : nil
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return onClick == nil
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        guard onClick != nil else { return }
        addCursorRect(bounds, cursor: NSCursor.pointingHand)
    }
    
    /// A press that moves still drags the window, so the whole window can be grabbed. A press that stays put clicks.
    override func mouseDown(with event: NSEvent) {
        guard
            let onClick: () -> Void = onClick,
            let window: NSWindow = window
        else {
            super.mouseDown(with: event)
            return
        }
        
        let startLocation: CGPoint = event.locationInWindow
        var isTracking: Bool = true
        
        while isTracking, let nextEvent: NSEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let location: CGPoint = nextEvent.locationInWindow
            
            if nextEvent.type == .leftMouseUp {
                isTracking = false
                
                if bounds.contains(convert(location, from: nil)) {
                    onClick()
                }
            }
            else if hypot(location.x - startLocation.x, location.y - startLocation.y) >= FloatingWindowCardView.dragThreshold {
                isTracking = false
                window.performDrag(with: event)
            }
        }
    }
    
    // MARK: - Helpers
    /// Reduce Motion turns the crossfade off, so the value just changes.
    private static func addCrossfade(to label: NSTextField) {
        guard NSWorkspace.shared.accessibilityDisplayShouldReduceMotion == false else { return }
        label.wantsLayer = true
        
        let transition: CATransition = CATransition()
        transition.type = .fade
        transition.duration = valueTransitionDuration
        label.layer?.add(transition, forKey: "valueCrossfade")
    }
    
    /// The widest text a stat shows in this unit, measured once per layout.
    private static func valueWidth(for stat: FloatingWindowLayout.Stat, unit: FannySettings.TemperatureUnit) -> CGFloat {
        let sampleText: String
        
        switch stat {
        case .cpuTemperature, .cpuAverage, .cpuHottest, .cpuDie, .gpuTemperature, .gpuAverage, .gpuHottest:
            // Above any real reading in every unit, so a hot Mac never widens the card.
            sampleText = ReadingFormatter.temperatureText(TemperatureReading(celsius: 188.0), unit: unit, style: .compact)
        case .fanSpeed, .fanSpeedBar, .fanTarget, .fanMinimum, .fanMaximum:
            sampleText = ReadingFormatter.rpmText(8888.0)
        }
        
        return textWidth(sampleText, font: valueFont).rounded(.up)
    }
    
    private static func textWidth(_ text: String, font: NSFont) -> CGFloat {
        return NSAttributedString(string: text, attributes: [.font: font]).size().width
    }
}

// MARK: - SpeedBarView
/// A thin capsule filled from the fan's minimum to its current speed.
private final class SpeedBarView: NSView {
    
    private let fillLayer: CALayer = CALayer()
    
    /// `nil` draws an empty track.
    var fraction: Double? {
        didSet {
            guard fraction != oldValue else { return }
            needsLayout = true
        }
    }
    
    // MARK: - Init
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(fillLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Layout
    override func layout() {
        super.layout()
        let radius: CGFloat = bounds.height / 2.0
        layer?.cornerRadius = radius
        fillLayer.cornerRadius = radius
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let width: CGFloat = bounds.width * CGFloat(fraction ?? 0.0)
        let x: CGFloat = userInterfaceLayoutDirection == .rightToLeft ? bounds.width - width : 0.0
        fillLayer.frame = CGRect(x: x, y: 0.0, width: width, height: bounds.height)
        CATransaction.commit()
    }
    
    override func updateLayer() {
        super.updateLayer()
        // Resolved here, so the colors follow light and dark mode.
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        fillLayer.backgroundColor = NSColor.labelColor.cgColor
    }
    
    override var wantsUpdateLayer: Bool {
        return true
    }
}

// MARK: - PassthroughImageView
/// An image view that drags the window when pressed, like the rest of the window. Image views opt out of this by default.
private final class PassthroughImageView: NSImageView {
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
}
