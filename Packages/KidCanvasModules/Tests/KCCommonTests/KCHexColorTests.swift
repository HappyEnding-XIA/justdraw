//
//  KCHexColorTests.swift
//  KCCommonTests
//
//  Created by 小大 on 2026/06/25.
//

import XCTest
@testable import KCCommon

final class HexColorTests: XCTestCase {
    func testParsesSixDigitOpaqueHex() {
        let color = KCHexColor(hex: "#F0A050")
        XCTAssertNotNil(color)
        XCTAssertEqual(color?.hex, "#F0A050")
    }

    func testParsesWithoutHashAndNormalizesToUppercase() {
        let color = KCHexColor(hex: "3366cc")
        XCTAssertEqual(color?.hex, "#3366CC")
    }

    func testParsesShorthandThreeDigit() {
        let color = KCHexColor(hex: "#0af")
        XCTAssertEqual(color?.hex, "#00AAFF")
    }

    func testParsesEightDigitWithAlpha() {
        let color = KCHexColor(hex: "#80808080")
        XCTAssertNotNil(color)
        XCTAssertNotEqual(color?.alpha, 1.0)
        XCTAssertEqual(color?.hex, "#80808080")
    }

    func testRoundTripsAlpha() {
        let original = KCHexColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.5)
        let parsed = KCHexColor(hex: original.hex)
        XCTAssertEqual(original.hex, parsed?.hex)
    }

    func testRejectsMalformedInput() {
        XCTAssertNil(KCHexColor(hex: "nope"))
        XCTAssertNil(KCHexColor(hex: "#12345"))
        XCTAssertNil(KCHexColor(hex: "#GGGGGG"))
    }

    func testRgba8MatchesPrototypeRounding() {
        // Prototype uses lrint(component * 255): 0.94 -> 240.
        let color = KCHexColor(red: 0.94, green: 0.43, blue: 0.45, alpha: 1.0)
        XCTAssertEqual(color.rgba8.red, 240)
        XCTAssertEqual(color.rgba8.green, 110)
        XCTAssertEqual(color.rgba8.blue, 115)
        XCTAssertEqual(color.rgba8.alpha, 255)
    }

    func testCodableRoundTrip() throws {
        // Compare the canonical hex string: the stored form survives the
        // 8-bit-per-channel quantization, the raw Doubles do not.
        let original = KCHexColor(red: 0.5, green: 0.25, blue: 0.125, alpha: 1.0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KCHexColor.self, from: data)
        XCTAssertEqual(original.hex, decoded.hex)
    }

    func testClampsOutOfRangeComponents() {
        let color = KCHexColor(red: 2, green: -1, blue: 0.5, alpha: 1)
        XCTAssertEqual(color.red, 1)
        XCTAssertEqual(color.green, 0)
    }
}

final class LoggingTests: XCTestCase {
    func testNullLoggerIsDefault() {
        // Should not crash and should not require a sink.
        KCLog.info("hello")
    }

    func testBufferedLoggerCapturesEntries() {
        let buffered = KCBufferedLogger()
        buffered.log(.warning, "watch out")
        XCTAssertEqual(buffered.snapshot().count, 1)
        XCTAssertEqual(buffered.snapshot().first?.level, .warning)
        XCTAssertEqual(buffered.snapshot().first?.message, "watch out")
    }

    func testSwappingGlobalSinkRoutesMessages() {
        let previous = KCLog.sink
        defer { KCLog.sink = previous }
        let buffered = KCBufferedLogger()
        KCLog.sink = buffered
        KCLog.error("boom")
        XCTAssertEqual(buffered.snapshot().last?.message, "boom")
    }
}
