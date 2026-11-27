//
//  Application.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// An application that broadcasts its life cycle events to its delegates.
protocol Application {
    var delegate: DelegateMulticast<ApplicationDelegate> { get set }
}
