//
//  KCStrokeRenderMath.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCDomain

/// 笔画的纯渲染数学运算，移植自 `-[KDDrawingCanvasView drawStroke:]`。
///
/// 将各画笔特定的宽度/透明度公式集中在此，可使画布渲染具备确定性且可单元测试，
/// 与最终的 UIKit 绘制表面解耦。铅笔柔边、钢笔端点和蜡笔颗粒纹理在 UIKit
/// 光栅化阶段叠加，本类型只负责可测试的基础宽度/透明度差异。
public enum KCStrokeRenderMath {
    /// 笔画解析后的渲染参数。
    public struct Metrics: Equatable, Sendable {
        public var renderedLineWidth: Double
        public var alpha: Double
    }

    /// 画笔质感叠加层。
    public struct TextureLayer: Equatable, Sendable {
        /// 质感层类型，供 UIKit 光栅化侧按语义分组绘制。
        public enum Kind: String, Sendable {
            case softHalo
            case sketchLine
            case waxSmear
        }

        public var kind: Kind
        public var widthMultiplier: Double
        public var alpha: Double
        public var offsetX: Double
        public var offsetY: Double
        /// 断续纹理的 dash 长度系数，UIKit 层会按当前渲染线宽换算成点。
        public var dashPatternMultipliers: [Double]
        /// 断续纹理的 dash phase 系数，UIKit 层会按当前渲染线宽换算成点。
        public var dashPhaseMultiplier: Double

        public init(
            kind: Kind,
            widthMultiplier: Double,
            alpha: Double,
            offsetX: Double = 0.0,
            offsetY: Double = 0.0,
            dashPatternMultipliers: [Double] = [],
            dashPhaseMultiplier: Double = 0.0
        ) {
            self.kind = kind
            self.widthMultiplier = widthMultiplier
            self.alpha = alpha
            self.offsetX = offsetX
            self.offsetY = offsetY
            self.dashPatternMultipliers = dashPatternMultipliers
            self.dashPhaseMultiplier = dashPhaseMultiplier
        }
    }

    /// 单个画笔在渲染层需要消费的完整视觉配置。
    public struct RenderProfile: Equatable, Sendable {
        public var metrics: Metrics
        public var usesButtLineCap: Bool
        public var textureLayers: [TextureLayer]
        public var grainAlpha: Double
        public var grainClipWidthMultiplier: Double

        public init(
            metrics: Metrics,
            usesButtLineCap: Bool,
            textureLayers: [TextureLayer],
            grainAlpha: Double,
            grainClipWidthMultiplier: Double
        ) {
            self.metrics = metrics
            self.usesButtLineCap = usesButtLineCap
            self.textureLayers = textureLayers
            self.grainAlpha = grainAlpha
            self.grainClipWidthMultiplier = grainClipWidthMultiplier
        }
    }

    /// 返回 `stroke` 的渲染线宽和透明度，应用原型的各画笔公式以及
    /// `max(1.0, width)` 下限。
    ///
    /// 橡皮擦笔画使用自己的配置宽度，渲染为完全不透明（透明度 1.0），
    /// 不再受当前画笔类型的质感公式影响。
    public static func metrics(for stroke: KCStroke) -> Metrics {
        if stroke.toolMode == .eraser {
            return Metrics(renderedLineWidth: max(1.0, stroke.lineWidth), alpha: 1.0)
        }

        return renderedMetrics(
            brushStyle: stroke.brushStyle,
            lineWidth: stroke.lineWidth,
            pressure: stroke.averagePressure
        )
    }

    /// 从原始值计算画笔基础度量——核心公式，与 `KCStroke` 模型解耦。
    /// 仅用于画笔质感计算；橡皮擦应通过 `metrics(for:)` 走独立分支。
    ///
    /// 当前产品化后的画笔公式：
    /// - **Pencil**：更轻、更淡，交给 UIKit 层叠加柔边和草稿感纹理。
    /// - **Pen**：保持完全不透明，宽度接近用户设置，交给 UIKit 层绘制利落端点。
    /// - **Crayon**：更厚、更饱和，交给 UIKit 层叠加蜡笔偏移纹理和颗粒。
    ///
    /// 返回的宽度以 1.0 为下限，与原型的 `MAX(1.0, …)` 一致。
    public static func renderedMetrics(
        brushStyle: KCBrushStyle,
        lineWidth: Double,
        pressure: Double
    ) -> Metrics {
        var alpha: Double = 1.0
        var renderedLineWidth: Double = lineWidth

        switch brushStyle {
        case .pencil:
            alpha = min(0.30, 0.14 + pressure * 0.12)
            renderedLineWidth = lineWidth * 0.32 * pressure
        case .pen:
            alpha = 1.0
            renderedLineWidth = lineWidth * 0.92 * min(1.08, max(0.94, pressure))
        case .crayon:
            alpha = min(0.18, 0.06 + pressure * 0.10)
            renderedLineWidth = lineWidth * 1.28 * pressure
        }

        return Metrics(renderedLineWidth: max(1.0, renderedLineWidth), alpha: alpha)
    }

    /// 返回画笔完整视觉配置。UIKit 层根据该配置绘制基础笔画、端点和质感层。
    public static func renderProfile(
        brushStyle: KCBrushStyle,
        lineWidth: Double,
        pressure: Double
    ) -> RenderProfile {
        let metrics = renderedMetrics(
            brushStyle: brushStyle,
            lineWidth: lineWidth,
            pressure: pressure
        )

        switch brushStyle {
        case .pencil:
            return RenderProfile(
                metrics: metrics,
                usesButtLineCap: false,
                textureLayers: [
                    TextureLayer(kind: .softHalo, widthMultiplier: 2.30, alpha: 0.05),
                    TextureLayer(kind: .sketchLine, widthMultiplier: 0.46, alpha: 0.40, offsetX: -1.45, offsetY: 0.78, dashPatternMultipliers: [0.92, 0.38, 0.36, 0.30]),
                    TextureLayer(kind: .sketchLine, widthMultiplier: 0.34, alpha: 0.34, offsetX: 1.18, offsetY: -0.76, dashPatternMultipliers: [0.76, 0.30, 0.32, 0.26], dashPhaseMultiplier: 0.22),
                    TextureLayer(kind: .sketchLine, widthMultiplier: 0.25, alpha: 0.30, offsetX: 0.44, offsetY: 1.34, dashPatternMultipliers: [0.60, 0.26, 0.28, 0.24], dashPhaseMultiplier: 0.45),
                    TextureLayer(kind: .sketchLine, widthMultiplier: 0.18, alpha: 0.28, offsetX: -0.72, offsetY: -1.26, dashPatternMultipliers: [0.48, 0.22, 0.24, 0.20], dashPhaseMultiplier: 0.64)
                ],
                grainAlpha: 0.0,
                grainClipWidthMultiplier: 0.0
            )
        case .pen:
            return RenderProfile(
                metrics: metrics,
                usesButtLineCap: true,
                textureLayers: [],
                grainAlpha: 0.0,
                grainClipWidthMultiplier: 0.0
            )
        case .crayon:
            return RenderProfile(
                metrics: metrics,
                usesButtLineCap: false,
                textureLayers: [
                    TextureLayer(kind: .waxSmear, widthMultiplier: 1.70, alpha: 0.28, offsetX: -1.8, offsetY: 0.9, dashPatternMultipliers: [0.66, 0.40, 0.54, 0.46]),
                    TextureLayer(kind: .waxSmear, widthMultiplier: 1.22, alpha: 0.40, offsetX: -3.6, offsetY: 2.1, dashPatternMultipliers: [0.58, 0.26, 0.42, 0.38], dashPhaseMultiplier: 0.16),
                    TextureLayer(kind: .waxSmear, widthMultiplier: 0.92, alpha: 0.42, offsetX: 3.2, offsetY: -2.3, dashPatternMultipliers: [0.48, 0.22, 0.34, 0.30], dashPhaseMultiplier: 0.34),
                    TextureLayer(kind: .waxSmear, widthMultiplier: 0.68, alpha: 0.36, offsetX: -2.0, offsetY: -3.2, dashPatternMultipliers: [0.38, 0.18, 0.28, 0.26], dashPhaseMultiplier: 0.54),
                    TextureLayer(kind: .waxSmear, widthMultiplier: 0.44, alpha: 0.34, offsetX: 2.3, offsetY: 3.1, dashPatternMultipliers: [0.30, 0.14, 0.22, 0.24], dashPhaseMultiplier: 0.70),
                    TextureLayer(kind: .waxSmear, widthMultiplier: 0.26, alpha: 0.32, offsetX: -3.9, offsetY: -0.8, dashPatternMultipliers: [0.22, 0.12, 0.16, 0.18], dashPhaseMultiplier: 0.82)
                ],
                grainAlpha: 0.94,
                grainClipWidthMultiplier: 1.72
            )
        }
    }

    /// 橡皮擦笔画开始绘制时所获得的配置宽度，与原型的
    /// `MAX(16.0, currentLineWidth * 1.35)` 一致。
    public static func eraserConfiguredWidth(from baseWidth: Double) -> Double {
        max(16.0, baseWidth * 1.35)
    }
}
