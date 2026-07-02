//
//  KCEditorPanelsFeature.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/02.
//

import UIKit
import CoreGraphics
import KCDomain

/// App 层编辑器面板 Feature：集中持有浮动工具面板「收起/展开」状态，
/// 以及折叠态最小工具芯片的色块决策，是从 `KCMainViewController` 抽出的编辑器面板
/// 边界（T023）。纯折叠态决策委托给 KCDomain `KCEditorPanelsCollapseState`，便于
/// `swift test` 单测；本类型只承担与 UIKit/`UIColor` 相关的状态持有与胶水。
///
/// UIKit 的浮动面板创建、约束、折叠动画，以及工具/画笔/颜色的事件协调仍留在控制器；
/// 工具芯片标题已由 T017 的 `KCToolStateChipTitle` 承担，本 Feature 只补色块决策。
final class KCEditorPanelsFeature {

    /// 当前是否处于面板收起态。
    private(set) var panelsCollapsed: Bool = false

    /// 当前折叠态的纯决策模型（图标/标签/各视图 alpha·hidden·enabled）。
    var collapseState: KCEditorPanelsCollapseState {
        KCEditorPanelsCollapseState(isCollapsed: panelsCollapsed)
    }

    /// 翻转收起态并返回新的折叠决策模型。
    @discardableResult
    func toggleCollapsed() -> KCEditorPanelsCollapseState {
        panelsCollapsed.toggle()
        return collapseState
    }

    /// 折叠态工具芯片的色块颜色：橡皮=白、贴纸=黄、其余=当前色（缺省原型红）。
    func chipSwatchColor(toolMode: KDToolMode, currentColor: UIColor?) -> UIColor {
        switch toolMode {
        case .eraser:
            return UIColor(white: 1.0, alpha: 1.0)
        case .sticker:
            return UIColor(red: 0.96, green: 0.85, blue: 0.48, alpha: 1.0)
        default:
            return currentColor ?? UIColor(red: 0.94, green: 0.43, blue: 0.45, alpha: 1.0)
        }
    }
}
