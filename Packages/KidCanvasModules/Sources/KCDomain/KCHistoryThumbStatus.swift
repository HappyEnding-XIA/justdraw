//
//  KCHistoryThumbStatus.swift
//  KCDomain
//
//  Created by 小大 on 2026/07/02.
//

import Foundation
import CoreGraphics

/// 不依赖 UIKit 的「历史缩略图槽位状态」模型——历史 Feature
/// （`KCHistoryFeature`）抽出的纯决策边界。
///
/// 此前 `KCMainViewController.refreshHistoryUI()` 把每个历史缩略图槽位的
/// 「空/普通/当前会话/已选中/脏的当前会话」判定，以及对应的边框宽度、强调缩放、
/// 无障碍标签前缀等决策用一连串 if/else 内联在 UIKit 代码里。这里将其集中为
/// 纯值类型，便于单测；`UIColor` 边框色与 transform 的 UIKit 应用仍留控制器。
public enum KCHistoryThumbStatus: Equatable, Sendable {

    /// 槽位没有对应会话（当前页未填满）。
    case empty
    /// 普通已保存会话。
    case normal
    /// 当前正在编辑的会话。
    case active
    /// 用户在历史面板选中的会话。
    case selected
    /// 当前正在编辑且有未保存改动的会话（脏态，视觉警示最强）。
    case dirtyActive

    /// 由槽位语义标志推导状态。判定优先级：空 > 脏的当前 > 选中 > 当前 > 普通。
    public static func status(isActive: Bool, isSelected: Bool, isDirtyActive: Bool, isEmpty: Bool) -> KCHistoryThumbStatus {
        if isEmpty { return .empty }
        if isDirtyActive { return .dirtyActive }
        if isSelected { return .selected }
        if isActive { return .active }
        return .normal
    }

    /// 边框宽度：脏态 3，其余 2（与原型一致）。
    public var borderWidth: CGFloat {
        self == .dirtyActive ? 3.0 : 2.0
    }

    /// 是否需要强调（当前/选中/脏态都强调）。
    public var isEmphasized: Bool {
        switch self {
        case .normal, .empty: return false
        case .active, .selected, .dirtyActive: return true
        }
    }

    /// 强调缩放比例：脏态 1.05、当前/选中 1.03、其余 1.0（无缩放）。
    public var emphasisScale: CGFloat {
        switch self {
        case .dirtyActive: return 1.05
        case .active, .selected: return 1.03
        case .normal, .empty: return 1.0
        }
    }

    /// 无障碍标签前缀；控制器在后面拼接序号（已保存用会话序号，空槽用槽位序号）。
    public var accessibilityPrefix: String {
        switch self {
        case .empty: return "Empty Saved Thumbnail"
        case .dirtyActive: return "Unsaved Saved Thumbnail"
        case .selected: return "Selected Saved Thumbnail"
        case .active, .normal: return "Saved Thumbnail"
        }
    }
}
