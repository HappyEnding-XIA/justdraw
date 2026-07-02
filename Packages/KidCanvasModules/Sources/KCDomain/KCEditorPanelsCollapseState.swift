//
//  KCEditorPanelsCollapseState.swift
//  KCDomain
//
//  Created by 小大 on 2026/07/02.
//

import Foundation
import CoreGraphics

/// 不依赖 UIKit 的「浮动工具面板折叠」状态模型——编辑器面板 Feature
/// （`KCEditorPanelsFeature`）抽出的纯决策边界。
///
/// 此前 `KCMainViewController.applyPanelsCollapsedAnimated(_:)` 把收起/展开时
/// 切换按钮图标、无障碍标签、各面板 alpha/hidden/userInteractionEnabled、
/// 工具状态芯片 alpha/hidden 的 ternary 决策散落在动画代码里。这里将其集中为
/// 纯值，便于单测；UIKit 的动画与视图应用仍留控制器，该类型只负责「折叠态下
/// 各视图该是什么样」的决策。
public struct KCEditorPanelsCollapseState: Equatable, Sendable {

    /// 是否处于收起态。
    public let isCollapsed: Bool

    public init(isCollapsed: Bool) {
        self.isCollapsed = isCollapsed
    }

    /// 收起切换按钮的 SF Symbol 名称（收起时显示「展开」图标）。
    public var toggleIconName: String {
        isCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical"
    }

    /// 收起切换按钮的无障碍标签（收起时提示「展开」）。
    public var toggleAccessibilityLabel: String {
        isCollapsed ? "Show Tools" : "Hide Tools"
    }

    /// 浮动面板的 alpha（收起时透明）。
    public var panelAlpha: CGFloat {
        isCollapsed ? 0.0 : 1.0
    }

    /// 浮动面板是否隐藏（收起时隐藏，动画完成后生效）。
    public var panelIsHidden: Bool {
        isCollapsed
    }

    /// 浮动面板是否可交互（收起时禁用，立即生效以防拦截画布触摸）。
    public var panelIsUserInteractionEnabled: Bool {
        !isCollapsed
    }

    /// 工具状态芯片的 alpha（仅收起时可见）。
    public var chipAlpha: CGFloat {
        isCollapsed ? 1.0 : 0.0
    }

    /// 工具状态芯片是否隐藏（展开时隐藏）。
    public var chipIsHidden: Bool {
        !isCollapsed
    }
}
