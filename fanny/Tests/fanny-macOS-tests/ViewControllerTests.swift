//
//  ViewControllerTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the base view controller's analytics title.
final class ViewControllerTests: XCTestCase {
    
    func testAnalyticsTitleIsNilByDefault() {
        let viewController: ViewController = ViewController()
        XCTAssertNil(viewController.analyticsTitle)
    }
    
    func testAnalyticsTitleIsStored() {
        let viewController: ViewController = ViewController()
        viewController.analytics(title: "general")
        XCTAssertEqual(viewController.analyticsTitle, "general")
    }
    
    func testRunsInsideXCTestHost() {
        XCTAssertNotNil(ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"])
    }
}
