//
//  Storage+LegacyMigration.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

extension Storage {
    
    // MARK: - Legacy Migration
    /// Where a later release moves renamed or retired keys into their new form.
    /// - Note: The old app's settings are not carried forward, because reading its non team prefixed group asks the user for access to another app's data.
    static func migrateLegacyKeys() {
        Log.debug("💾 migrateLegacyKeys -> nothing to migrate")
    }
}
