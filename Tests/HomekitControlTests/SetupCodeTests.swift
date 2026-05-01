//
//  SetupCodeTests.swift
//  HomekitControlTests
//
//  Tests for SetupCode model — validates pairing code formatting and validation.
//  Incorrect codes can prevent device pairing or cause pairing to the wrong device.
//
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomekitControl

final class SetupCodeTests: XCTestCase {

    // MARK: - Code Formatting

    func test_formattedCode_validEightDigits_returnsFormattedCode() {
        let code = SetupCode(deviceName: "Light", code: "12345678")
        XCTAssertEqual(code.formattedCode, "123-45-678")
    }

    func test_formattedCode_alreadyFormatted_returnsReformatted() {
        let code = SetupCode(deviceName: "Light", code: "123-45-678")
        XCTAssertEqual(code.formattedCode, "123-45-678")
    }

    func test_formattedCode_tooShort_returnsOriginal() {
        let code = SetupCode(deviceName: "Light", code: "1234")
        XCTAssertEqual(code.formattedCode, "1234")
    }

    func test_formattedCode_tooLong_returnsOriginal() {
        let code = SetupCode(deviceName: "Light", code: "123456789")
        XCTAssertEqual(code.formattedCode, "123456789")
    }

    func test_formattedCode_empty_returnsEmpty() {
        let code = SetupCode(deviceName: "Light", code: "")
        XCTAssertEqual(code.formattedCode, "")
    }

    func test_formattedCode_withExtraDashes_countsDigitsOnly() {
        // "1-2-3-4-5-6-7-8" has 8 digits, should format correctly
        let code = SetupCode(deviceName: "Light", code: "1-2-3-4-5-6-7-8")
        XCTAssertEqual(code.formattedCode, "123-45-678")
    }

    // MARK: - Code Validation

    func test_isValidCode_eightDigits_returnsTrue() {
        let code = SetupCode(deviceName: "Light", code: "12345678")
        XCTAssertTrue(code.isValidCode)
    }

    func test_isValidCode_eightDigitsFormatted_returnsTrue() {
        let code = SetupCode(deviceName: "Light", code: "123-45-678")
        XCTAssertTrue(code.isValidCode)
    }

    func test_isValidCode_allZeros_returnsTrue() {
        let code = SetupCode(deviceName: "Light", code: "00000000")
        XCTAssertTrue(code.isValidCode)
    }

    func test_isValidCode_allNines_returnsTrue() {
        let code = SetupCode(deviceName: "Light", code: "99999999")
        XCTAssertTrue(code.isValidCode)
    }

    func test_isValidCode_tooShort_returnsFalse() {
        let code = SetupCode(deviceName: "Light", code: "1234567")
        XCTAssertFalse(code.isValidCode)
    }

    func test_isValidCode_tooLong_returnsFalse() {
        let code = SetupCode(deviceName: "Light", code: "123456789")
        XCTAssertFalse(code.isValidCode)
    }

    func test_isValidCode_containsLetters_returnsFalse() {
        let code = SetupCode(deviceName: "Light", code: "1234ABCD")
        XCTAssertFalse(code.isValidCode)
    }

    func test_isValidCode_containsSpaces_returnsFalse() {
        let code = SetupCode(deviceName: "Light", code: "1234 678")
        XCTAssertFalse(code.isValidCode)
    }

    func test_isValidCode_empty_returnsFalse() {
        let code = SetupCode(deviceName: "Light", code: "")
        XCTAssertFalse(code.isValidCode)
    }

    // MARK: - Codable Roundtrip

    func test_codableRoundtrip_preservesAllFields() throws {
        let original = SetupCode(
            deviceName: "Kitchen Light",
            code: "12345678",
            manufacturer: .philipsHue,
            category: .light,
            room: "Kitchen",
            notes: "Above sink",
            serialNumber: "SN123",
            model: "A19"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(SetupCode.self, from: data)

        XCTAssertEqual(decoded.deviceName, "Kitchen Light")
        XCTAssertEqual(decoded.code, "12345678")
        XCTAssertEqual(decoded.manufacturer, .philipsHue)
        XCTAssertEqual(decoded.category, .light)
        XCTAssertEqual(decoded.room, "Kitchen")
        XCTAssertEqual(decoded.notes, "Above sink")
        XCTAssertEqual(decoded.serialNumber, "SN123")
        XCTAssertEqual(decoded.model, "A19")
        XCTAssertEqual(decoded.id, original.id)
    }

    func test_codableRoundtrip_nilOptionals() throws {
        let original = SetupCode(deviceName: "Light", code: "00000000")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SetupCode.self, from: data)

        XCTAssertNil(decoded.room)
        XCTAssertNil(decoded.notes)
        XCTAssertNil(decoded.serialNumber)
        XCTAssertNil(decoded.model)
        XCTAssertNil(decoded.photoPath)
        XCTAssertNil(decoded.photoData)
    }

    // MARK: - Identity

    func test_setupCode_hasUniqueId() {
        let code1 = SetupCode(deviceName: "Light 1", code: "11111111")
        let code2 = SetupCode(deviceName: "Light 2", code: "22222222")
        XCTAssertNotEqual(code1.id, code2.id)
    }

    func test_setupCode_hashableByContent() {
        let id = UUID()
        let now = Date()
        let code1 = SetupCode(id: id, deviceName: "Light", code: "12345678", createdAt: now, updatedAt: now)
        let code2 = SetupCode(id: id, deviceName: "Light", code: "12345678", createdAt: now, updatedAt: now)
        XCTAssertEqual(code1, code2)
    }
}
