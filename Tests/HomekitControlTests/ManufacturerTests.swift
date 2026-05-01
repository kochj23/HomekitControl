//
//  ManufacturerTests.swift
//  HomekitControlTests
//
//  Tests for Manufacturer detection — incorrect manufacturer detection can
//  cause wrong setup procedures or firmware tracking for physical devices.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class ManufacturerTests: XCTestCase {

    // MARK: - Detection from Device Names

    func test_detect_philipsHue_fromHue() {
        XCTAssertEqual(Manufacturer.detect(from: "Hue White Bulb"), .philipsHue)
    }

    func test_detect_philipsHue_fromPhilips() {
        XCTAssertEqual(Manufacturer.detect(from: "Philips Light Strip"), .philipsHue)
    }

    func test_detect_philipsHue_caseInsensitive() {
        XCTAssertEqual(Manufacturer.detect(from: "HUE COLOR"), .philipsHue)
        XCTAssertEqual(Manufacturer.detect(from: "philips"), .philipsHue)
    }

    func test_detect_lutron_fromLutron() {
        XCTAssertEqual(Manufacturer.detect(from: "Lutron Caseta"), .lutron)
    }

    func test_detect_lutron_fromCaseta() {
        XCTAssertEqual(Manufacturer.detect(from: "Caseta Dimmer"), .lutron)
    }

    func test_detect_ikea_fromIkea() {
        XCTAssertEqual(Manufacturer.detect(from: "IKEA Smart Bulb"), .ikea)
    }

    func test_detect_ikea_fromTradfri() {
        XCTAssertEqual(Manufacturer.detect(from: "TRADFRI LED"), .ikea)
    }

    func test_detect_ecobee() {
        XCTAssertEqual(Manufacturer.detect(from: "ecobee SmartThermostat"), .ecobee)
    }

    func test_detect_schlage() {
        XCTAssertEqual(Manufacturer.detect(from: "Schlage Encode Plus"), .schlage)
    }

    func test_detect_yale() {
        XCTAssertEqual(Manufacturer.detect(from: "Yale Assure Lock"), .yale)
    }

    func test_detect_august() {
        XCTAssertEqual(Manufacturer.detect(from: "August Smart Lock Pro"), .august)
    }

    func test_detect_eve_notLeviton() {
        // "eve" should match Eve, but "leviton" should NOT match Eve
        XCTAssertEqual(Manufacturer.detect(from: "Eve Motion"), .eve)
        XCTAssertEqual(Manufacturer.detect(from: "Leviton Switch"), .leviton)
    }

    func test_detect_lifx() {
        XCTAssertEqual(Manufacturer.detect(from: "LIFX Mini"), .lifx)
    }

    func test_detect_wemo_fromWemo() {
        XCTAssertEqual(Manufacturer.detect(from: "Wemo Smart Plug"), .wemo)
    }

    func test_detect_wemo_fromBelkin() {
        XCTAssertEqual(Manufacturer.detect(from: "Belkin WeMo"), .wemo)
    }

    func test_detect_tpLink_fromTPLink() {
        XCTAssertEqual(Manufacturer.detect(from: "TP-Link Kasa"), .tpLink)
    }

    func test_detect_tpLink_fromKasa() {
        XCTAssertEqual(Manufacturer.detect(from: "Kasa Smart Plug"), .tpLink)
    }

    func test_detect_meross() {
        XCTAssertEqual(Manufacturer.detect(from: "Meross Smart Plug"), .meross)
    }

    func test_detect_aqara_fromAqara() {
        XCTAssertEqual(Manufacturer.detect(from: "Aqara Motion Sensor"), .aqara)
    }

    func test_detect_aqara_fromXiaomi() {
        XCTAssertEqual(Manufacturer.detect(from: "Xiaomi Smart Hub"), .aqara)
    }

    func test_detect_sonos() {
        XCTAssertEqual(Manufacturer.detect(from: "Sonos One"), .sonos)
    }

    func test_detect_apple_fromApple() {
        XCTAssertEqual(Manufacturer.detect(from: "Apple HomePod"), .apple)
    }

    func test_detect_apple_fromHomePod() {
        XCTAssertEqual(Manufacturer.detect(from: "HomePod mini"), .apple)
    }

    func test_detect_google() {
        XCTAssertEqual(Manufacturer.detect(from: "Google Nest Hub"), .google)
    }

    func test_detect_amazon_fromAmazon() {
        XCTAssertEqual(Manufacturer.detect(from: "Amazon Echo Show"), .amazon)
    }

    func test_detect_amazon_fromEcho() {
        XCTAssertEqual(Manufacturer.detect(from: "Echo Dot"), .amazon)
    }

    func test_detect_ring() {
        XCTAssertEqual(Manufacturer.detect(from: "Ring Doorbell"), .ring)
    }

    func test_detect_nest() {
        XCTAssertEqual(Manufacturer.detect(from: "Nest Thermostat"), .nest)
    }

    func test_detect_honeywell() {
        XCTAssertEqual(Manufacturer.detect(from: "Honeywell T9"), .honeywell)
    }

    func test_detect_leviton() {
        XCTAssertEqual(Manufacturer.detect(from: "Leviton Decora"), .leviton)
    }

    func test_detect_ge_fromGE() {
        XCTAssertEqual(Manufacturer.detect(from: "GE C-Life"), .ge)
    }

    func test_detect_ge_fromCync() {
        XCTAssertEqual(Manufacturer.detect(from: "Cync Smart Bulb"), .ge)
    }

    func test_detect_hatch() {
        XCTAssertEqual(Manufacturer.detect(from: "Hatch Rest+"), .hatch)
    }

    func test_detect_unknown_forUnrecognized() {
        XCTAssertEqual(Manufacturer.detect(from: "Some Random Device"), .unknown)
    }

    func test_detect_unknown_forEmptyString() {
        XCTAssertEqual(Manufacturer.detect(from: ""), .unknown)
    }

    // MARK: - Codable

    func test_allCases_areCodeable() throws {
        for manufacturer in Manufacturer.allCases {
            let data = try JSONEncoder().encode(manufacturer)
            let decoded = try JSONDecoder().decode(Manufacturer.self, from: data)
            XCTAssertEqual(decoded, manufacturer, "Failed roundtrip for \(manufacturer)")
        }
    }

    // MARK: - Icons

    func test_allCases_haveIcons() {
        for manufacturer in Manufacturer.allCases {
            XCTAssertFalse(manufacturer.icon.isEmpty, "\(manufacturer) has no icon")
        }
    }

    // MARK: - CaseIterable

    func test_allCases_includes25Manufacturers() {
        // Sanity check — if this fails, a manufacturer was added/removed without updating tests
        XCTAssertEqual(Manufacturer.allCases.count, 25)
    }
}
