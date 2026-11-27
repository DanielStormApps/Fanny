//
//  FloatingWindowViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout
import SFSafeSymbols

/// The glass window that shows the chosen cards, with a close badge on hover and the menu bar actions on right click.
/// - Note: The view is larger than the glass so the close badge can sit centered on the glass's top leading corner.
final class FloatingWindowViewController: ViewController {
    
    private let glassView: NSGlassEffectView = NSGlassEffectView()
    private let contentView: NSView = NSView()
    private let cardsContainerView: NSView = NSView()
    private let emptyLabel: NSTextField = NSTextField(labelWithString: FloatingWindowContent.emptyText)
    /// Holds the cards while they glide to a new layout, measured from the top left corner so their frames stay put as the window resizes below them.
    private let relayoutOverlayView: FlippedView = FlippedView()
    private let closeHitView: NSView = NSView()
    private let closeGlassView: NSGlassEffectView = NSGlassEffectView()
    private let closeButton: HoverGrowButton = HoverGrowButton()
    /// A preview in Settings shows the live readings but never reacts to the pointer.
    private let isPreview: Bool
    
    var contextMenuProvider: (() -> NSMenu?)?
    /// Called with the new size after cards are added, removed, or reordered.
    var sizeDidChange: ((CGSize) -> Void)?
    
    private var isHovering: Bool = false
    private var lastContent: FloatingWindowContent?
    private var lastUnit: FannySettings.TemperatureUnit?
    private var lastSettings: FannySettings?
    private var lastSnapshotDate: Date?
    private var cardViews: [FloatingWindowCardView] = []
    private var cardKinds: [FloatingWindowLayout.CardKind] = []
    /// Bumped on every rebuild, so a finished glide never touches cards a later rebuild replaced.
    private var relayoutGeneration: Int = 0
    private var glassConstraints: [NSLayoutConstraint] = []
    /// Refreshes the window's shadow every frame while the glass changes size, since the system only recomputes it when asked.
    private var shadowDisplayLink: CADisplayLink?
    /// The window frame and orientation a running glide ends on, so a rebuild mid-glide can settle it first.
    private var pendingRelayout: (window: NSWindow, frame: CGRect, isHorizontal: Bool)?
    
    private static let cornerRadius: CGFloat = 18.0
    private static let contentInset: CGFloat = 8.0
    private static let cardSpacing: CGFloat = 8.0
    
    /// The minus badge from Home Screen edit mode, scaled down for the smaller window.
    private static let closeButtonSize: CGFloat = 16.0
    
    /// The HIG minimum clickable size on macOS. The glass badge is smaller, so the click area extends past it.
    private static let closeHitSize: CGFloat = 20.0
    
    /// How far the rounded corner sits inside its square corner along the diagonal, so the badge centers on the curve like an iOS icon's badge.
    private static let cornerCurveInset: CGFloat = cornerRadius * (1.0 - 1.0 / 2.0.squareRoot())
    
    /// Leaves room for the half of the badge that hangs outside the glass, rounded to a half point so the glass lands on whole pixels.
    private static let glassInset: CGFloat = ((closeHitSize / 2.0 - cornerCurveInset) * 2.0).rounded() / 2.0
    
    private static let hoverAnimationDuration: TimeInterval = 0.15
    private static let relayoutAnimationDuration: TimeInterval = 0.3
    
    // MARK: - Init
    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Cycle
    override func loadView() {
        view = NSView(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 120.0, height: 60.0)))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // The Settings pane is "floatingWindow", so the window itself is tracked apart from it.
        analytics(title: "floatingWindowPanel")
        analyticsIsEnabled = isPreview == false
        setupGlassView()
        setupContent()
        setupCloseButton()
        setupTrackingArea()
        update()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        setHovering(false)
    }
    
    // MARK: - Setup
    private func setupGlassView() {
        let inset: CGFloat = FloatingWindowViewController.glassInset
        glassView.cornerRadius = FloatingWindowViewController.cornerRadius
        
        // A bare NSView is not an accessibility element, so the glass is the one stop that speaks every reading.
        glassView.setAccessibilityElement(true)
        glassView.setAccessibilityRole(.group)
        glassView.setAccessibilityLabel(String(localized: "Floating Window", comment: "Accessibility label of the floating window. Also the menu item and Settings pane that show or customize it."))
        // Hidden views are skipped, not pruned, so without this the cards' labels and icons would still be reachable inside the group.
        glassView.setAccessibilityChildren([])
        
        view.addSubview(glassView)
        glassConstraints = glassView.autoPinEdgesToSuperviewEdges(with: NSEdgeInsets(top: inset, left: inset, bottom: inset, right: inset))
    }
    
    private func setupContent() {
        glassView.contentView = contentView
        
        cardsContainerView.hideFromAccessibility()
        contentView.addSubview(cardsContainerView)
        let contentInset: CGFloat = FloatingWindowViewController.contentInset
        cardsContainerView.autoPinEdgesToSuperviewEdges(with: NSEdgeInsets(top: contentInset, left: contentInset, bottom: contentInset, right: contentInset))
        
        emptyLabel.font = NSFont.systemFont(ofSize: NSFont.preferredFont(forTextStyle: .callout).pointSize, weight: .medium)
        emptyLabel.textColor = NSColor.secondaryLabelColor
        emptyLabel.hideFromAccessibility()
        
        relayoutOverlayView.hideFromAccessibility()
        view.addSubview(relayoutOverlayView)
        relayoutOverlayView.autoPinEdgesToSuperviewEdges()
    }
    
    /// A small glass circle with a minus, like removing an app from the Home Screen, centered on the glass's top leading corner.
    private func setupCloseButton() {
        let title: String = String(localized: "Close Floating Window", comment: "Floating window: hides the floating window.")
        
        closeHitView.alphaValue = 0.0
        // A window passes clicks on fully clear pixels to whatever is behind it, so the area around the badge needs a trace of fill.
        closeHitView.wantsLayer = true
        closeHitView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.01).cgColor
        view.addSubview(closeHitView)
        closeHitView.autoPinEdge(toSuperviewEdge: .top)
        closeHitView.autoPinEdge(toSuperviewEdge: .leading)
        closeHitView.autoSetDimensions(to: CGSize(width: FloatingWindowViewController.closeHitSize, height: FloatingWindowViewController.closeHitSize))
        
        closeGlassView.cornerRadius = FloatingWindowViewController.closeButtonSize / 2.0
        closeHitView.addSubview(closeGlassView)
        closeGlassView.autoCenterInSuperview()
        closeGlassView.autoSetDimensions(to: CGSize(width: FloatingWindowViewController.closeButtonSize, height: FloatingWindowViewController.closeButtonSize))
        
        closeButton.isBordered = false
        closeButton.imagePosition = .imageOnly
        closeButton.image = NSImage(systemSymbol: .minus, accessibilityDescription: title)
        closeButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9.0, weight: .bold)
        closeButton.contentTintColor = NSColor.labelColor
        closeButton.toolTip = title
        closeButton.setAccessibilityLabel(title)
        closeButton.target = self
        closeButton.action = #selector(closeButtonPressed)
        // On top of the glass and filling the click area, so a click just outside the badge still closes the window.
        closeHitView.addSubview(closeButton)
        closeButton.autoPinEdgesToSuperviewEdges()
        closeButton.growingView = closeHitView
    }
    
    private func setupTrackingArea() {
        // A preview keeps its close badge hidden.
        guard isPreview == false else {
            closeButton.isHoverEnabled = false
            closeButton.refusesFirstResponder = true
            closeHitView.isHidden = true
            return
        }
        
        let trackingArea: NSTrackingArea = NSTrackingArea(rect: view.bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        view.addTrackingArea(trackingArea)
    }
    
    // MARK: - Size
    /// The cards' size plus the glass padding and the room the close badge needs.
    var preferredSize: CGSize {
        return FloatingWindowViewController.windowSize(forCardsSize: cardsContainerView.fittingSize)
    }
    
    private static func windowSize(forCardsSize cardsSize: CGSize) -> CGSize {
        let padding: CGFloat = (contentInset + glassInset) * 2.0
        return CGSize(width: (cardsSize.width + padding).rounded(.up), height: (cardsSize.height + padding).rounded(.up))
    }
    
    // MARK: - Update
    /// Rebuilds the cards when the layout changed, and otherwise only updates their values.
    func update() {
        guard isViewLoaded else { return }
        
        let settings: FannySettings = FannySettingsManager.shared.settings
        let snapshot: ReadingsSnapshot? = SensorMonitor.shared.snapshot
        
        // A change to what is read waits for the read it starts, so the old snapshot never flashes a dash for a reading it does not have.
        if let lastSettings: FannySettings = lastSettings, snapshot?.capturedDate == lastSnapshotDate, SensorMonitor.changesReadings(from: lastSettings, to: settings) {
            return
        }
        
        lastSettings = settings
        lastSnapshotDate = snapshot?.capturedDate
        let content: FloatingWindowContent = FloatingWindowContent(snapshot: snapshot, settings: settings)
        guard content != lastContent || settings.temperatureUnit != lastUnit else { return }
        
        if let lastContent: FloatingWindowContent = lastContent, FloatingWindowViewController.hasSameLayout(lastContent, content), settings.temperatureUnit == lastUnit {
            for (cardView, card) in zip(cardViews, content.cards) {
                cardView.update(card: card)
            }
        }
        else {
            rebuildCards(content: content, unit: settings.temperatureUnit, animated: lastContent != nil && canAnimateRelayout)
        }
        
        if content.spokenText != lastContent?.spokenText {
            glassView.setAccessibilityValue(content.spokenText)
        }
        
        lastContent = content
        lastUnit = settings.temperatureUnit
    }
    
    /// Only a window on screen glides, and never with Reduce Motion on.
    private var canAnimateRelayout: Bool {
        return isPreview == false && view.window?.isVisible == true && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion == false
    }
    
    /// - Parameter animated: Glides the cards from their old places to their new ones while the window resizes, such as after the orientation changes or a card is added.
    private func rebuildCards(content: FloatingWindowContent, unit: FannySettings.TemperatureUnit, animated: Bool) {
        relayoutGeneration = relayoutGeneration + 1
        
        if let pendingRelayout: (window: NSWindow, frame: CGRect, isHorizontal: Bool) = pendingRelayout {
            finishRelayout(in: pendingRelayout.window, frame: pendingRelayout.frame, isHorizontal: pendingRelayout.isHorizontal)
        }
        
        let oldCards: [OldCard] = zip(cardKinds, cardViews).map({ kind, cardView in
            return OldCard(kind: kind, view: cardView, frame: relayoutOverlayView.convert(cardView.bounds, from: cardView))
        })
        
        // Clears the cards, fading views, and empty label the previous layout left behind.
        for subview in relayoutOverlayView.subviews + cardsContainerView.subviews {
            subview.removeFromSuperview()
        }
        
        let isHorizontal: Bool = content.orientation == FloatingWindowLayout.Orientation.horizontal
        
        cardViews = content.cards.map({ FloatingWindowCardView(card: $0, unit: unit) })
        cardKinds = content.cards.map({ $0.kind })
        
        if isPreview == false {
            for (cardView, card) in zip(cardViews, content.cards) where card.isTurnedOff {
                cardView.onClick = { [weak self] in
                    self?.openSensorsSettings()
                }
                cardView.toolTip = FloatingWindowViewController.openSensorsTitle
            }
        }
        
        // The cards are hidden from VoiceOver, so the glass offers the same route as an action.
        let hasTurnedOffCard: Bool = isPreview == false && content.cards.contains(where: { $0.isTurnedOff })
        glassView.setAccessibilityCustomActions(hasTurnedOffCard ? [makeOpenSensorsAccessibilityAction()] : [])
        
        // The first build is not announced, so VoiceOver only hears later layout changes.
        let hadContent: Bool = lastContent != nil
        
        // The empty message has nothing to glide, so it appears at once.
        if animated, oldCards.isEmpty == false, cardViews.isEmpty == false {
            animateRelayout(from: oldCards, isHorizontal: isHorizontal)
        }
        else {
            if cardViews.isEmpty {
                cardsContainerView.addSubview(emptyLabel)
                emptyLabel.autoPinEdgesToSuperviewEdges()
            }
            
            layoutCards(isHorizontal: isHorizontal)
            view.layoutSubtreeIfNeeded()
            sizeDidChange?(preferredSize)
        }
        
        if hadContent {
            NSAccessibility.post(element: glassView, notification: .layoutChanged)
        }
    }
    
    /// Chains the cards along the layout's direction, and stretches each across the window's short side so the cells line up however many rows each one has.
    private func layoutCards(isHorizontal: Bool) {
        let leadingEdge: ALEdge = isHorizontal ? .leading : .top
        let trailingEdge: ALEdge = isHorizontal ? .trailing : .bottom
        let crossEdges: [ALEdge] = isHorizontal ? [.top, .bottom] : [.leading, .trailing]
        var previousCardView: FloatingWindowCardView?
        
        for cardView in cardViews {
            cardsContainerView.addSubview(cardView)
            
            if let previousCardView: FloatingWindowCardView = previousCardView {
                cardView.autoPinEdge(leadingEdge, to: trailingEdge, of: previousCardView, withOffset: FloatingWindowViewController.cardSpacing)
            }
            else {
                cardView.autoPinEdge(toSuperviewEdge: leadingEdge)
            }
            
            for edge in crossEdges {
                cardView.autoPinEdge(toSuperviewEdge: edge)
            }
            
            previousCardView = cardView
        }
        
        previousCardView?.autoPinEdge(toSuperviewEdge: trailingEdge)
    }
    
    // MARK: - Relayout Animation
    /// A card as it was before a rebuild, with its frame in the overlay.
    private struct OldCard {
        let kind: FloatingWindowLayout.CardKind
        let view: FloatingWindowCardView
        let frame: CGRect
    }
    
    /// Where each card lands once the window reaches its new size, matching `layoutCards(isHorizontal:)`, and the size of all the cards together.
    private func finalCardFrames(isHorizontal: Bool) -> (frames: [CGRect], cardsSize: CGSize) {
        let origin: CGFloat = FloatingWindowViewController.glassInset + FloatingWindowViewController.contentInset
        let spacing: CGFloat = FloatingWindowViewController.cardSpacing
        let sizes: [CGSize] = cardViews.map({ $0.fittingSize })
        let spacingTotal: CGFloat = spacing * CGFloat(max(sizes.count - 1, 0))
        let cardsSize: CGSize
        
        if isHorizontal {
            cardsSize = CGSize(width: sizes.map({ $0.width }).reduce(0.0, +) + spacingTotal, height: sizes.map({ $0.height }).max() ?? 0.0)
        }
        else {
            cardsSize = CGSize(width: sizes.map({ $0.width }).max() ?? 0.0, height: sizes.map({ $0.height }).reduce(0.0, +) + spacingTotal)
        }
        
        // The overlay measures from the left, while the layout chains cards from the leading edge, so a right-to-left layout counts from the right.
        let isRightToLeft: Bool = view.userInterfaceLayoutDirection == .rightToLeft
        var position: CGFloat = 0.0
        var frames: [CGRect] = []
        
        for size in sizes {
            if isHorizontal {
                let x: CGFloat = isRightToLeft ? origin + cardsSize.width - position - size.width : origin + position
                frames.append(CGRect(x: x, y: origin, width: size.width, height: cardsSize.height))
                position = position + size.width + spacing
            }
            else {
                frames.append(CGRect(x: origin, y: origin + position, width: cardsSize.width, height: size.height))
                position = position + size.height + spacing
            }
        }
        
        return (frames: frames, cardsSize: cardsSize)
    }
    
    /// Glides the new cards from where the same cards were to their new places while the glass resizes, then hands them back to the layout.
    /// - Note: Animating a window's frame stretches a snapshot of it, so the window instead grows at once to cover both its old and new frames, which shows nothing since it is clear past the glass. The glass and cards animate inside it, and the window trims to its new frame at the end.
    /// - Note: A card that was not there fades in, and one that is gone fades out. A card that grew past its old frame, such as one with a new row, fades from its old look so it never squeezes into a frame too small for it.
    private func animateRelayout(from oldCards: [OldCard], isHorizontal: Bool) {
        let finalLayout: (frames: [CGRect], cardsSize: CGSize) = finalCardFrames(isHorizontal: isHorizontal)
        let finalSize: CGSize = FloatingWindowViewController.windowSize(forCardsSize: finalLayout.cardsSize)
        
        guard let window: NSWindow = view.window else {
            for cardView in cardViews {
                cardsContainerView.addSubview(cardView)
            }
            
            layoutCards(isHorizontal: isHorizontal)
            sizeDidChange?(finalSize)
            return
        }
        
        let generation: Int = relayoutGeneration
        let oldWindowFrame: CGRect = window.frame
        let finalWindowFrame: CGRect = FloatingWindowController.resizedFrame(oldWindowFrame, to: finalSize, in: (window.screen ?? NSScreen.main)?.visibleFrame)
        let unionFrame: CGRect = oldWindowFrame.union(finalWindowFrame)
        // Overlay frames are measured from the window's top left corner, which moves when the window grows left or up.
        let oldOffset: CGPoint = CGPoint(x: oldWindowFrame.minX - unionFrame.minX, y: unionFrame.maxY - oldWindowFrame.maxY)
        let finalOffset: CGPoint = CGPoint(x: finalWindowFrame.minX - unionFrame.minX, y: unionFrame.maxY - finalWindowFrame.maxY)
        let finalFrames: [CGRect] = finalLayout.frames.map({ $0.offsetBy(dx: finalOffset.x, dy: finalOffset.y) })
        var fadingOutViews: [(view: NSView, startFrame: CGRect, endFrame: CGRect)] = []
        
        for (index, cardView) in cardViews.enumerated() {
            let finalFrame: CGRect = finalFrames[index]
            cardView.translatesAutoresizingMaskIntoConstraints = true
            relayoutOverlayView.addSubview(cardView)
            
            if let oldCard: OldCard = oldCards.first(where: { $0.kind == cardKinds[index] }) {
                let oldFrame: CGRect = oldCard.frame.offsetBy(dx: oldOffset.x, dy: oldOffset.y)
                let fittingSize: CGSize = cardView.fittingSize
                
                if fittingSize.width <= oldFrame.width + 0.5, fittingSize.height <= oldFrame.height + 0.5 {
                    cardView.frame = oldFrame
                }
                else {
                    cardView.frame = finalFrame
                    cardView.alphaValue = 0.0
                    fadingOutViews.append((view: oldCard.view, startFrame: oldFrame, endFrame: finalFrame))
                }
            }
            else {
                cardView.frame = finalFrame
                cardView.alphaValue = 0.0
            }
        }
        
        for oldCard in oldCards where cardKinds.contains(oldCard.kind) == false {
            let oldFrame: CGRect = oldCard.frame.offsetBy(dx: oldOffset.x, dy: oldOffset.y)
            fadingOutViews.append((view: oldCard.view, startFrame: oldFrame, endFrame: oldFrame))
        }
        
        // Fading views sit under the new cards, so a card fading in covers the old look it replaces.
        for fadingOutView in fadingOutViews {
            fadingOutView.view.translatesAutoresizingMaskIntoConstraints = true
            relayoutOverlayView.addSubview(fadingOutView.view, positioned: .below, relativeTo: nil)
            fadingOutView.view.frame = fadingOutView.startFrame
        }
        
        // The glass leaves its constraints for the glide, keeping its place on screen while the window grows around it.
        let inset: CGFloat = FloatingWindowViewController.glassInset
        let oldGlassFrame: CGRect = CGRect(x: oldWindowFrame.minX - unionFrame.minX, y: oldWindowFrame.minY - unionFrame.minY, width: oldWindowFrame.width, height: oldWindowFrame.height).insetBy(dx: inset, dy: inset)
        let finalGlassFrame: CGRect = CGRect(x: finalWindowFrame.minX - unionFrame.minX, y: finalWindowFrame.minY - unionFrame.minY, width: finalWindowFrame.width, height: finalWindowFrame.height).insetBy(dx: inset, dy: inset)
        (glassConstraints as NSArray).autoRemoveConstraints()
        glassView.translatesAutoresizingMaskIntoConstraints = true
        closeHitView.isHidden = true
        // A drag during the glide would be undone when the window trims to the frame worked out here.
        window.isMovable = false
        pendingRelayout = (window: window, frame: finalWindowFrame, isHorizontal: isHorizontal)
        
        NSAnimationContext.runAnimationGroup { context in
            context.allowsImplicitAnimation = false
            window.setFrame(unionFrame, display: false)
            glassView.frame = oldGlassFrame
            view.layoutSubtreeIfNeeded()
        }
        
        startShadowUpdates()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = FloatingWindowViewController.relayoutAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            glassView.animator().frame = finalGlassFrame
            
            for (cardView, frame) in zip(cardViews, finalFrames) {
                cardView.animator().frame = frame
                cardView.animator().alphaValue = 1.0
            }
            
            for fadingOutView in fadingOutViews {
                fadingOutView.view.animator().frame = fadingOutView.endFrame
                fadingOutView.view.animator().alphaValue = 0.0
            }
        } completionHandler: { [weak self] in
            guard let strongSelf: FloatingWindowViewController = self else { return }
            
            for fadingOutView in fadingOutViews {
                fadingOutView.view.removeFromSuperview()
            }
            
            // A later rebuild already took over the cards and the glass.
            guard strongSelf.relayoutGeneration == generation else { return }
            
            strongSelf.finishRelayout(in: window, frame: finalWindowFrame, isHorizontal: isHorizontal)
        }
    }
    
    /// Trims the window to its new frame and puts the glass and cards back under the layout.
    private func finishRelayout(in window: NSWindow, frame: CGRect, isHorizontal: Bool) {
        pendingRelayout = nil
        stopShadowUpdates()
        
        for fadingView in relayoutOverlayView.subviews where cardViews.contains(where: { $0 === fadingView }) == false {
            fadingView.removeFromSuperview()
        }
        
        glassView.translatesAutoresizingMaskIntoConstraints = false
        (glassConstraints as NSArray).autoInstallConstraints()
        
        for cardView in cardViews {
            cardView.removeFromSuperview()
            cardView.translatesAutoresizingMaskIntoConstraints = false
        }
        
        layoutCards(isHorizontal: isHorizontal)
        window.setFrame(frame, display: true)
        view.layoutSubtreeIfNeeded()
        window.invalidateShadow()
        window.isMovable = true
        closeHitView.isHidden = isPreview
    }
    
    private func startShadowUpdates() {
        stopShadowUpdates()
        let displayLink: CADisplayLink = view.displayLink(target: self, selector: #selector(shadowDisplayLinkFired))
        displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
        shadowDisplayLink = displayLink
    }
    
    private func stopShadowUpdates() {
        shadowDisplayLink?.invalidate()
        shadowDisplayLink = nil
    }
    
    @objc private func shadowDisplayLinkFired() {
        view.window?.invalidateShadow()
    }
    
    // MARK: - Layout Comparison
    /// The same cards with the same rows in the same order, so only values differ.
    static func hasSameLayout(_ content: FloatingWindowContent, _ otherContent: FloatingWindowContent) -> Bool {
        return content.orientation == otherContent.orientation && hasSameCards(content, otherContent)
    }
    
    /// The same cards with the same titles and rows in the same order, in either orientation.
    /// - Note: Updating in place only changes values, so a renamed fan rebuilds its card.
    static func hasSameCards(_ content: FloatingWindowContent, _ otherContent: FloatingWindowContent) -> Bool {
        guard content.cards.count == otherContent.cards.count else { return false }
        
        return zip(content.cards, otherContent.cards).allSatisfy({ card, otherCard in
            return card.kind == otherCard.kind && card.title == otherCard.title && card.isTurnedOff == otherCard.isTurnedOff && card.rows.map({ $0.stat }) == otherCard.rows.map({ $0.stat })
        })
    }
    
    // MARK: - Mouse
    override func rightMouseDown(with event: NSEvent) {
        guard
            isPreview == false,
            let contextMenu: NSMenu = contextMenuProvider?()
        else {
            super.rightMouseDown(with: event)
            return
        }
        
        NSMenu.popUpContextMenu(contextMenu, with: event, for: view)
    }
    
    override func mouseEntered(with event: NSEvent) {
        setHovering(true)
    }
    
    override func mouseExited(with event: NSEvent) {
        setHovering(false)
    }
    
    private func setHovering(_ isHovering: Bool) {
        guard self.isHovering != isHovering else { return }
        self.isHovering = isHovering
        
        let alphaValue: CGFloat = isHovering ? 1.0 : 0.0
        
        // Reduce Motion turns every animation off, so the badge just appears and disappears.
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            closeHitView.alphaValue = alphaValue
        }
        else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = FloatingWindowViewController.hoverAnimationDuration
                self.closeHitView.animator().alphaValue = alphaValue
            }
        }
    }
    
    // MARK: - Actions
    @objc private func closeButtonPressed() {
        guard isPreview == false else { return }
        trackAction("floatingWindowPanel_Close")
        FannySettingsManager.shared.update({ $0.showsFloatingWindow = false })
    }
    
    private func openSensorsSettings() {
        trackAction("floatingWindowPanel_OpenSensors")
        SettingsWindowController.shared.show(pane: .sensors)
    }
    
    private func makeOpenSensorsAccessibilityAction() -> NSAccessibilityCustomAction {
        return NSAccessibilityCustomAction(name: FloatingWindowViewController.openSensorsTitle) { [weak self] in
            self?.openSensorsSettings()
            return true
        }
    }
    
    private static var openSensorsTitle: String {
        return String(localized: "Open Sensors Settings", comment: "Floating window: tooltip and VoiceOver action on a turned off CPU or GPU card. Opens the Sensors pane in Settings.")
    }
    
    // MARK: - Analytics
    private func trackAction(_ title: String) {
        let event: PageViewEvent = PageViewEvent(title: title)
        Analytics.shared.track(event: event)
    }
}

// MARK: - HoverGrowButton
/// A borderless button that grows a little while the pointer is over it, unless Reduce Motion is on.
private final class HoverGrowButton: NSButton {
    
    /// The view that grows. Defaults to the button, and is the badge for the close button so its glass grows too.
    weak var growingView: NSView?
    var isHoverEnabled: Bool = true
    
    private var trackingArea: NSTrackingArea?
    
    private static let hoverScale: CGFloat = 1.2
    private static let animationDuration: TimeInterval = 0.12
    
    /// How far the pointer moves while pressed before the press becomes a window drag instead of a click.
    private static let dragThreshold: CGFloat = 3.0
    
    // MARK: - Tracking
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea: NSTrackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let area: NSTrackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }
    
    // No super call: it passes the event up the responder chain, and the window's own exit would hide the close badge while the pointer is still over the window.
    override func mouseEntered(with event: NSEvent) {
        guard isHoverEnabled else { return }
        setGrown(true)
    }
    
    override func mouseExited(with event: NSEvent) {
        setGrown(false)
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        guard newWindow == nil else { return }
        setGrown(false)
    }
    
    // MARK: - Mouse
    /// A press that moves drags the window, so the whole window can be grabbed. A press that stays put clicks as usual.
    override func mouseDown(with event: NSEvent) {
        guard let window: NSWindow = window else {
            super.mouseDown(with: event)
            return
        }
        
        let startLocation: CGPoint = event.locationInWindow
        var isTracking: Bool = true
        isHighlighted = true
        
        while isTracking, let nextEvent: NSEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let location: CGPoint = nextEvent.locationInWindow
            
            if nextEvent.type == .leftMouseUp {
                isHighlighted = false
                isTracking = false
                
                if bounds.contains(convert(location, from: nil)) {
                    sendAction(action, to: target)
                }
            }
            else if hypot(location.x - startLocation.x, location.y - startLocation.y) >= HoverGrowButton.dragThreshold {
                isHighlighted = false
                isTracking = false
                window.performDrag(with: event)
            }
        }
    }
    
    // MARK: - Scale
    private func setGrown(_ isGrown: Bool) {
        // Reduce Motion turns the growth off entirely. A button left grown when the setting changed still shrinks back.
        guard isGrown == false || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion == false else { return }
        
        let targetView: NSView = growingView ?? self
        targetView.wantsLayer = true
        
        let size: CGSize = targetView.bounds.size
        let scale: CGFloat = isGrown ? HoverGrowButton.hoverScale : 1.0
        
        // A view's layer scales from its corner, so the transform shifts it to scale around its center.
        var transform: CATransform3D = CATransform3DMakeTranslation(size.width / 2.0, size.height / 2.0, 0.0)
        transform = CATransform3DScale(transform, scale, scale, 1.0)
        transform = CATransform3DTranslate(transform, -size.width / 2.0, -size.height / 2.0, 0.0)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = HoverGrowButton.animationDuration
            context.allowsImplicitAnimation = true
            targetView.layer?.transform = transform
        }
    }
}

// MARK: - FlippedView
/// A view measured from its top left corner, so frames inside it stay put while the window grows or shrinks below them.
private final class FlippedView: NSView {
    
    override var isFlipped: Bool {
        return true
    }
}
