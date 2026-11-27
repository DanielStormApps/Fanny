//
//  FanEntity.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// One of the Mac's fans, so a Shortcut can ask for a single fan's speed.
struct FanEntity: AppEntity {
    
    /// The SMC fan index, starting at 0.
    let id: Int
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Fan")
    static var defaultQuery: FanQuery = FanQuery()
    
    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: "\(ReadingFormatter.fanName(id: id, settings: FannySettingsManager.shared.settings))")
    }
}

/// Lists the fans the latest read found.
struct FanQuery: EntityQuery {
    
    @MainActor
    func entities(for identifiers: [Int]) async throws -> [FanEntity] {
        let fanIDs: [Int] = await FanQuery.currentFanIDs()
        return identifiers.filter({ fanIDs.contains($0) }).map({ FanEntity(id: $0) })
    }
    
    @MainActor
    func suggestedEntities() async throws -> [FanEntity] {
        return await FanQuery.currentFanIDs().map({ FanEntity(id: $0) })
    }
    
    /// Reads first when the app has not read yet, such as when Shortcuts launched it.
    @MainActor
    private static func currentFanIDs() async -> [Int] {
        AppBootstrap.shared.runIfNeeded()
        let snapshot: ReadingsSnapshot
        
        if let currentSnapshot: ReadingsSnapshot = SensorMonitor.shared.snapshot {
            snapshot = currentSnapshot
        }
        else {
            snapshot = await SensorMonitor.shared.refreshNow()
        }
        
        return snapshot.fanStatus == ReadingsSnapshot.FanStatus.fans ? snapshot.fans.map({ $0.id }) : []
    }
}
