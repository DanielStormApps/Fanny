//
//  GitHubIssue.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/26/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// Builds links to GitHub's new issue forms with this Mac's details filled in, so a report arrives with what is needed to look into it.
enum GitHubIssue {
    
    enum Kind {
        case problem
        case featureRequest
        
        /// A file in `.github/ISSUE_TEMPLATE` on the public repo.
        var template: String {
            let template: String
            
            switch self {
            case .problem:
                template = "bug_report.yml"
            case .featureRequest:
                template = "feature_request.yml"
            }
            
            return template
        }
        
        /// Also set by the template, but sent too so the label applies even if the template is missing.
        var label: String {
            let label: String
            
            switch self {
            case .problem:
                label = "bug"
            case .featureRequest:
                label = "feature request"
            }
            
            return label
        }
    }
    
    /// Field ids from the issue templates, which GitHub fills from matching query parameters.
    enum Field: String {
        case fannyVersion = "fanny-version"
        case macOSVersion = "macos-version"
        case macModel = "mac-model"
        case chip = "chip"
        case fanCount = "fan-count"
    }
    
    /// Keeps `+`, `&`, and `=` encoded, since GitHub would read a bare `+` as a space and the others as new parameters.
    private static let queryValueAllowedCharacters: CharacterSet = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))
    
    // MARK: - URL
    static func url(kind: Kind, gitHubPath: String, fields: [(Field, String)]) -> URL? {
        let parameters: [(String, String)] = [("template", kind.template), ("labels", kind.label)] + fields.map({ ($0.0.rawValue, $0.1) })
        let query: String = parameters.compactMap({ name, value in
            guard let encodedValue: String = value.addingPercentEncoding(withAllowedCharacters: GitHubIssue.queryValueAllowedCharacters) else { return nil }
            return "\(name)=\(encodedValue)"
        }).joined(separator: "&")
        
        return URL(string: "\(gitHubPath)/issues/new?\(query)")
    }
    
    // MARK: - This Mac
    /// The person sees every value in the form before submitting, and none of them is a reading.
    static func currentFields() -> [(Field, String)] {
        var fields: [(Field, String)] = [(Field.fannyVersion, "\(Bundle.version) (\(Bundle.buildNumber))"),
                                         (Field.macOSVersion, GitHubIssue.macOSVersion()),]
        
        if let macModel: String = GitHubIssue.systemValue(named: "hw.model") {
            fields.append((Field.macModel, macModel))
        }
        
        if let chip: String = GitHubIssue.systemValue(named: "machdep.cpu.brand_string") {
            fields.append((Field.chip, chip))
        }
        
        if let snapshot: ReadingsSnapshot = SensorMonitor.shared.snapshot, snapshot.fanStatus != ReadingsSnapshot.FanStatus.unavailable {
            fields.append((Field.fanCount, String(snapshot.fans.count)))
        }
        
        return fields
    }
    
    /// Such as 27.2 (27C52).
    private static func macOSVersion() -> String {
        let version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        var text: String = "\(version.majorVersion).\(version.minorVersion)"
        
        if version.patchVersion > 0 {
            text = text + ".\(version.patchVersion)"
        }
        
        if let build: String = GitHubIssue.systemValue(named: "kern.osversion") {
            text = text + " (\(build))"
        }
        
        return text
    }
    
    private static func systemValue(named name: String) -> String? {
        var size: Int = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        
        var buffer: [CChar] = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        
        let value: String = String(cString: buffer).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
