//
//  KCHistoryThumbStatusTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/07/02.
//

import XCTest
@testable import KCDomain

final class KCHistoryThumbStatusTests: XCTestCase {

    func testStatusDerivationPrecedence() {
        // 优先级：空 > 脏 > 选中 > 当前 > 普通。
        XCTAssertEqual(KCHistoryThumbStatus.status(isActive: false, isSelected: false, isDirtyActive: false, isEmpty: true), .empty)
        // 即使同时是当前/选中/脏，只要空就判定空。
        XCTAssertEqual(KCHistoryThumbStatus.status(isActive: true, isSelected: true, isDirtyActive: true, isEmpty: true), .empty)
        XCTAssertEqual(KCHistoryThumbStatus.status(isActive: true, isSelected: true, isDirtyActive: true, isEmpty: false), .dirtyActive)
        XCTAssertEqual(KCHistoryThumbStatus.status(isActive: true, isSelected: true, isDirtyActive: false, isEmpty: false), .selected)
        XCTAssertEqual(KCHistoryThumbStatus.status(isActive: true, isSelected: false, isDirtyActive: false, isEmpty: false), .active)
        XCTAssertEqual(KCHistoryThumbStatus.status(isActive: false, isSelected: false, isDirtyActive: false, isEmpty: false), .normal)
    }

    func testBorderWidth() {
        XCTAssertEqual(KCHistoryThumbStatus.dirtyActive.borderWidth, 3.0)
        XCTAssertEqual(KCHistoryThumbStatus.active.borderWidth, 2.0)
        XCTAssertEqual(KCHistoryThumbStatus.selected.borderWidth, 2.0)
        XCTAssertEqual(KCHistoryThumbStatus.normal.borderWidth, 2.0)
        XCTAssertEqual(KCHistoryThumbStatus.empty.borderWidth, 2.0)
    }

    func testEmphasis() {
        XCTAssertTrue(KCHistoryThumbStatus.active.isEmphasized)
        XCTAssertTrue(KCHistoryThumbStatus.selected.isEmphasized)
        XCTAssertTrue(KCHistoryThumbStatus.dirtyActive.isEmphasized)
        XCTAssertFalse(KCHistoryThumbStatus.normal.isEmphasized)
        XCTAssertFalse(KCHistoryThumbStatus.empty.isEmphasized)
    }

    func testEmphasisScale() {
        XCTAssertEqual(KCHistoryThumbStatus.dirtyActive.emphasisScale, 1.05)
        XCTAssertEqual(KCHistoryThumbStatus.active.emphasisScale, 1.03)
        XCTAssertEqual(KCHistoryThumbStatus.selected.emphasisScale, 1.03)
        XCTAssertEqual(KCHistoryThumbStatus.normal.emphasisScale, 1.0)
        XCTAssertEqual(KCHistoryThumbStatus.empty.emphasisScale, 1.0)
    }

    func testAccessibilityPrefixes() {
        XCTAssertEqual(KCHistoryThumbStatus.empty.accessibilityPrefix, "Empty Saved Thumbnail")
        XCTAssertEqual(KCHistoryThumbStatus.dirtyActive.accessibilityPrefix, "Unsaved Saved Thumbnail")
        XCTAssertEqual(KCHistoryThumbStatus.selected.accessibilityPrefix, "Selected Saved Thumbnail")
        XCTAssertEqual(KCHistoryThumbStatus.active.accessibilityPrefix, "Saved Thumbnail")
        XCTAssertEqual(KCHistoryThumbStatus.normal.accessibilityPrefix, "Saved Thumbnail")
    }
}
