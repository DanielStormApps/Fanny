//
//  URLRequest+Extensions.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

extension URLRequest {
    
    struct httpMethod {
        static let GET: String = "GET"
    }
    
    init(url: URL, httpBody: Data?, httpHeaderFields: [String: String], httpMethod: String, networkServiceType: NetworkServiceType = .default) {
        self.init(url: url)
        self.networkServiceType = networkServiceType
        self.httpMethod = httpMethod
        self.httpBody = httpBody
        
        for (key, value) in httpHeaderFields {
            self.setValue(value, forHTTPHeaderField: key)
        }
    }
}
