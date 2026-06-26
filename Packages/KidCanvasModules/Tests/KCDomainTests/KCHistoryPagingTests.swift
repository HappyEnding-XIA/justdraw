//
//  KCHistoryPagingTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/06/26.
//

import XCTest
@testable import KCDomain

final class HistoryPagingTests: XCTestCase {

    func testMaxPageIndexIsZeroWhenNoSessions() {
        let paging = KCHistoryPaging(sessionCount: 0, pageSize: 6)
        XCTAssertEqual(paging.maxPageIndex, 0)
    }

    func testMaxPageIndexFitsExactPageBoundary() {
        // 12 个会话，每页 6 个 → 第 0、1 页正好填满 → 最大索引 1。
        let paging = KCHistoryPaging(sessionCount: 12, pageSize: 6)
        XCTAssertEqual(paging.maxPageIndex, 1)
    }

    func testMaxPageIndexRoundsUpForPartialLastPage() {
        // 13 个会话，每页 6 个 → 第 0、1 页填满 + 第 2 页有 1 个 → 最大索引 2。
        let paging = KCHistoryPaging(sessionCount: 13, pageSize: 6)
        XCTAssertEqual(paging.maxPageIndex, 2)
    }

    func testMaxPageIndexTreatsZeroPageSizeAsOne() {
        // 退化的页大小 0 不得除以零；视为 1 → 5 页。
        let paging = KCHistoryPaging(sessionCount: 5, pageSize: 0)
        XCTAssertEqual(paging.maxPageIndex, 4)
    }

    func testClampedPageIndexPullsOutOfRangeBackIn() {
        var paging = KCHistoryPaging(sessionCount: 13, pageSize: 6, pageIndex: 99)
        XCTAssertEqual(paging.clampedPageIndex, 2)
        paging.pageIndex = -3
        XCTAssertEqual(paging.clampedPageIndex, 0)
    }

    func testClampedPageIndexLeavesInboundIndexUnchanged() {
        let paging = KCHistoryPaging(sessionCount: 13, pageSize: 6, pageIndex: 1)
        XCTAssertEqual(paging.clampedPageIndex, 1)
    }

    func testCanAdvanceAndCanRetreatBoundaries() {
        let paging5 = KCHistoryPaging(sessionCount: 13, pageSize: 6, pageIndex: 2)
        XCTAssertTrue(paging5.canRetreat)
        XCTAssertFalse(paging5.canAdvance) // 处于最大页

        let paging0 = KCHistoryPaging(sessionCount: 13, pageSize: 6, pageIndex: 0)
        XCTAssertFalse(paging0.canRetreat)
        XCTAssertTrue(paging0.canAdvance)
    }

    func testSessionIndexForThumbCombinesPageAndOffset() {
        // 第 2 页 × 每页 6 + 缩略图 4 → 会话索引 16。
        let paging = KCHistoryPaging(sessionCount: 50, pageSize: 6, pageIndex: 2)
        XCTAssertEqual(paging.sessionIndex(forThumb: 4), 16)
    }

    func testSessionIndexForThumbUsesEffectivePageSizeWhenZero() {
        // 页大小 0 → 有效 1；第 3 页 × 1 + 缩略图 0 → 3。
        let paging = KCHistoryPaging(sessionCount: 50, pageSize: 0, pageIndex: 3)
        XCTAssertEqual(paging.sessionIndex(forThumb: 0), 3)
    }
}
