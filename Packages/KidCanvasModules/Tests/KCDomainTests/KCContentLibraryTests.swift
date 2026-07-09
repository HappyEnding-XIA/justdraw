//
//  KCContentLibraryTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/07/09.
//

import XCTest
@testable import KCDomain

final class KCContentLibraryTests: XCTestCase {

    // MARK: - 分区能力

    func testAllPartitionsAllowOpen() {
        for partition in KCContentLibraryPartition.defaultOrder {
            XCTAssertTrue(partition.allowsOpen, "\(partition) 应支持打开")
        }
    }

    func testOfficialLineArtIsNotDeletable() {
        XCTAssertFalse(KCContentLibraryPartition.officialLineArt.allowsDelete,
                       "官方线稿不可删除")
    }

    func testMyLineArtAndHistoryAreDeletable() {
        XCTAssertTrue(KCContentLibraryPartition.myLineArt.allowsDelete)
        XCTAssertTrue(KCContentLibraryPartition.history.allowsDelete)
    }

    // MARK: - 分区顺序与稳定标识

    func testDefaultOrderIsOfficialThenMyThenHistory() {
        XCTAssertEqual(KCContentLibraryPartition.defaultOrder,
                       [.officialLineArt, .myLineArt, .history])
    }

    func testPartitionLocalizationKeysAreStable() {
        XCTAssertEqual(KCContentLibraryPartition.officialLineArt.localizationKey,
                       "library.partition.official-line-art")
        XCTAssertEqual(KCContentLibraryPartition.myLineArt.localizationKey,
                       "library.partition.my-line-art")
        XCTAssertEqual(KCContentLibraryPartition.history.localizationKey,
                       "library.partition.history")
    }

    // MARK: - 分区展示状态

    func testSectionStateEmptyWhenItemCountZero() {
        let state = KCContentLibrarySectionState(partition: .history, itemCount: 0)
        XCTAssertTrue(state.isEmpty)
    }

    func testSectionStateNonEmptyWhenItemCountPositive() {
        let state = KCContentLibrarySectionState(partition: .history, itemCount: 3)
        XCTAssertFalse(state.isEmpty)
    }

    func testCanDeleteAnyRequiresDeletablePartitionAndNonEmpty() {
        // 官方线稿：即便非空也不可删除。
        XCTAssertFalse(KCContentLibrarySectionState(partition: .officialLineArt, itemCount: 5).canDeleteAny)
        // 历史：空态不可删除。
        XCTAssertFalse(KCContentLibrarySectionState(partition: .history, itemCount: 0).canDeleteAny)
        // 历史：非空可删除。
        XCTAssertTrue(KCContentLibrarySectionState(partition: .history, itemCount: 2).canDeleteAny)
        // 我的线稿：非空可删除。
        XCTAssertTrue(KCContentLibrarySectionState(partition: .myLineArt, itemCount: 1).canDeleteAny)
    }

    func testNegativeItemCountClampedToZero() {
        XCTAssertEqual(KCContentLibrarySectionState(partition: .history, itemCount: -3).itemCount, 0)
    }

    func testEmptyStateLocalizationKeysAreStable() {
        XCTAssertEqual(KCContentLibrarySectionState(partition: .officialLineArt, itemCount: 0).emptyStateLocalizationKey,
                       "library.empty.official-line-art")
        XCTAssertEqual(KCContentLibrarySectionState(partition: .myLineArt, itemCount: 0).emptyStateLocalizationKey,
                       "library.empty.my-line-art")
        XCTAssertEqual(KCContentLibrarySectionState(partition: .history, itemCount: 0).emptyStateLocalizationKey,
                       "library.empty.history")
    }
}
