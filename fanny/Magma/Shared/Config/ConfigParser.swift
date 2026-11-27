//
//  ConfigParser.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A parser that loads a config from a file or a URL.
final class ConfigParser {
    
    func config(filePath path: String) -> Config? {
        let fileURL: URL = URL(fileURLWithPath: path)
        guard let data: Data = try? Data(contentsOf: fileURL) else { return nil }
        return Config(data: data)
    }
    
    func config(path: String, completion: @escaping (Config?) -> ()) {
        guard let url: URL = URL(string: path) else {
            completion(nil)
            return
        }
        
        let urlRequest: URLRequest = URLRequest(url: url, httpBody: nil, httpHeaderFields: [:], httpMethod: URLRequest.httpMethod.GET, networkServiceType: .responsiveData)
        
        URLSession.shared.dataTask(with: urlRequest) { data, _, _ in
            completion(Config(data: data))
        }.resume()
    }
}
