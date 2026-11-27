//
//  FloatingWindowController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

/// A controller that owns the floating window panel and keeps it in sync with the settings and readings.
final class FloatingWindowController: NSObject {
    
    /// Builds the right-click menu, which shows the menu bar menu's actions.
    var contextMenuProvider: (() -> NSMenu?)?
    
    private var panel: FloatingWindowPanel?
    private var viewController: FloatingWindowViewController?
    
    private static let frameAutosaveName: String = "FloatingWindowPanel"
    private static let defaultScreenInset: CGFloat = 16.0
    private static let minimumVisibleWidth: CGFloat = 40.0
    private static let minimumVisibleHeight: CGFloat = 20.0
    
    // MARK: - Setup
    func setup() {
        let viewController: FloatingWindowViewController = FloatingWindowViewController()
        viewController.contextMenuProvider = { [weak self] in
            return self?.contextMenuProvider?()
        }
        viewController.sizeDidChange = { [weak self] size in
            self?.resizePanel(to: size)
        }
        
        let panel: FloatingWindowPanel = FloatingWindowPanel(contentSize: viewController.preferredSize)
        panel.contentViewController = viewController
        panel.setContentSize(viewController.preferredSize)
        AppThemeManager.shared.register(panel)
        
        self.viewController = viewController
        self.panel = panel
        
        SensorMonitor.shared.delegate.add(self)
        FannySettingsManager.shared.delegate.add(self)
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersDidChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        
        applyVisibility()
    }
    
    // MARK: - Visibility
    private func applyVisibility() {
        if FannySettingsManager.shared.settings.showsFloatingWindow {
            show()
        }
        else {
            hide()
        }
    }
    
    /// Orders the panel front without activating the app, so it never takes focus.
    private func show() {
        guard let panel: FloatingWindowPanel = panel, panel.isVisible == false else { return }
        
        // Read before the autosave name is set, since setting it and the first resize both save a frame right away.
        let hasSavedFrame: Bool = UserDefaults.standard.string(forKey: "NSWindow Frame \(FloatingWindowController.frameAutosaveName)") != nil
        
        if panel.frameAutosaveName.isEmpty {
            panel.setFrameAutosaveName(FloatingWindowController.frameAutosaveName)
        }
        
        viewController?.update()
        ensureOnScreen(hasSavedFrame: hasSavedFrame)
        panel.orderFrontRegardless()
        Log.info("🎛️ FloatingWindow show -> frame: \(NSStringFromRect(panel.frame))")
    }
    
    private func hide() {
        guard let panel: FloatingWindowPanel = panel, panel.isVisible else { return }
        panel.orderOut(nil)
        Log.info("🎛️ FloatingWindow hide")
    }
    
    // MARK: - Size
    private func resizePanel(to size: CGSize) {
        guard let panel: FloatingWindowPanel = panel, panel.frame.size != size else { return }
        
        let visibleFrame: CGRect? = (panel.screen ?? NSScreen.main)?.visibleFrame
        let frame: CGRect = FloatingWindowController.resizedFrame(panel.frame, to: size, in: visibleFrame)
        panel.setFrame(frame, display: true)
    }
    
    /// Keeps the top edge and the side nearer the screen's edge in place, so the window grows away from that edge and stays on screen.
    static func resizedFrame(_ frame: CGRect, to size: CGSize, in visibleFrame: CGRect?) -> CGRect {
        let isNearTrailingEdge: Bool = visibleFrame.map({ frame.midX > $0.midX }) ?? false
        var resizedFrame: CGRect = CGRect(x: isNearTrailingEdge ? frame.maxX - size.width : frame.minX, y: frame.maxY - size.height, width: size.width, height: size.height)
        
        if let visibleFrame: CGRect = visibleFrame {
            resizedFrame.origin.x = min(max(resizedFrame.minX, visibleFrame.minX), max(visibleFrame.maxX - size.width, visibleFrame.minX))
            resizedFrame.origin.y = min(max(resizedFrame.minY, visibleFrame.minY), max(visibleFrame.maxY - size.height, visibleFrame.minY))
        }
        
        return resizedFrame
    }
    
    // MARK: - Position
    /// Moves the panel back on screen when a saved position no longer lies on any display, or places it at the bottom right the first time.
    private func ensureOnScreen(hasSavedFrame: Bool) {
        guard let panel: FloatingWindowPanel = panel else { return }
        
        let screenFrames: [CGRect] = NSScreen.screens.map({ $0.frame })
        
        guard
            hasSavedFrame == false || FloatingWindowController.isOnScreen(panel.frame, screenFrames: screenFrames) == false,
            let screen: NSScreen = NSScreen.main ?? NSScreen.screens.first
        else { return }
        
        let origin: CGPoint = FloatingWindowController.defaultOrigin(size: panel.frame.size, in: screen.visibleFrame)
        panel.setFrameOrigin(origin)
        Log.info("🎛️ FloatingWindow ensureOnScreen -> origin: \(NSStringFromPoint(origin))")
    }
    
    /// True when enough of the frame lies on a display to grab it, not just a sliver.
    private static func isOnScreen(_ frame: CGRect, screenFrames: [CGRect]) -> Bool {
        return screenFrames.contains(where: { screenFrame in
            let overlap: CGRect = screenFrame.intersection(frame)
            return overlap.isNull == false && overlap.width >= minimumVisibleWidth && overlap.height >= minimumVisibleHeight
        })
    }
    
    /// The bottom right corner of the visible area, just inside its edges.
    private static func defaultOrigin(size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        return CGPoint(x: visibleFrame.maxX - size.width - defaultScreenInset, y: visibleFrame.minY + defaultScreenInset)
    }
    
    // MARK: - Notifications
    @objc private func screenParametersDidChange() {
        guard FannySettingsManager.shared.settings.showsFloatingWindow else { return }
        ensureOnScreen(hasSavedFrame: true)
    }
}

// MARK: - SensorMonitorDelegate
extension FloatingWindowController: SensorMonitorDelegate {
    
    func sensorMonitor(_ monitor: SensorMonitor, didUpdateSnapshot snapshot: ReadingsSnapshot) {
        guard panel?.isVisible == true else { return }
        viewController?.update()
    }
}

// MARK: - FannySettingsManagerDelegate
extension FloatingWindowController: FannySettingsManagerDelegate {
    
    func fannySettingsManager(_ manager: FannySettingsManager, didUpdateSettings settings: FannySettings) {
        applyVisibility()
        guard panel?.isVisible == true else { return }
        viewController?.update()
    }
}
