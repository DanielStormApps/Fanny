//
//  AppDelegate.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

/// The application delegate that sets up the app and broadcasts its life cycle events.
@main
final class AppDelegate: NSObject, NSApplicationDelegate, Application {
    
    var delegate: DelegateMulticast<ApplicationDelegate> = DelegateMulticast<ApplicationDelegate>()
    
    // Held strongly because `NSApplication` only keeps a weak reference to its delegate.
    private static let shared: AppDelegate = AppDelegate()
    
    // MARK: - Init
    // No storyboard or nib connects the delegate, so the entry point has to set it.
    static func main() {
        let application: NSApplication = NSApplication.shared
        application.delegate = shared
        application.run()
    }
    
    // MARK: - NSApplicationDelegate
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        delegate.add(ApplicationLifeCycle.shared)
        setupLoggers()
        setupFirebase()
        
        // Tests host the app, so they must never start the app's services or register a login item.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        
        AppBootstrap.shared.runIfNeeded()
        
        delegate.invoke({ $0.applicationDidFinishLaunching() })
    }
    
    func applicationWillBecomeActive(_ aNotification: Notification) {
        delegate.invoke({ $0.applicationWillBecomeActive() })
    }
    
    func applicationDidBecomeActive(_ aNotification: Notification) {
        delegate.invoke({ $0.applicationDidBecomeActive() })
    }
    
    func applicationWillResignActive(_ aNotification: Notification) {
        delegate.invoke({ $0.applicationWillResignActive() })
    }
    
    func applicationDidResignActive(_ aNotification: Notification) {
        delegate.invoke({ $0.applicationDidResignActive() })
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        delegate.invoke({ $0.applicationWillTerminate() })
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppBootstrap.shared.runIfNeeded()
        SettingsWindowController.shared.show()
        return false
    }
    
    // MARK: - Setup
    /// The console and file loggers come first, so a Firebase setup warning is not lost.
    private func setupLoggers() {
        let consoleLogger: ConsoleLogger = ConsoleLogger()
        LogManager.shared.add(logger: consoleLogger)
        
        LogManager.shared.add(logger: FileLogger.shared)
    }
    
    private func setupFirebase() {
        // Tests host the app, so they must never send crash or analytics data.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        FirebaseManager.shared.configure()
        
        guard FirebaseManager.shared.isConfigured else { return }
        
        let crashlyticsLogger: CrashlyticsLogger = CrashlyticsLogger()
        LogManager.shared.add(logger: crashlyticsLogger)
    }
}
