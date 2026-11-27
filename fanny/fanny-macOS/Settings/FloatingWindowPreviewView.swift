//
//  FloatingWindowPreviewView.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import ImageIO
import PureLayout

/// Shows the live floating window over the desktop picture, so theme and tint changes can be seen as they happen.
/// - Note: The preview ignores the pointer, and VoiceOver reads it as one image.
final class FloatingWindowPreviewView: NSView {
    
    private let backgroundView: NSView = NSView()
    private let windowViewController: FloatingWindowViewController = FloatingWindowViewController(isPreview: true)
    
    private var loadedDesktopImageURL: URL?
    private var heightConstraint: NSLayoutConstraint?
    private var windowSizeConstraints: [NSLayoutConstraint] = []
    
    private static let minimumHeight: CGFloat = 120.0
    private static let verticalPadding: CGFloat = 24.0
    /// Large enough to stay sharp across the Settings window, small enough to decode quickly.
    private static let maximumDesktopImagePixelSize: Int = 1600
    /// This macOS version's default wallpaper, for desktops the app cannot read, such as an Aerial or a photo in a protected folder.
    private static let defaultDesktopImageURL: URL = URL(fileURLWithPath: "/System/Library/CoreServices/DefaultDesktop.heic")
    
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
        layer?.masksToBounds = true
        heightConstraint = autoSetDimension(.height, toSize: FloatingWindowPreviewView.minimumHeight)
        
        setupBackgroundView()
        setupWindowView()
        setupAccessibility()
        
        SensorMonitor.shared.delegate.add(self)
        FannySettingsManager.shared.delegate.add(self)
    }
    
    private func setupBackgroundView() {
        backgroundView.wantsLayer = true
        backgroundView.layer?.contentsGravity = .resizeAspectFill
        backgroundView.layer?.masksToBounds = true
        
        addSubview(backgroundView)
        backgroundView.autoPinEdgesToSuperviewEdges()
    }
    
    private func setupWindowView() {
        let windowView: NSView = windowViewController.view
        addSubview(windowView)
        windowView.autoCenterInSuperview()
        windowViewController.sizeDidChange = { [weak self] size in
            self?.updateWindowSize(size)
        }
        updateWindowSize(windowViewController.preferredSize)
    }
    
    /// The preview grows with the window, so a vertical layout still fits.
    private func updateWindowSize(_ size: CGSize) {
        NSLayoutConstraint.deactivate(windowSizeConstraints)
        windowSizeConstraints = windowViewController.view.autoSetDimensions(to: size)
        heightConstraint?.constant = max(FloatingWindowPreviewView.minimumHeight, size.height + FloatingWindowPreviewView.verticalPadding)
    }
    
    private func setupAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel(String(localized: "Floating window preview", comment: "Settings, Appearance: accessibility label of the live preview of the floating window."))
    }
    
    // MARK: - Window
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeScreenNotification, object: nil)
        guard let window: NSWindow = window else { return }
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidChangeScreen), name: NSWindow.didChangeScreenNotification, object: window)
        windowViewController.update()
        loadDesktopImage()
    }
    
    // MARK: - Desktop Picture
    /// Decodes the desktop picture of the window's screen off the main thread, falling back to the default wallpaper.
    /// - Note: For an Aerial, the system reports the default wallpaper's still as the desktop picture.
    private func loadDesktopImage() {
        guard
            let screen: NSScreen = window?.screen ?? NSScreen.main,
            let url: URL = NSWorkspace.shared.desktopImageURL(for: screen),
            url != loadedDesktopImageURL
        else { return }
        
        loadedDesktopImageURL = url
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image: CGImage? = FloatingWindowPreviewView.downsampledImage(at: url) ?? FloatingWindowPreviewView.downsampledImage(at: FloatingWindowPreviewView.defaultDesktopImageURL)
            
            DispatchQueue.main.async {
                guard let strongSelf: FloatingWindowPreviewView = self, strongSelf.loadedDesktopImageURL == url else { return }
                
                if image == nil {
                    Log.warn("🎨 loadDesktopImage -> unreadable, url: \(url.lastPathComponent)")
                    // Cleared, so the next time the preview appears it tries again.
                    strongSelf.loadedDesktopImageURL = nil
                }
                
                strongSelf.backgroundView.layer?.contents = image
            }
        }
    }
    
    private static func downsampledImage(at url: URL) -> CGImage? {
        guard let source: CGImageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: FloatingWindowPreviewView.maximumDesktopImagePixelSize]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
    
    // MARK: - Actions
    @objc private func windowDidChangeScreen() {
        loadDesktopImage()
    }
    
    // MARK: - Mouse
    /// The preview takes every click itself, so nothing inside it can drag the Settings window.
    override func hitTest(_ point: NSPoint) -> NSView? {
        // The point is in the superview's coordinates, like the frame.
        return frame.contains(point) ? self : nil
    }
    
    override func mouseDown(with event: NSEvent) {}
    
    // MARK: - Accessibility
    override func accessibilityChildren() -> [Any]? {
        return nil
    }
}

// MARK: - SensorMonitorDelegate
extension FloatingWindowPreviewView: SensorMonitorDelegate {
    
    func sensorMonitor(_ monitor: SensorMonitor, didUpdateSnapshot snapshot: ReadingsSnapshot) {
        guard window?.isVisible == true else { return }
        windowViewController.update()
    }
}

// MARK: - FannySettingsManagerDelegate
extension FloatingWindowPreviewView: FannySettingsManagerDelegate {
    
    func fannySettingsManager(_ manager: FannySettingsManager, didUpdateSettings settings: FannySettings) {
        windowViewController.update()
    }
}
