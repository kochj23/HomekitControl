//
//  WidgetDataTests.swift
//  HomekitControlTests
//
//  Tests for widget deep link URL construction.
//  Note: WidgetScene, WidgetDeviceHealth, and WidgetData types are in the
//  widget extension target and are not accessible from the main app test target.
//  Only deep link URL tests (which use Foundation types) are included here.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
// Widget types are in a separate target, so we test only what's accessible

final class WidgetDeepLinkTests: XCTestCase {

    // MARK: - Deep Link URL Construction

    func test_deepLink_executeScene_format() {
        let sceneId = UUID()
        let urlString = "homekitcontrol://scene/\(sceneId.uuidString)"
        let url = URL(string: urlString)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "homekitcontrol")
        XCTAssertTrue(url!.absoluteString.contains(sceneId.uuidString))
    }

    func test_deepLink_openDevices_format() {
        let url = URL(string: "homekitcontrol://devices")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "devices")
    }

    func test_deepLink_openHealth_format() {
        let url = URL(string: "homekitcontrol://health")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "health")
    }

    func test_deepLink_openScenes_format() {
        let url = URL(string: "homekitcontrol://scenes")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "scenes")
    }

    func test_deepLink_invalidUUID_stillCreatesURL() {
        let url = URL(string: "homekitcontrol://scene/not-a-uuid")
        XCTAssertNotNil(url, "URL should be constructable even with invalid UUID path")
    }
}
