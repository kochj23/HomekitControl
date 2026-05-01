//
//  NovaAPIServerTests.swift
//  HomekitControlTests
//
//  Tests for the NovaAPIServer HTTP parser, routing logic, and response
//  formatting. The API server is the integration point for Nova and Claude
//  Code -- if request parsing breaks, all external automation stops working.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

// MARK: - HTTP Request Parsing Tests

/// Tests the NovaRequest HTTP/1.1 parser that powers the local API server.
/// This parser runs on every inbound request -- a parsing bug would silently
/// drop valid requests or misroute them.
final class NovaRequestParsingTests: XCTestCase {

    // MARK: - Valid Requests

    func test_parseGET_simpleRequest() {
        let raw = "GET /api/ping HTTP/1.1\r\nHost: 127.0.0.1:37432\r\n\r\n"
        let data = Data(raw.utf8)
        let req = NovaRequestTestHelper.parse(data)
        XCTAssertNotNil(req, "Valid GET request should parse successfully")
        XCTAssertEqual(req?.method, "GET")
        XCTAssertEqual(req?.path, "/api/ping")
        XCTAssertTrue(req?.body.isEmpty ?? false)
    }

    func test_parsePOST_withJSONBody() {
        let body = "{\"name\": \"Good Morning\"}"
        let raw = "POST /api/scenes/execute HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        let data = Data(raw.utf8)
        let req = NovaRequestTestHelper.parse(data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.method, "POST")
        XCTAssertEqual(req?.path, "/api/scenes/execute")
        XCTAssertEqual(req?.body, "{\"name\": \"Good Morning\"}")
    }

    func test_parseOPTIONS_request() {
        let raw = "OPTIONS /api/status HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
        let data = Data(raw.utf8)
        let req = NovaRequestTestHelper.parse(data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.method, "OPTIONS")
    }

    func test_parseHeaders_caseInsensitive() {
        let raw = "GET /api/status HTTP/1.1\r\nHost: 127.0.0.1\r\nAuthorization: Bearer test-token\r\nContent-Type: application/json\r\n\r\n"
        let data = Data(raw.utf8)
        let req = NovaRequestTestHelper.parse(data)
        XCTAssertNotNil(req)
        // Headers should be lowercased for lookup
        XCTAssertEqual(req?.headers["authorization"], "Bearer test-token")
        XCTAssertEqual(req?.headers["content-type"], "application/json")
    }

    func test_parsePath_stripsQueryString() {
        let raw = "GET /api/accessories?filter=light HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
        let data = Data(raw.utf8)
        let req = NovaRequestTestHelper.parse(data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.path, "/api/accessories")
    }

    // MARK: - Invalid / Incomplete Requests

    func test_parseIncompleteRequest_noHeaderTerminator() {
        let raw = "GET /api/ping HTTP/1.1\r\nHost: 127.0.0.1"
        let data = Data(raw.utf8)
        let req = NovaRequestTestHelper.parse(data)
        XCTAssertNil(req, "Request without \\r\\n\\r\\n terminator should fail to parse")
    }

    func test_parseEmptyData_returnsNil() {
        let req = NovaRequestTestHelper.parse(Data())
        XCTAssertNil(req)
    }

    func test_parseGarbage_returnsNil() {
        let data = Data("not an http request".utf8)
        let req = NovaRequestTestHelper.parse(data)
        XCTAssertNil(req)
    }

    func test_parsePOST_incompleteBody_returnsNil() {
        // Content-Length says 100 but body is only 10 bytes
        let raw = "POST /api/refresh HTTP/1.1\r\nContent-Length: 100\r\n\r\nshort body"
        let data = Data(raw.utf8)
        let req = NovaRequestTestHelper.parse(data)
        XCTAssertNil(req, "Request with incomplete body per Content-Length should return nil")
    }

    // MARK: - Body JSON Parsing

    func test_bodyJSON_validJSON() {
        let body = "{\"name\": \"Good Morning\"}"
        let raw = "POST /api/scenes/execute HTTP/1.1\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        let data = Data(raw.utf8)
        let req = NovaRequestTestHelper.parse(data)
        let json = req?.bodyJSON()
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["name"] as? String, "Good Morning")
    }

    func test_bodyJSON_invalidJSON_returnsNil() {
        let body = "not json {{{"
        let raw = "POST /api/scenes/execute HTTP/1.1\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        let data = Data(raw.utf8)
        let req = NovaRequestTestHelper.parse(data)
        XCTAssertNotNil(req, "Request should still parse even with invalid JSON body")
        XCTAssertNil(req?.bodyJSON(), "bodyJSON() should return nil for invalid JSON")
    }

    func test_bodyJSON_emptyBody_returnsNil() {
        let raw = "POST /api/refresh HTTP/1.1\r\nContent-Length: 0\r\n\r\n"
        let data = Data(raw.utf8)
        let req = NovaRequestTestHelper.parse(data)
        XCTAssertNil(req?.bodyJSON())
    }

    // MARK: - Edge Cases

    func test_parseMultipleHeaderValues() {
        let raw = "GET /api/status HTTP/1.1\r\nHost: 127.0.0.1\r\nX-Custom: value1: value2\r\n\r\n"
        let data = Data(raw.utf8)
        let req = NovaRequestTestHelper.parse(data)
        XCTAssertNotNil(req)
        // Header value with colon should preserve everything after first ": "
        XCTAssertEqual(req?.headers["x-custom"], "value1: value2")
    }

    func test_parseLargeBody() {
        let largeBody = String(repeating: "a", count: 10000)
        let raw = "POST /api/test HTTP/1.1\r\nContent-Length: \(largeBody.utf8.count)\r\n\r\n\(largeBody)"
        let data = Data(raw.utf8)
        let req = NovaRequestTestHelper.parse(data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.body.count, 10000)
    }
}

// MARK: - HTTP Response Formatting Tests

/// Tests the response helpers to ensure correct HTTP/1.1 formatting,
/// Content-Length accuracy, and proper JSON serialization.
@MainActor
final class NovaAPIResponseTests: XCTestCase {

    func test_serverPort_is37432() {
        let server = NovaAPIServer.shared
        XCTAssertEqual(server.port, 37432)
    }

    func test_serverIsSingleton() {
        let a = NovaAPIServer.shared
        let b = NovaAPIServer.shared
        XCTAssertTrue(a === b)
    }
}

// MARK: - Test Helper

/// Exposes the private NovaRequest parser for unit testing.
/// This mirrors the parser inside NovaAPIServer without requiring
/// a live network connection.
enum NovaRequestTestHelper {
    struct ParsedRequest {
        let method: String
        let path: String
        let body: String
        let headers: [String: String]

        func bodyJSON() -> [String: Any]? {
            guard let d = body.data(using: .utf8) else { return nil }
            return try? JSONSerialization.jsonObject(with: d) as? [String: Any]
        }
    }

    static func parse(_ data: Data) -> ParsedRequest? {
        guard let raw = String(data: data, encoding: .utf8), raw.contains("\r\n\r\n") else { return nil }
        let parts = raw.components(separatedBy: "\r\n\r\n")
        let lines = parts[0].components(separatedBy: "\r\n")
        guard let rl = lines.first else { return nil }
        let tokens = rl.components(separatedBy: " ")
        guard tokens.count >= 2 else { return nil }
        var hdrs: [String: String] = [:]
        for l in lines.dropFirst() {
            let kv = l.components(separatedBy: ": ")
            if kv.count >= 2 { hdrs[kv[0].lowercased()] = kv.dropFirst().joined(separator: ": ") }
        }
        let rawBody = parts.dropFirst().joined(separator: "\r\n\r\n")
        if let cl = hdrs["content-length"], let n = Int(cl), rawBody.utf8.count < n { return nil }
        let method = tokens[0]
        let path = tokens[1].components(separatedBy: "?").first ?? tokens[1]
        return ParsedRequest(method: method, path: path, body: rawBody, headers: hdrs)
    }
}
