//
//  KCContentPickerLayoutTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/07/02.
//

import XCTest
@testable import KCDomain

final class KCContentPickerLayoutTests: XCTestCase {

    func testDefaultLayoutMatchesPrototypeConstants() {
        let layout = KCContentPickerLayout()
        XCTAssertEqual(layout.columns, 6)
        XCTAssertEqual(layout.buttonSize, 30.0)
        XCTAssertEqual(layout.spacing, 8.0)
    }

    func testGridWidthIsColumnsTimesButtonPlusSpacing() {
        // 6 列 × 30 + 5 × 8 = 220。
        let layout = KCContentPickerLayout()
        XCTAssertEqual(layout.gridWidth, 220.0)
    }

    func testGridHeightForExactRows() {
        // 24 色 = 4 整行：4 × 30 + 3 × 8 = 144。
        let layout = KCContentPickerLayout()
        XCTAssertEqual(layout.gridHeight(forColorCount: 24), 144.0)
    }

    func testGridHeightRoundsUpForPartialRow() {
        // 25 色 = 5 行（最后一行只 1 个）：5 × 30 + 4 × 8 = 182。
        let layout = KCContentPickerLayout()
        XCTAssertEqual(layout.gridHeight(forColorCount: 25), 182.0)
    }

    func testGridHeightForZeroColorsIsZero() {
        XCTAssertEqual(KCContentPickerLayout().gridHeight(forColorCount: 0), 0.0)
    }

    func testRowColumnMapping() {
        let layout = KCContentPickerLayout() // 6 列
        XCTAssertEqual(layout.rowColumn(forIndex: 0).row, 0)
        XCTAssertEqual(layout.rowColumn(forIndex: 0).column, 0)
        XCTAssertEqual(layout.rowColumn(forIndex: 5).column, 5)
        XCTAssertEqual(layout.rowColumn(forIndex: 6).row, 1)
        XCTAssertEqual(layout.rowColumn(forIndex: 6).column, 0)
        XCTAssertEqual(layout.rowColumn(forIndex: 13).row, 2)
        XCTAssertEqual(layout.rowColumn(forIndex: 13).column, 1)
    }

    func testColumnsClampedToOne() {
        let layout = KCContentPickerLayout(columns: 0)
        XCTAssertEqual(layout.columns, 1)
    }
}
