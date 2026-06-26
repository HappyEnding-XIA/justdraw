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
/// 与最终的 UIKit 绘制表面解耦。（铅笔柔边轮廓和蜡笔颗粒纹理在光栅化阶段叠加，
/// 属于后续待办项。）
public enum KCStrokeRenderMath {
    /// 笔画解析后的渲染参数。
    public struct Metrics: Equatable, Sendable {
        public var renderedLineWidth: Double
        public var alpha: Double
    }

    /// 返回 `stroke` 的渲染线宽和透明度，应用原型的各画笔公式以及
    /// `max(1.0, width)` 下限。
    ///
    /// 橡皮擦笔画以压力 1.0 渲染为完全不透明（透明度 1.0），无论累积采样如何。
    /// 调用方通常会在绘制代码中覆盖橡皮擦的压力，因此本方法直接读取
    /// `stroke.averagePressure`。
    public static func metrics(for stroke: KCStroke) -> Metrics {
        let isEraser = stroke.toolMode == .eraser
        let pressure = isEraser ? 1.0 : stroke.averagePressure
        return renderedMetrics(
            brushStyle: stroke.brushStyle,
            lineWidth: stroke.lineWidth,
            pressure: pressure
        )
    }

    /// 从原始值计算画笔基础度量——核心公式，与 `KCStroke` 模型解耦。
    /// 供 ObjC bridge 调用，此时调用方已在绘制代码中确定了橡皮擦压力。
    ///
    /// 原型的各画笔公式：
    /// - **Pencil**：alpha = `min(0.92, 0.62 + pressure × 0.18)`；
    ///   width = `lineWidth × 0.9 × pressure`
    /// - **Pen**：alpha = `1.0`；width = `lineWidth × 0.72 × min(1.18, max(0.88, pressure))`
    /// - **Crayon**：alpha = `min(0.92, 0.58 + pressure × 0.20)`；
    ///   width = `lineWidth × 1.12 × pressure`
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
            alpha = min(0.92, 0.62 + pressure * 0.18)
            renderedLineWidth = lineWidth * 0.9 * pressure
        case .pen:
            alpha = 1.0
            renderedLineWidth = lineWidth * 0.72 * min(1.18, max(0.88, pressure))
        case .crayon:
            alpha = min(0.92, 0.58 + pressure * 0.20)
            renderedLineWidth = lineWidth * 1.12 * pressure
        }

        return Metrics(renderedLineWidth: max(1.0, renderedLineWidth), alpha: alpha)
    }

    /// 橡皮擦笔画开始绘制时所获得的配置宽度，与原型的
    /// `MAX(16.0, currentLineWidth * 1.35)` 一致。
    public static func eraserConfiguredWidth(from baseWidth: Double) -> Double {
        max(16.0, baseWidth * 1.35)
    }
}
