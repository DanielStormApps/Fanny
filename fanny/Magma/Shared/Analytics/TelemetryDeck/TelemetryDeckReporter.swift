//
//  TelemetryDeckReporter.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation
import TelemetryDeck

/// A reporter that sends analytics signals to TelemetryDeck.
final class TelemetryDeckReporter {
    
    private var trackingID: String = String()
    private var clientUUID: String = String()
    /// The SDK keeps this same instance, so changing it later reaches the running SDK.
    private var configuration: TelemetryManagerConfiguration?
    
    // MARK: - Init
    convenience init(trackingID: String, clientUUID: String, isEnabled: Bool) {
        self.init()
        self.trackingID = trackingID
        self.clientUUID = clientUUID
        
        guard trackingID.matches(regex: TelemetryDeckReporter.Regex.trackerID) else {
            assertionFailure("`trackingID` contains an invalid TelemetryDeck tracker ID")
            return
        }
        
        let telemetryManagerConfiguration: TelemetryManagerConfiguration = TelemetryManagerConfiguration(appID: trackingID)
        telemetryManagerConfiguration.logHandler = nil
        telemetryManagerConfiguration.defaultUser = clientUUID
        // Starts the SDK even when analytics is off, so turning it back on needs no restart. Off, it sends no new signals, including its own session signals.
        telemetryManagerConfiguration.analyticsDisabled = isEnabled == false
        
        #if DEBUG
            telemetryManagerConfiguration.testMode = true
        #endif
        
        TelemetryDeck.initialize(config: telemetryManagerConfiguration)
        configuration = telemetryManagerConfiguration
    }
    
    /// Signals already queued still go out, so the event sent just before turning analytics off is not lost.
    func setEnabled(_ isEnabled: Bool) {
        configuration?.analyticsDisabled = isEnabled == false
    }
    
    // MARK: - Content View
    func contentView(name: String) {
        let parameters: [String: String] = [AnalyticsParameter.hitType: AnalyticsHitType.contentView,
                                            AnalyticsParameter.contentName: name]
        
        reportSignal(name: name, parameters: parameters)
    }
    
    // MARK: - Event
    func event(name: String, action: String, description: String) {
        let parameters: [String: String] = [AnalyticsParameter.hitType: AnalyticsHitType.event,
                                            AnalyticsParameter.eventName: name,
                                            AnalyticsParameter.eventAction: action,
                                            AnalyticsParameter.eventDescription: description]
        
        reportSignal(name: name, parameters: parameters)
    }
    
    // MARK: - Report Signal
    private func reportSignal(name: String, parameters: [String: String]) {
        guard trackingID.isEmpty == false else {
            assertionFailure("`trackingID` is empty. Set with `TelemetryDeckReporter(trackingID:clientUUID:)`.")
            return
        }
        
        var signalParameters: [String: String] = AnalyticsSharedParameters.parameters()
        signalParameters.combine(with: parameters)
        
        sendSignal(name: name, parameters: signalParameters)
    }
    
    private func sendSignal(name: String, parameters: [String: String]) {
        TelemetryDeck.signal(name, parameters: parameters, customUserID: clientUUID)
    }
}

extension TelemetryDeckReporter {
    
    // MARK: - Regular Expression
    private struct Regex {
        static let trackerID: String = #"\b[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}\b"#
    }
}
