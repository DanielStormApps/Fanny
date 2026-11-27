//
//  UpdateCheckerTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the update checker's version rules, trusted links, request, and responses through a stubbed session.
final class UpdateCheckerTests: XCTestCase {
    
    private let repositoryPath: String = "DanielStormApps/Fanny"
    private let date: Date = Date(timeIntervalSinceReferenceDate: 800000000.0)
    
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }
    
    // MARK: - Versions
    func testLatestVersionAcceptsReleaseTags() {
        XCTAssertEqual(UpdateChecker.latestVersion(fromTag: "26.2.0"), "26.2.0")
        XCTAssertEqual(UpdateChecker.latestVersion(fromTag: "2.3.0"), "2.3.0")
        XCTAssertEqual(UpdateChecker.latestVersion(fromTag: "26.10.12"), "26.10.12")
    }
    
    func testLatestVersionRejectsOtherTags() {
        XCTAssertNil(UpdateChecker.latestVersion(fromTag: ""))
        XCTAssertNil(UpdateChecker.latestVersion(fromTag: "v"))
        XCTAssertNil(UpdateChecker.latestVersion(fromTag: "v26.2.0"))
        XCTAssertNil(UpdateChecker.latestVersion(fromTag: "V26.2.0"))
        XCTAssertNil(UpdateChecker.latestVersion(fromTag: " 26.2.0\n"))
        XCTAssertNil(UpdateChecker.latestVersion(fromTag: "2.3"))
        XCTAssertNil(UpdateChecker.latestVersion(fromTag: "26.2.0.1"))
        XCTAssertNil(UpdateChecker.latestVersion(fromTag: "26.2.0-beta"))
        XCTAssertNil(UpdateChecker.latestVersion(fromTag: "27.1.0beta"))
        XCTAssertNil(UpdateChecker.latestVersion(fromTag: "26..0"))
        XCTAssertNil(UpdateChecker.latestVersion(fromTag: "release"))
    }
    
    func testIsNewerComparesNumerically() {
        XCTAssertTrue(UpdateChecker.isNewer("26.10.0", than: "26.9.0"))
        XCTAssertTrue(UpdateChecker.isNewer("26.1.1", than: "26.1.0"))
        XCTAssertTrue(UpdateChecker.isNewer("27.0.0", than: "26.12.3"))
        XCTAssertFalse(UpdateChecker.isNewer("26.1.0", than: "26.1.0"))
        XCTAssertFalse(UpdateChecker.isNewer("26.0.9", than: "26.1.0"))
        XCTAssertFalse(UpdateChecker.isNewer("2.3.0", than: "26.1.0"))
    }
    
    func testIsNewerIgnoresTrailingZeros() {
        XCTAssertFalse(UpdateChecker.isNewer("26.1.0", than: "26.1"))
        XCTAssertFalse(UpdateChecker.isNewer("26.1", than: "26.1.0"))
        XCTAssertTrue(UpdateChecker.isNewer("26.1.1", than: "26.1"))
    }
    
    // MARK: - Trusted Links
    func testRepositoryPathFromGitHubPath() {
        XCTAssertEqual(UpdateChecker.repositoryPath(fromGitHubPath: "https://github.com/DanielStormApps/Fanny"), repositoryPath)
        XCTAssertEqual(UpdateChecker.repositoryPath(fromGitHubPath: "https://github.com/DanielStormApps/Fanny/"), repositoryPath)
        XCTAssertNil(UpdateChecker.repositoryPath(fromGitHubPath: nil))
        XCTAssertNil(UpdateChecker.repositoryPath(fromGitHubPath: "https://example.com/DanielStormApps/Fanny"))
        XCTAssertNil(UpdateChecker.repositoryPath(fromGitHubPath: "https://github.com/DanielStormApps"))
    }
    
    func testTrustedReleaseURLAcceptsTheRepository() {
        XCTAssertTrue(UpdateChecker.isTrustedReleaseURL(URL(string: "https://github.com/DanielStormApps/Fanny/releases/tag/26.2.0")!, repositoryPath: repositoryPath))
        XCTAssertTrue(UpdateChecker.isTrustedReleaseURL(URL(string: "https://GitHub.com/DanielStormApps/Fanny/releases/latest")!, repositoryPath: repositoryPath))
    }
    
    func testTrustedReleaseURLRejectsOtherLinks() {
        let links: [String] = ["http://github.com/DanielStormApps/Fanny/releases/tag/26.2.0",
                               "https://evil.com/DanielStormApps/Fanny/releases/tag/26.2.0",
                               "https://github.com.evil.com/DanielStormApps/Fanny/releases/tag/26.2.0",
                               "https://github.com@evil.com/DanielStormApps/Fanny/releases/tag/26.2.0",
                               "https://github.com:8443/DanielStormApps/Fanny/releases/tag/26.2.0",
                               "https://github.com/DanielStormApps/FannyFake/releases/tag/26.2.0",
                               "https://github.com/DanielStormApps/Fanny",
                               "https://github.com/DanielStormApps/Fanny/../Other/releases",
                               "https://github.com/DanielStormApps/Fanny/%2E%2E/Other/releases",
                               "https://github.com/Other/Fanny/releases/tag/26.2.0",]
        
        for link in links {
            XCTAssertFalse(UpdateChecker.isTrustedReleaseURL(URL(string: link)!, repositoryPath: repositoryPath), link)
        }
    }
    
    func testAvailableUpdateOnlyForNewerVersions() {
        let releaseURL: URL = URL(string: "https://github.com/DanielStormApps/Fanny/releases/tag/26.2.0")!
        let update: AvailableUpdate? = UpdateChecker.availableUpdate(tagName: "26.2.0", releaseURL: releaseURL, currentVersion: "26.1.0", repositoryPath: repositoryPath)
        XCTAssertEqual(update, AvailableUpdate(version: "26.2.0", url: releaseURL))
        XCTAssertNil(UpdateChecker.availableUpdate(tagName: "26.1.0", releaseURL: releaseURL, currentVersion: "26.1.0", repositoryPath: repositoryPath))
        XCTAssertNil(UpdateChecker.availableUpdate(tagName: "nightly", releaseURL: releaseURL, currentVersion: "26.1.0", repositoryPath: repositoryPath))
    }
    
    func testAvailableUpdateWithUntrustedLinkFallsBackToLatestRelease() {
        let untrustedURL: URL = URL(string: "https://evil.com/DanielStormApps/Fanny/releases/tag/26.2.0")!
        let update: AvailableUpdate? = UpdateChecker.availableUpdate(tagName: "26.2.0", releaseURL: untrustedURL, currentVersion: "26.1.0", repositoryPath: repositoryPath)
        XCTAssertEqual(update?.url, URL(string: "https://github.com/DanielStormApps/Fanny/releases/latest"))
        
        let missingLinkUpdate: AvailableUpdate? = UpdateChecker.availableUpdate(tagName: "26.2.0", releaseURL: nil, currentVersion: "26.1.0", repositoryPath: repositoryPath)
        XCTAssertEqual(missingLinkUpdate?.url, URL(string: "https://github.com/DanielStormApps/Fanny/releases/latest"))
    }
    
    // MARK: - Schedule
    func testAutomaticCheckIsDueAfterADay() {
        XCTAssertTrue(UpdateChecker.isAutomaticCheckDue(isEnabled: true, lastCheckDate: nil, date: date))
        XCTAssertFalse(UpdateChecker.isAutomaticCheckDue(isEnabled: true, lastCheckDate: date.addingTimeInterval(-23.0 * 60.0 * 60.0), date: date))
        XCTAssertTrue(UpdateChecker.isAutomaticCheckDue(isEnabled: true, lastCheckDate: date.addingTimeInterval(-24.0 * 60.0 * 60.0), date: date))
    }
    
    func testAutomaticCheckIsDueWhenTheClockMovedBackward() {
        XCTAssertTrue(UpdateChecker.isAutomaticCheckDue(isEnabled: true, lastCheckDate: date.addingTimeInterval(60.0), date: date))
    }
    
    func testAutomaticCheckIsNeverDueWhenOff() {
        XCTAssertFalse(UpdateChecker.isAutomaticCheckDue(isEnabled: false, lastCheckDate: nil, date: date))
    }
    
    func testStarCountReadsLikeGitHub() {
        let counts: [Int] = [0, 999, 1000, 1049, 1050, 1390, 9999, 12345, 99_949, 99_950, 123_456, 999_499, 999_500, 1_234_567]
        let texts: [String] = counts.map({ AboutSettingsViewController.starCountText($0) })
        XCTAssertEqual(texts, ["0", "999", "1k", "1k", "1.1k", "1.4k", "10k", "12.3k", "99.9k", "100k", "123k", "999k", "1m", "1.2m"])
    }
    
    func testStarCountRefreshIsDueAfterADay() {
        XCTAssertTrue(AboutSettingsViewController.isStarCountRefreshDue(savedDate: nil, date: date))
        XCTAssertFalse(AboutSettingsViewController.isStarCountRefreshDue(savedDate: date.addingTimeInterval(-23.0 * 60.0 * 60.0), date: date))
        XCTAssertTrue(AboutSettingsViewController.isStarCountRefreshDue(savedDate: date.addingTimeInterval(-24.0 * 60.0 * 60.0), date: date))
        XCTAssertTrue(AboutSettingsViewController.isStarCountRefreshDue(savedDate: date.addingTimeInterval(60.0), date: date))
    }
    
    // MARK: - Status
    func testStatusTextForEachState() {
        let update: AvailableUpdate = AvailableUpdate(version: "26.2.0", url: URL(string: "https://github.com/DanielStormApps/Fanny/releases/latest")!)
        let texts: [String] = [UpdateChecker.statusText(isChecking: true, didFailManualCheck: false, availableUpdate: nil, lastCheckDate: nil),
                               UpdateChecker.statusText(isChecking: false, didFailManualCheck: true, availableUpdate: nil, lastCheckDate: date),
                               UpdateChecker.statusText(isChecking: false, didFailManualCheck: false, availableUpdate: update, lastCheckDate: date),
                               UpdateChecker.statusText(isChecking: false, didFailManualCheck: false, availableUpdate: nil, lastCheckDate: date),
                               UpdateChecker.statusText(isChecking: false, didFailManualCheck: false, availableUpdate: nil, lastCheckDate: nil),]
        
        XCTAssertEqual(Set(texts).count, texts.count)
        XCTAssertTrue(texts.allSatisfy({ $0.isEmpty == false }))
        XCTAssertTrue(texts[2].contains("26.2.0"))
    }
    
    // MARK: - Request
    func testRequestHeaders() throws {
        let request: URLRequest = try XCTUnwrap(UpdateChecker.makeRequest(repositoryPath: repositoryPath, eTag: "\"abc\"", appVersion: "26.1.0"))
        XCTAssertEqual(request.url?.absoluteString, "https://api.github.com/repos/DanielStormApps/Fanny/releases/latest")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "Fanny/26.1.0")
        XCTAssertEqual(request.value(forHTTPHeaderField: "If-None-Match"), "\"abc\"")
    }
    
    func testRequestWithoutETagSendsNoValidator() throws {
        let request: URLRequest = try XCTUnwrap(UpdateChecker.makeRequest(repositoryPath: repositoryPath, eTag: nil, appVersion: "26.1.0"))
        XCTAssertNil(request.value(forHTTPHeaderField: "If-None-Match"))
    }
    
    // MARK: - Responses
    func testReleaseResponse() throws {
        let body: Data = Data("{\"tag_name\": \"26.2.0\", \"html_url\": \"https://github.com/DanielStormApps/Fanny/releases/tag/26.2.0\", \"body\": \"Notes\"}".utf8)
        let result: UpdateChecker.CheckResult = try performStubbedRequest(statusCode: 200, headerFields: ["ETag": "\"etag-1\""], body: body)
        XCTAssertEqual(result, UpdateChecker.CheckResult.release(tagName: "26.2.0", url: URL(string: "https://github.com/DanielStormApps/Fanny/releases/tag/26.2.0"), eTag: "\"etag-1\""))
    }
    
    func testNotModifiedResponse() throws {
        let result: UpdateChecker.CheckResult = try performStubbedRequest(statusCode: 304, headerFields: [:], body: Data())
        XCTAssertEqual(result, UpdateChecker.CheckResult.notModified)
    }
    
    func testNotFoundResponseReadsAsNoRelease() throws {
        let body: Data = Data("{\"message\": \"Not Found\"}".utf8)
        let result: UpdateChecker.CheckResult = try performStubbedRequest(statusCode: 404, headerFields: [:], body: body)
        XCTAssertEqual(result, UpdateChecker.CheckResult.noRelease)
    }
    
    func testMalformedResponseFails() throws {
        let result: UpdateChecker.CheckResult = try performStubbedRequest(statusCode: 200, headerFields: [:], body: Data("not json".utf8))
        XCTAssertEqual(result, UpdateChecker.CheckResult.failed(reason: "malformed release"))
    }
    
    func testRateLimitedResponseFails() throws {
        let result: UpdateChecker.CheckResult = try performStubbedRequest(statusCode: 403, headerFields: [:], body: Data())
        XCTAssertEqual(result, UpdateChecker.CheckResult.failed(reason: "status 403"))
    }
    
    func testNetworkErrorFails() {
        let result: UpdateChecker.CheckResult = UpdateChecker.checkResult(data: nil, response: nil, error: URLError(URLError.Code.notConnectedToInternet))
        
        guard case .failed = result else {
            XCTFail("Expected a failure, got \(result)")
            return
        }
    }
    
    // MARK: - Helpers
    private func performStubbedRequest(statusCode: Int, headerFields: [String: String], body: Data) throws -> UpdateChecker.CheckResult {
        let request: URLRequest = try XCTUnwrap(UpdateChecker.makeRequest(repositoryPath: repositoryPath, eTag: nil, appVersion: "26.1.0"))
        
        StubURLProtocol.handler = { request in
            let response: HTTPURLResponse = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headerFields)!
            return (response, body)
        }
        
        let configuration: URLSessionConfiguration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session: URLSession = URLSession(configuration: configuration)
        
        let expectation: XCTestExpectation = expectation(description: "check finished")
        var result: UpdateChecker.CheckResult?
        
        UpdateChecker.performRequest(request, session: session) { checkResult in
            XCTAssertTrue(Thread.isMainThread)
            result = checkResult
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        session.invalidateAndCancel()
        return try XCTUnwrap(result)
    }
}

/// Answers every request with the response from `handler`, so no test reaches the network.
private final class StubURLProtocol: URLProtocol {
    
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler: (URLRequest) -> (HTTPURLResponse, Data) = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(URLError.Code.badServerResponse))
            return
        }
        
        let (response, data): (HTTPURLResponse, Data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {}
}
