//
//  KCRecentColorQueue.swift
//  KCDomain
//
//  Created by 小大 on 2026/07/02.
//

import Foundation

/// 不依赖 UIKit 的「最近使用颜色」队列模型——内容选择 Feature
/// （`KCContentPickerFeature`）抽出的纯逻辑边界。
///
/// 此前 `KCMainViewController.addRecentColor(_:)` 把「先移除已有同色、再插到
/// 队首、再裁剪到上限 8」的内联逻辑散落其中。这里将其抽为纯函数，便于单测。
/// 该类型不感知 `UIColor`：相等判定由调用方通过 `areEqual` 闭包提供，
/// 从而让本模型在测试里可用任意 `Equatable` 类型驱动。
public enum KCRecentColorQueue {

    /// 默认保留的最近颜色数量，对应原型 `while recentColors.count > 8`。
    public static let defaultLimit: Int = 8

    /// 把 `item` 插入 `queue` 队首：先按 `areEqual` 移除已有的等价项，再插到最前，
    /// 再裁剪到不超过 `limit`。`item` 为 `nil` 时原样返回 `queue`（对应原型早返回）。
    public static func inserting<T>(
        _ item: T?,
        into queue: [T],
        limit: Int = defaultLimit,
        areEqual: (T, T) -> Bool
    ) -> [T] {
        guard let item else { return queue }
        var result = queue.filter { !areEqual($0, item) }
        result.insert(item, at: 0)
        let safeLimit = max(0, limit)
        if result.count > safeLimit {
            result.removeLast(result.count - safeLimit)
        }
        return result
    }
}
