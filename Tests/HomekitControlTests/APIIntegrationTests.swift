//
//  APIIntegrationTests.swift
//  HomekitControlTests
//
//  Integration tests for the live Nova API server on port 37432.
//  These tests verify the running instance responds correctly to HTTP requests.
//  They require HomekitControl to be running -- they skip gracefully if it's not.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class APIIntegrationTests: XCTestCase {

    private let baseURL = "http://127.0.0.1:37432"
    private let session = URLSession(configuration: {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        return config
    }())

    // MARK: - Health Check

    func test_ping_returnsOK() async throws {
        guard await isServerReachable() else {
            throw XCTSkip("HomekitControl API not running on port 37432")
        }

        let url = URL(string: "\(baseURL)/api/ping")!
        let (data, response) = try await session.data(from: url)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 200)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["pong"] as? String, "true")
    }

    // MARK: - Status Endpoint

    func test_status_returnsRequiredFields() async throws {
        guard await isServerReachable() else {
            throw XCTSkip("HomekitControl API not running on port 37432")
        }

        let url = URL(string: "\(baseURL)/api/status")!
        let (data, response) = try await session.data(from: url)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 200)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)

        // Required fields per API contract
        XCTAssertEqual(json?["status"] as? String, "running")
        XCTAssertEqual(json?["app"] as? String, "HomekitControl")
        XCTAssertNotNil(json?["port"])
        XCTAssertNotNil(json?["uptimeSeconds"])
    }

    func test_status_uptimeIsPositive() async throws {
        guard await isServerReachable() else {
            throw XCTSkip("HomekitControl API not running on port 37432")
        }

        let url = URL(string: "\(baseURL)/api/status")!
        let (data, _) = try await session.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let uptime = json?["uptimeSeconds"] as? Int {
            XCTAssertGreaterThanOrEqual(uptime, 0)
        }
    }

    // MARK: - Homes Endpoint

    func test_homes_returnsArray() async throws {
        guard await isServerReachable() else {
            throw XCTSkip("HomekitControl API not running on port 37432")
        }

        let url = URL(string: "\(baseURL)/api/homes")!
        let (data, response) = try await session.data(from: url)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 200)

        // Response is either an array of homes or an object with a note
        let parsed = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(parsed is [Any] || parsed is [String: Any],
                       "Response should be a JSON array or object")
    }

    // MARK: - Accessories Endpoint

    func test_accessories_returnsValidJSON() async throws {
        guard await isServerReachable() else {
            throw XCTSkip("HomekitControl API not running on port 37432")
        }

        let url = URL(string: "\(baseURL)/api/accessories")!
        let (data, response) = try await session.data(from: url)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 200)

        let parsed = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(parsed, "Accessories response should be valid JSON")
    }

    // MARK: - Scenes Endpoint

    func test_scenes_returnsValidJSON() async throws {
        guard await isServerReachable() else {
            throw XCTSkip("HomekitControl API not running on port 37432")
        }

        let url = URL(string: "\(baseURL)/api/scenes")!
        let (data, response) = try await session.data(from: url)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 200)

        let parsed = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(parsed, "Scenes response should be valid JSON")
    }

    // MARK: - Unknown Endpoint

    func test_unknownEndpoint_returns404() async throws {
        guard await isServerReachable() else {
            throw XCTSkip("HomekitControl API not running on port 37432")
        }

        let url = URL(string: "\(baseURL)/api/nonexistent")!
        let (data, response) = try await session.data(from: url)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 404)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["error"])
    }

    // MARK: - POST Without Auth

    func test_sceneExecute_withoutAuth_returns401() async throws {
        guard await isServerReachable() else {
            throw XCTSkip("HomekitControl API not running on port 37432")
        }

        let url = URL(string: "\(baseURL)/api/scenes/execute")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{\"name\": \"Test\"}".data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 401,
                        "POST without Bearer token should return 401 Unauthorized")

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertTrue((json?["error"] as? String)?.contains("Unauthorized") ?? false)
    }

    func test_refresh_withoutAuth_returns401() async throws {
        guard await isServerReachable() else {
            throw XCTSkip("HomekitControl API not running on port 37432")
        }

        let url = URL(string: "\(baseURL)/api/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await session.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 401)
    }

    // MARK: - Response Headers

    func test_response_hasContentType() async throws {
        guard await isServerReachable() else {
            throw XCTSkip("HomekitControl API not running on port 37432")
        }

        let url = URL(string: "\(baseURL)/api/ping")!
        let (_, response) = try await session.data(from: url)
        let httpResponse = response as! HTTPURLResponse

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
        XCTAssertNotNil(contentType)
        XCTAssertTrue(contentType?.contains("application/json") ?? false ||
                      contentType?.contains("text/plain") ?? false)
    }

    // MARK: - Helpers

    private func isServerReachable() async -> Bool {
        let url = URL(string: "\(baseURL)/api/ping")!
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
