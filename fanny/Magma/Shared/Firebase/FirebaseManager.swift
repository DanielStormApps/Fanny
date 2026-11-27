//
//  FirebaseManager.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

/// A shared instance class that configures Firebase and sets the user values attached to every crash and analytics report.
final class FirebaseManager {
    
    /// Whether Firebase was configured this launch, so its logger and reporter only call it once it is ready.
    private(set) var isConfigured: Bool = false
    
    /// Whether the user lets Fanny send crash reports, which also covers Firebase's own analytics. On until they turn it off in Privacy Settings.
    private(set) var isCrashReportsEnabled: Bool = Storage.bool(forKey: .crashReportsDisabled) == false
    
    private var isEnabled: Bool {
        return ConfigManager.shared.config.analytics?.services?.firebase?.enabled == true
    }
    
    private var hasGoogleServiceInfo: Bool {
        return Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }
    
    // MARK: - Init
    private init() {}
    static let shared: FirebaseManager = FirebaseManager()
    
    // MARK: - Configure
    func configure() {
        guard isEnabled else { return }
        
        // `FirebaseApp.configure()` stops the app when `GoogleService-Info.plist` is missing, which it is in a build without the private analytics files.
        guard hasGoogleServiceInfo else {
            Log.warn("📈 configure -> missing GoogleService-Info.plist, Firebase is off")
            return
        }
        
        // macOS apps catch uncaught exceptions and keep running by default, so Crashlytics would never report them.
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        FirebaseApp.configure()
        isConfigured = true
        // Firebase also collects on its own, such as sessions, so the user's choice has to reach it, not only our events.
        applyCollectionSettings()
        handleUnsentReports()
        
        // ID
        let clientUUID: String = UserManager.shared.currentUser.clientUUID
        Crashlytics.crashlytics().setUserID(clientUUID)
        Crashlytics.crashlytics().setCustomValue(clientUUID, forKey: AnalyticsParameter.clientUUID)
        FirebaseAnalytics.Analytics.setUserID(clientUUID)
        FirebaseAnalytics.Analytics.setUserProperty(clientUUID, forName: AnalyticsParameter.clientUUID)
        
        // Feature usage
        let usesWidgetExtension: String = UserManager.shared.currentUser.usesWidgetExtension.stringValue
        Crashlytics.crashlytics().setCustomValue(usesWidgetExtension, forKey: AnalyticsParameter.usesWidgetExtension)
        FirebaseAnalytics.Analytics.setUserProperty(usesWidgetExtension, forName: AnalyticsParameter.usesWidgetExtension)
    }
    
    // MARK: - Collection
    /// Firebase's analytics needs both switches on, and crash reports only the Crash Reports switch. Crashlytics saves the choice but only applies it from the next launch.
    func applyCollectionSettings() {
        guard isConfigured else { return }
        FirebaseAnalytics.Analytics.setAnalyticsCollectionEnabled(Analytics.shared.isEnabled && isCrashReportsEnabled)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(isCrashReportsEnabled)
    }
    
    /// Reports the change while crash reports are still on, before turning them off and after turning them back on, so both changes are counted.
    /// - Note: `event` only goes out while Analytics is on, but the non-fatal is recorded either way.
    func setCrashReportsEnabled(_ isEnabled: Bool, event: AnalyticsEvent) {
        guard isEnabled != isCrashReportsEnabled else { return }
        
        if isEnabled == false {
            recordNonFatalError(.crashReportsTurnedOff)
            Analytics.shared.track(event: event)
        }
        
        isCrashReportsEnabled = isEnabled
        Storage.save(isEnabled == false, forKey: .crashReportsDisabled)
        // Crashlytics keeps collecting until Fanny restarts, then holds back what it saved, including the off non-fatal. This flag lets that next launch send them once.
        Storage.save(isEnabled == false, forKey: .crashReportsOffReportPending)
        applyCollectionSettings()
        
        Log.info("🔒 setCrashReportsEnabled -> isEnabled: \(isEnabled)")
        
        if isEnabled {
            recordNonFatalError(.crashReportsTurnedOn)
            Analytics.shared.track(event: event)
        }
    }
    
    /// With collection off, Crashlytics keeps reports on this Mac. The first launch after turning it off sends what the last session saved, which matches the switch taking effect on restart. Later launches delete them, so nothing collected while off is sent if it is turned back on.
    private func handleUnsentReports() {
        guard isCrashReportsEnabled == false else { return }
        
        let sendsReports: Bool = Storage.bool(forKey: .crashReportsOffReportPending)
        Storage.save(false, forKey: .crashReportsOffReportPending)
        
        Crashlytics.crashlytics().checkForUnsentReports { hasUnsentReports in
            guard hasUnsentReports else { return }
            
            if sendsReports {
                Crashlytics.crashlytics().sendUnsentReports()
            }
            else {
                Crashlytics.crashlytics().deleteUnsentReports()
            }
        }
    }
    
    // MARK: - Non-Fatal
    private func recordNonFatalError(_ nonFatalError: NonFatalError) {
        guard
            isConfigured,
            isCrashReportsEnabled
        else { return }
        
        Log.info("🔒 recordNonFatalError -> nonFatalError: \(nonFatalError)")
        Crashlytics.crashlytics().record(error: nonFatalError.nsError)
    }
}

// MARK: - NonFatalError
/// Changes worth seeing in Crashlytics that are not crashes.
private enum NonFatalError {
    case crashReportsTurnedOff
    case crashReportsTurnedOn
    
    var nsError: NSError {
        let error: NSError
        
        switch self {
        case .crashReportsTurnedOff:
            error = NSError(domain: "crashReportsTurnedOff", code: 100)
        case .crashReportsTurnedOn:
            error = NSError(domain: "crashReportsTurnedOn", code: 101)
        }
        
        return error
    }
}
