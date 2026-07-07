//
//  KCHistoryFeature.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/02.
//

import UIKit
import CoreGraphics
import KCDomain

/// App 层历史 Feature：集中「历史缩略图槽位状态」推导与删除可用性判定，
/// 是从 `KCMainViewController` 抽出的历史展示边界（T024）。分页数学委托 KCDomain
/// `KCHistoryPaging`（T013），槽位状态判定委托 KCDomain `KCHistoryThumbStatus`，
/// 便于 `swift test` 单测；本类型只承担与 UIKit/`UIColor` 相关的胶水。
///
/// 历史会话数据、缩略图按钮构建、翻页/打开/删除的事件协调仍留控制器；本 Feature
/// 不触碰 `KCSessionService`/`KCSessionStore` 的磁盘格式，只读取传入的会话 id 列表
/// 与当前选中/活动状态，给出展示决策。
final class KCHistoryFeature {

    /// 默认（无脏态）下空槽位的边框色，与原型一致。
    static let idleBorderColor = UIColor(red: 0.17, green: 0.22, blue: 0.30, alpha: 0.08)

    /// 推导历史缩略图槽位 `thumbIndex` 在当前页的状态及对应的绝对会话索引。
    /// - Parameters:
    ///   - sessionIds: 全部历史会话 id（按展示顺序），仅取 `.identifier`。
    ///   - pageIndex: 当前历史页码。
    ///   - pageSize: 每页槽位数（缩略图按钮数）。
    ///   - activeSessionId: 当前正在编辑的会话 id（若有）。
    ///   - selectedSessionId: 用户在历史面板选中的会话 id（若有）。
    ///   - isDirtyActive: 当前活动会话是否有未保存改动。
    ///   - thumbIndex: 槽位序号（0…pageSize-1）。
    /// - Returns: 状态与其对应的绝对会话索引（空槽位也会返回推算出的索引）。
    func thumbStatus(
        sessionIds: [String],
        pageIndex: Int,
        pageSize: Int,
        activeSessionId: String?,
        selectedSessionId: String?,
        isDirtyActive: Bool,
        thumbIndex: Int
    ) -> (status: KCHistoryThumbStatus, sessionIndex: Int) {
        let sessionIndex = KCHistoryPaging(
            sessionCount: sessionIds.count, pageSize: pageSize, pageIndex: pageIndex
        ).sessionIndex(forThumb: thumbIndex)
        if sessionIndex >= sessionIds.count {
            return (.empty, sessionIndex)
        }
        let sessionId = sessionIds[sessionIndex]
        let isActive = sessionId == activeSessionId
        let isSelected = sessionId == selectedSessionId
        let isDirty = isActive && isDirtyActive
        let status = KCHistoryThumbStatus.status(
            isActive: isActive, isSelected: isSelected, isDirtyActive: isDirty, isEmpty: false
        )
        return (status, sessionIndex)
    }

    /// 把槽位状态映射为边框色（脏=橙、选中=绿、当前=蓝、其余=中性）。
    func borderColor(for status: KCHistoryThumbStatus) -> UIColor {
        switch status {
        case .dirtyActive:
            return UIColor(red: 0.97, green: 0.70, blue: 0.25, alpha: 0.94)
        case .selected:
            return UIColor(red: 0.50, green: 0.78, blue: 0.56, alpha: 0.90)
        case .active:
            return UIColor(red: 0.45, green: 0.73, blue: 0.97, alpha: 0.82)
        case .normal, .empty:
            return Self.idleBorderColor
        }
    }

    /// 「删除历史」按钮是否可用：有选中会话、或有任意历史、或有草稿时可用（与原型一致）。
    func canDeleteHistory(hasSelectedSession: Bool, sessionCount: Int, hasDraft: Bool) -> Bool {
        hasSelectedSession || sessionCount > 0 || hasDraft
    }
}
