//
//  FNYMenu.swift
//  Fanny
//
//  Created by Daniel Storm on 9/2/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation
import Cocoa

class FNYMenu: NSMenu {

    // MARK: - Init
    init() {
        super.init(title: String())
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
