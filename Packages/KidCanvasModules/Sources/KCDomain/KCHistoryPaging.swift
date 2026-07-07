//
//  KCHistoryPaging.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/26.
//

import Foundation

/// 纯净、不依赖 UIKit 的已保存作品历史分页模型——历史 Feature
/// （`KCHistoryFeature`）抽出的第一个边界。
///
/// 此前 Objective-C 的 `KDMainViewController` 将所有这些分页计算（最大页码、
/// 页码钳制、缩略图→会话索引映射）都内联其中。这里将其原样提取出来，以便
/// 进行单元测试，并让控制器通过这一带类型的接口与历史 Feature 通信，而不是
/// 把算术散落各处。UIKit 的渲染（缩略图按钮本身）仍留在控制器中；该类型仅
/// 负责导航模型。
public struct KCHistoryPaging: Equatable, Sendable {

    /// 正在分页浏览的已保存会话数量。
    public let sessionCount: Int

    /// 每页的缩略图槽位数量（控制器的 `historyPageSize`，由缩略图按钮数量推导）。
    public let pageSize: Int

    /// 当前可见的页码索引。
    public var pageIndex: Int

    public init(sessionCount: Int, pageSize: Int, pageIndex: Int = 0) {
        self.sessionCount = max(0, sessionCount)
        self.pageSize = pageSize
        self.pageIndex = pageIndex
    }

    /// 有效页大小，绝不低于 1——对应原型在所有做除法处使用的
    /// `MAX(1, historyPageSize)` 保护。
    public var effectivePageSize: Int {
        max(1, pageSize)
    }

    /// 最高的有效页码索引。当没有会话时返回 `0`，对应原型中的
    /// `maxHistoryPageIndex`。
    public var maxPageIndex: Int {
        guard sessionCount > 0 else { return 0 }
        return (sessionCount - 1) / effectivePageSize
    }

    /// `pageIndex` 钳制到 `[0, maxPageIndex]`，对应原型 `refreshHistoryUI` 中的
    /// `MIN(MAX(0, pageIndex), maxPageIndex)`。
    public var clampedPageIndex: Int {
        min(max(0, pageIndex), maxPageIndex)
    }

    /// 用户是否可以向后翻页（下一页）。
    public var canAdvance: Bool {
        pageIndex < maxPageIndex
    }

    /// 用户是否可以向前翻页（上一页）。
    public var canRetreat: Bool {
        pageIndex > 0
    }

    /// 将当前页内的缩略图槽位 `thumbIndex` 映射为其绝对会话索引，对应原型中的
    /// `sessionIndexForHistoryThumbIndex:`（`pageIndex * pageSize + thumbIndex`）。
    public func sessionIndex(forThumb thumbIndex: Int) -> Int {
        pageIndex * effectivePageSize + thumbIndex
    }

    /// 返回相邻页需要预热的会话索引。顺序优先下一页，再上一页；
    /// 当前页已经由 UI 刷新同步消费，不放入预热列表。
    public func adjacentPageSessionIndexes() -> [Int] {
        guard sessionCount > 0 else { return [] }
        let currentPage = clampedPageIndex
        var indexes: [Int] = []

        for page in [currentPage + 1, currentPage - 1] {
            guard page >= 0 && page <= maxPageIndex else { continue }
            let startIndex = page * effectivePageSize
            let endIndex = min(startIndex + effectivePageSize, sessionCount)
            guard startIndex < endIndex else { continue }
            indexes.append(contentsOf: startIndex..<endIndex)
        }

        return indexes
    }
}
