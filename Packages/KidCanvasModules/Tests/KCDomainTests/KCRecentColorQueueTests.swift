//
//  KCRecentColorQueueTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/07/02.
//

import XCTest
@testable import KCDomain

final class KCRecentColorQueueTests: XCTestCase {

    private func equal(_ a: Int, _ b: Int) -> Bool { a == b }

    func testNilItemReturnsQueueUnchanged() {
        let queue = [1, 2, 3]
        let result = KCRecentColorQueue.inserting(nil, into: queue, areEqual: equal)
        XCTAssertEqual(result, [1, 2, 3])
    }

    func testNewItemInsertedAtFront() {
        let result = KCRecentColorQueue.inserting(9, into: [1, 2, 3], areEqual: equal)
        XCTAssertEqual(result, [9, 1, 2, 3])
    }

    func testExistingItemMovesToFrontAndDedupes() {
        // 已存在的 2 先移除，再插到队首；不重复。
        let result = KCRecentColorQueue.inserting(2, into: [1, 2, 3], areEqual: equal)
        XCTAssertEqual(result, [2, 1, 3])
    }

    func testCapsAtDefaultLimitEight() {
        let queue = Array(1...8)
        // 插入新值 9，应裁剪到 8 个：[9,1,2,3,4,5,6,7]。
        let result = KCRecentColorQueue.inserting(9, into: queue, areEqual: equal)
        XCTAssertEqual(result.count, 8)
        XCTAssertEqual(result, [9, 1, 2, 3, 4, 5, 6, 7])
    }

    func testAtLimitExistingItemKeepsCount() {
        // 已在队列中的项前移，总数仍为上限。
        let queue = Array(1...8)
        let result = KCRecentColorQueue.inserting(5, into: queue, areEqual: equal)
        XCTAssertEqual(result.count, 8)
        XCTAssertEqual(result, [5, 1, 2, 3, 4, 6, 7, 8])
    }

    func testCustomLimitRespected() {
        let result = KCRecentColorQueue.inserting(9, into: [1, 2], limit: 2, areEqual: equal)
        XCTAssertEqual(result, [9, 1])
    }

    func testCustomEqualityPredicateDrivesDedupe() {
        // 用自定义相等闭包驱动去重（模拟 UIColor 等非 Equatable-by-value 类型的场景）。
        let byValue: (Int, Int) -> Bool = { $0 == $1 }
        let queue = [10, 20, 30]
        let result = KCRecentColorQueue.inserting(20, into: queue, areEqual: byValue)
        XCTAssertEqual(result, [20, 10, 30])
    }
}
