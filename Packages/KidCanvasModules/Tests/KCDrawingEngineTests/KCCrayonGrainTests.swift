//
//  KCCrayonGrainTests.swift
//  KCDrawingEngineTests
//
//  Created by 小大 on 2026/06/26.
//

import XCTest
@testable import KCDrawingEngine

final class CrayonGrainTests: XCTestCase {

    // Reference case hand-computed from the original Objective-C math:
    // bounds {0,0,100,50}, lineWidth 10.
    // grainBounds {-5,-5,110,60}; spacing = max(4, 4.6) = 4.6;
    // columnCount = ceil(110/4.6) = 24; rowCount = ceil(60/4.6) = 14;
    // dash count = (14+1) * (24+1) = 375; dashWidth = max(0.7, 0.45) = 0.7.
    private static let referenceBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
    private static let referenceLineWidth: CGFloat = 10

    func testEmptyBoundsReturnsNoDashes() {
        XCTAssertTrue(KCCrayonGrain.dashes(pathBounds: .zero, lineWidth: 10).isEmpty)
        XCTAssertTrue(KCCrayonGrain.dashes(pathBounds: CGRect(x: 5, y: 5, width: 0, height: 0),
                                           lineWidth: 10).isEmpty)
    }

    func testDashCountAndConstantWidthForReferenceBounds() {
        let dashes = KCCrayonGrain.dashes(pathBounds: CrayonGrainTests.referenceBounds,
                                          lineWidth: CrayonGrainTests.referenceLineWidth)
        XCTAssertEqual(dashes.count, 375)
        for dash in dashes {
            XCTAssertEqual(dash.lineWidth, 0.7, accuracy: 1e-9)
        }
    }

    func testFirstDashGeometryMatchesPrototype() {
        // row 0, column 0: seed 0 → jitter (-1.02, -0.84); center (-6.02, -5.84);
        // dashLength 1.5 (floored); y offset +0.7 (even seed).
        let dashes = KCCrayonGrain.dashes(pathBounds: CrayonGrainTests.referenceBounds,
                                          lineWidth: CrayonGrainTests.referenceLineWidth)
        let first = dashes[0]
        XCTAssertEqual(first.start.x, -6.77, accuracy: 1e-9)
        XCTAssertEqual(first.start.y, -5.84, accuracy: 1e-9)
        XCTAssertEqual(first.end.x, -5.27, accuracy: 1e-9)
        XCTAssertEqual(first.end.y, -5.14, accuracy: 1e-9)
    }

    func testDashGeometryAtRowColumnMatchesPrototype() {
        // row 1, column 1 (row-major index 25 + 1 = 26): seed 54.
        // jitter (0.68, 0.28); center (0.28, -0.12);
        // dashLength = 10 * (0.10 + 4*0.018) = 1.72; y offset +0.7.
        let dashes = KCCrayonGrain.dashes(pathBounds: CrayonGrainTests.referenceBounds,
                                          lineWidth: CrayonGrainTests.referenceLineWidth)
        let dash = dashes[26]
        XCTAssertEqual(dash.start.x, -0.58, accuracy: 1e-9)
        XCTAssertEqual(dash.start.y, -0.12, accuracy: 1e-9)
        XCTAssertEqual(dash.end.x, 1.14, accuracy: 1e-9)
        XCTAssertEqual(dash.end.y, 0.58, accuracy: 1e-9)
    }

    func testGridRespectsColumnAndRowCaps() {
        // Huge bounds with small spacing force both caps: 220 columns × 180 rows.
        // lineWidth 4 → spacing = max(4, 1.84) = 4; grainBounds grows by 2 each side.
        let dashes = KCCrayonGrain.dashes(pathBounds: CGRect(x: 0, y: 0, width: 10000, height: 10000),
                                          lineWidth: 4)
        XCTAssertEqual(dashes.count, (180 + 1) * (220 + 1))
    }

    func testDashWidthFloorsToPointSevenForThinLines() {
        let dashes = KCCrayonGrain.dashes(pathBounds: CGRect(x: 0, y: 0, width: 20, height: 20),
                                          lineWidth: 0.01)
        XCTAssertFalse(dashes.isEmpty)
        for dash in dashes {
            XCTAssertEqual(dash.lineWidth, 0.7, accuracy: 1e-9)
        }
    }
}
