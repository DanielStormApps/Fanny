//
//  DelegateMulticast.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A multicast delegate for broadcasting events to multiple listeners.
final class DelegateMulticast<T> {
    
    private var delegates: [WeakDelegate] = []
    
    func add(_ delegate: T) {
        guard Mirror(reflecting: delegate).subjectType is AnyClass else { return }
        let newDelegate: WeakDelegate = WeakDelegate(value: delegate as AnyObject)
        
        // Listeners such as Settings panes come and go, so released ones are dropped here.
        delegates = delegates.filter({ $0.value != nil })
        
        for delegate in delegates {
            guard newDelegate != delegate else { return }
        }
        
        delegates.append(newDelegate)
    }
    
    func invoke(_ invocation: (T) -> ()) {
        for delegate in delegates {
            guard let delegate: T = delegate.value as? T else { continue }
            invocation(delegate)
        }
    }
}

/// A weak reference to a delegate, so that listeners are not retained by the multicast.
private final class WeakDelegate: Equatable {
    
    weak var value: AnyObject?
    
    static func ==(lhs: WeakDelegate, rhs: WeakDelegate) -> Bool {
        return lhs.value === rhs.value
    }
    
    // MARK: - Init
    init(value: AnyObject) {
        self.value = value
    }
}
