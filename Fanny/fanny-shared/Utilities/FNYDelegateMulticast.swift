//
//  FNYDelegateMulticast.swift
//  Fanny
//
//  Created by Daniel Storm on 9/15/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation

class FNYDelegateMulticast<T> {
    
    private var delegates: [WeakDelegate] = []
    
    func add(_ delegate: T) {
        guard Mirror(reflecting: delegate).subjectType is AnyClass else { return }
        let newDelegate: WeakDelegate = WeakDelegate(value: delegate as AnyObject)
        
        for delegate in delegates {
            guard newDelegate != delegate else { return }
        }
        
        delegates.append(newDelegate)
    }
    
    func remove(_ delegate: T) {
        guard Mirror(reflecting: delegate).subjectType is AnyClass else { return }
        let oldDelegate: WeakDelegate = WeakDelegate(value: delegate as AnyObject)
        
        for i in 0..<delegates.count {
            guard delegates[i] == oldDelegate else { continue }
            delegates.remove(at: i)
            break
        }
    }
    
    func invoke(_ invocation: (T) -> ()) {
        for delegate in delegates {
            guard let delegate: T = delegate.value as? T else { continue }
            invocation(delegate)
        }
    }
    
}

private class WeakDelegate: Equatable {
    
    weak var value: AnyObject?
    
    static func ==(lhs: WeakDelegate, rhs: WeakDelegate) -> Bool {
        return lhs.value === rhs.value
    }
    
    init(value: AnyObject) {
        self.value = value
    }
    
}
