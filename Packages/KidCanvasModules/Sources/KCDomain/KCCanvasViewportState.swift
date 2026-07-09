//
//  KCCanvasViewportState.swift
//  KCDomain
//
//  Created by 小大 on 2026/07/09.
//

import Foundation
import CoreGraphics

/// 不依赖 UIKit 的画布视口（viewport）状态模型——画布导航能力（T097）的纯逻辑边界。
///
/// KidCanvas 的画布内容（笔画、底图、印章）统一存储在“内容坐标空间”中，
/// 内容坐标空间的大小即 `contentSize`（等于画布 view 的 `bounds.size`）。
/// 视口只描述“如何把内容坐标投射到屏幕坐标”：先按 `scale` 缩放，再按
/// `translation` 平移，即
///
/// ```
/// 屏幕点 = scale × 内容点 + translation
/// ```
///
/// `viewportRect` 是屏幕坐标下的“安全创作区”（已扣除顶栏、左工具轨、右侧面板、
/// 底部 Dock 的可连续绘制区域）。默认视图把内容中心对齐到安全创作区中心，
/// 而不是整屏几何中心；缩放/平移后 `clampedTranslation` 保证画布不会完全移出
/// 可视区域（缩放后内容大于创作区时不留空隙，小于创作区时居中）。
///
/// 该类型只做几何与坐标转换，不持有 UIKit 类型；真正的双指手势识别、
/// `setNeedsDisplay`、按钮显隐等 UIKit 行为由 App/Canvas 层（画布 view、
/// 主控制器）在拿到本模型结果后执行。
public struct KCCanvasViewportState: Equatable, Sendable {

    /// 最小缩放（对应 PRD 建议下限 50%）。
    public static let minimumScale: CGFloat = 0.5

    /// 最大缩放（对应 PRD 建议上限 300%）。
    public static let maximumScale: CGFloat = 3.0

    /// 内容坐标空间尺寸（点），等于画布 view 的 `bounds.size`。
    public var contentSize: CGSize

    /// 屏幕坐标下的安全创作区矩形（已扣除浮动面板遮挡区域）。
    public var viewportRect: CGRect

    /// 当前缩放系数，构造与变更时都会被钳制到 `[minimumScale, maximumScale]`。
    public var scale: CGFloat

    /// 当前平移（屏幕点）：`屏幕点 = scale × 内容点 + translation`。
    public var translation: CGPoint

    /// 构造一个视口状态。`scale` 与 `translation` 默认为默认视图对应值之外的安全值，
    /// 由调用方在 layout 后显式调用 `defaultState` / `resettingToDefault()` 进入默认视图。
    public init(
        contentSize: CGSize,
        viewportRect: CGRect,
        scale: CGFloat = 1.0,
        translation: CGPoint = .zero
    ) {
        self.contentSize = contentSize
        self.viewportRect = viewportRect
        self.scale = Self.clampedScale(scale)
        self.translation = translation
    }

    /// 把缩放系数钳制到 `[minimumScale, maximumScale]`。
    public static func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(maximumScale, max(minimumScale, scale))
    }

    /// 内容坐标空间的中心点。
    public var contentCenter: CGPoint {
        CGPoint(x: contentSize.width / 2.0, y: contentSize.height / 2.0)
    }

    /// 在给定缩放下，把内容中心对齐到安全创作区中心所需的平移量。
    public func defaultTranslation(forScale scale: CGFloat) -> CGPoint {
        CGPoint(
            x: viewportRect.midX - contentCenter.x * scale,
            y: viewportRect.midY - contentCenter.y * scale
        )
    }

    /// 当前缩放下居中所需的平移量。
    public var defaultTranslation: CGPoint {
        defaultTranslation(forScale: scale)
    }

    /// 默认视图：缩放回到 1.0、平移把内容中心对齐安全创作区中心。
    public var defaultState: KCCanvasViewportState {
        var state = self
        state.scale = 1.0
        state.translation = defaultTranslation(forScale: 1.0)
        return state
    }

    /// 回到默认视图（语义等价于 `defaultState`，命名更贴近调用方“重置”意图）。
    public func resettingToDefault() -> KCCanvasViewportState {
        defaultState
    }

    /// 当前是否处于默认视图：缩放为 1 且平移与默认平移在亚像素容差内一致。
    public var isDefault: Bool {
        let expected = defaultTranslation(forScale: 1.0)
        return abs(scale - 1.0) < 0.001
            && abs(translation.x - expected.x) < 0.5
            && abs(translation.y - expected.y) < 0.5
    }

    /// 缩放后的内容尺寸（点）。
    public var scaledContentSize: CGSize {
        CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
    }

    /// 内容坐标到屏幕坐标的仿射变换：`屏幕点 = scale × 内容点 + translation`。
    /// 用显式矩阵构造，避免 `concatenating` / `scaledBy` 的合成顺序歧义。
    public var affineTransform: CGAffineTransform {
        CGAffineTransform(
            a: scale, b: 0.0,
            c: 0.0, d: scale,
            tx: translation.x, ty: translation.y
        )
    }

    /// 屏幕坐标 → 内容坐标。`scale` 为 0 时原样返回（防御退化输入）。
    public func canvasPoint(forViewPoint point: CGPoint) -> CGPoint {
        guard scale != 0.0 else { return point }
        return CGPoint(
            x: (point.x - translation.x) / scale,
            y: (point.y - translation.y) / scale
        )
    }

    /// 内容坐标 → 屏幕坐标。
    public func viewPoint(forCanvasPoint point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * scale + translation.x,
            y: point.y * scale + translation.y
        )
    }

    /// 把当前平移量按“画布不能完全移出可视区”的规则钳制。
    ///
    /// 单轴规则（x、y 各自独立）：
    /// - 缩放后内容小于创作区：居中，内容完全可见；
    /// - 缩放后内容大于创作区：平移范围限定为 `[viewportMax - 内容尺寸, viewportMin]`，
    ///   保证创作区始终被内容覆盖、不留空隙（等价于 UIScrollView 在内容大于可见区时的边界）。
    public func clampedTranslation(forScale scale: CGFloat) -> CGPoint {
        guard !viewportRect.isEmpty,
              contentSize.width > 0.0, contentSize.height > 0.0 else {
            return translation
        }
        return CGPoint(
            x: Self.clamp(
                translation.x,
                contentExtent: contentSize.width * scale,
                viewportMin: viewportRect.minX,
                viewportMax: viewportRect.maxX
            ),
            y: Self.clamp(
                translation.y,
                contentExtent: contentSize.height * scale,
                viewportMin: viewportRect.minY,
                viewportMax: viewportRect.maxY
            )
        )
    }

    /// 当前缩放下的钳制平移量。
    public var clampedTranslation: CGPoint {
        clampedTranslation(forScale: scale)
    }

    /// 返回平移与缩放均已钳制后的状态。
    public var clamped: KCCanvasViewportState {
        var state = self
        state.translation = clampedTranslation(forScale: state.scale)
        return state
    }

    /// 围绕屏幕焦点 `focus` 缩放 `scaleMultiplier` 倍，并返回钳制后的新状态。
    ///
    /// 缩放保持“焦点下的内容点不动”：先用旧视口算出焦点对应的内容点，
    /// 再反解出新的平移量，使该内容点在新缩放下仍位于焦点。最后做平移钳制，
    /// 钳制在边缘附近可能让焦点产生亚像素级偏移（与 UIScrollView 边界行为一致）。
    public func applyingScale(_ scaleMultiplier: CGFloat, aroundViewPoint focus: CGPoint) -> KCCanvasViewportState {
        let newScale = Self.clampedScale(scale * scaleMultiplier)
        guard newScale > 0.0 else { return self }
        let canvasFocus = canvasPoint(forViewPoint: focus)
        let newTranslation = CGPoint(
            x: focus.x - newScale * canvasFocus.x,
            y: focus.y - newScale * canvasFocus.y
        )
        var state = self
        state.scale = newScale
        state.translation = newTranslation
        return state.clamped
    }

    /// 按屏幕增量 `delta` 平移，并返回钳制后的新状态。
    public func translating(by delta: CGPoint) -> KCCanvasViewportState {
        var state = self
        state.translation = CGPoint(x: translation.x + delta.x, y: translation.y + delta.y)
        return state.clamped
    }

    /// 单轴钳制原语。
    private static func clamp(
        _ translation: CGFloat,
        contentExtent: CGFloat,
        viewportMin: CGFloat,
        viewportMax: CGFloat
    ) -> CGFloat {
        let viewportExtent = viewportMax - viewportMin
        if contentExtent <= viewportExtent {
            // 内容小于等于创作区：把内容中心对齐到创作区中心。
            return (viewportMin + viewportMax) / 2.0 - contentExtent / 2.0
        }
        // 内容大于创作区：平移范围限定为 [viewportMax - 内容尺寸, viewportMin]，
        // 保证创作区始终被内容完全覆盖，画布边缘不会拖出空隙。
        let lowerBound = viewportMax - contentExtent
        let upperBound = viewportMin
        return min(upperBound, max(lowerBound, translation))
    }
}
