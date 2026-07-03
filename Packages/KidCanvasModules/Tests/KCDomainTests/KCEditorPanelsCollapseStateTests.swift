//
//  KCEditorPanelsCollapseStateTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/07/02.
//

import XCTest
@testable import KCDomain

final class KCEditorPanelsCollapseStateTests: XCTestCase {

    func testExpandedStateShowsPanelsAndHidesChip() {
        let state = KCEditorPanelsCollapseState(isCollapsed: false)
        XCTAssertFalse(state.isCollapsed)
        XCTAssertEqual(state.toggleIconName, "rectangle.compress.vertical")
        XCTAssertEqual(state.toggleAccessibilityLabel, "action.hide-tools.title")
        XCTAssertEqual(state.panelAlpha, 1.0)
        XCTAssertFalse(state.panelIsHidden)
        XCTAssertTrue(state.panelIsUserInteractionEnabled)
        XCTAssertEqual(state.chipAlpha, 0.0)
        XCTAssertTrue(state.chipIsHidden)
    }

    func testCollapsedStateHidesPanelsAndShowsChip() {
        let state = KCEditorPanelsCollapseState(isCollapsed: true)
        XCTAssertTrue(state.isCollapsed)
        XCTAssertEqual(state.toggleIconName, "rectangle.expand.vertical")
        XCTAssertEqual(state.toggleAccessibilityLabel, "action.show-tools.title")
        XCTAssertEqual(state.panelAlpha, 0.0)
        XCTAssertTrue(state.panelIsHidden)
        XCTAssertFalse(state.panelIsUserInteractionEnabled)
        XCTAssertEqual(state.chipAlpha, 1.0)
        XCTAssertFalse(state.chipIsHidden)
    }

    func testPanelAndChipVisibilityAreInverse() {
        // 面板与芯片恰有一个隐藏：收起态下面板隐藏+芯片显示，展开态反之，
        // 避免两者同时出现或同时消失。panelIsHidden 与 chipIsHidden 互斥。
        for collapsed in [false, true] {
            let state = KCEditorPanelsCollapseState(isCollapsed: collapsed)
            XCTAssertNotEqual(state.panelIsHidden, state.chipIsHidden)
        }
    }

    func testPanelAlphaAndChipAlphaAreComplementary() {
        // 两者 alpha 互补（和为 1），保证渐变过程中一淡一浓。
        for collapsed in [false, true] {
            let state = KCEditorPanelsCollapseState(isCollapsed: collapsed)
            XCTAssertEqual(state.panelAlpha + state.chipAlpha, 1.0, accuracy: 0.0001)
        }
    }
}
