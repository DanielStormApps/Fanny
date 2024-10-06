//
//  Fan+FNYExtensions.swift
//  Fanny
//
//  Created by Jorge Pastor on 06/10/2024.
//  Copyright © 2024 Daniel Storm. All rights reserved.
//

import Foundation

extension Array where Element == Fan {
    
    func fastest() -> Fan? {
        return self.max(by: { (a, b) -> Bool in a.currentRPM ?? 0 < b.currentRPM ?? 0 })
    }
}

extension Fan {
    
    func formattedRPM() -> String {
        return (currentRPM?.description ?? "?") + " RPM"
    }
}
