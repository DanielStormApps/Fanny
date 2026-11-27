//
//  FanReading.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// The speeds of one fan, in revolutions per minute.
struct FanReading: Codable, Equatable, Identifiable {
    /// The SMC fan index, starting at 0.
    let id: Int
    var currentRPM: Double
    var minimumRPM: Double?
    var maximumRPM: Double?
    var targetRPM: Double?
    
    /// Apple silicon fans rest at 0 RPM until they are needed, so a real fan can read 0.
    var isStopped: Bool {
        return currentRPM < 1.0 && (maximumRPM ?? 0.0) > 0.0
    }
    
    /// Where the current speed sits from the minimum, 0.0, to the maximum, 1.0, for the speed bars.
    /// - Returns: `nil` when the fan does not report both limits, so no bar is drawn.
    var speedFraction: Double? {
        guard
            let minimumRPM: Double = minimumRPM,
            let maximumRPM: Double = maximumRPM,
            maximumRPM > minimumRPM
        else { return nil }
        
        let fraction: Double
        
        if isStopped {
            fraction = 0.0
        }
        else {
            fraction = min(max((currentRPM - minimumRPM) / (maximumRPM - minimumRPM), 0.0), 1.0)
        }
        
        return fraction
    }
}
