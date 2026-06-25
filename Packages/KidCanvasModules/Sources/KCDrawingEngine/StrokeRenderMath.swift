import Foundation
import KCDomain

/// Pure rendering math for a stroke, ported from
/// `-[KDDrawingCanvasView drawStroke:]`.
///
/// Capturing the brush-specific width/alpha formulas here makes the canvas
/// rendering deterministic and unit-testable, decoupled from the eventual UIKit
/// drawing surface. (The pencil soft-outline and crayon grain texture are
/// applied on top during rasterization and remain a follow-up.)
public enum StrokeRenderMath {
    /// Resolved rendering parameters for a stroke.
    public struct Metrics: Equatable, Sendable {
        public var renderedLineWidth: Double
        public var alpha: Double
    }

    /// Returns the rendered line width and alpha for `stroke`, applying the
    /// prototype's per-brush formulas and the `max(1.0, width)` floor.
    ///
    /// Eraser strokes render fully opaque (alpha 1.0) at pressure 1.0 regardless
    /// of accumulated samples. The caller typically overrides pressure for eraser
    /// in the drawing code, so this method reads `stroke.averagePressure` directly.
    public static func metrics(for stroke: Stroke) -> Metrics {
        let isEraser = stroke.toolMode == .eraser
        let pressure = isEraser ? 1.0 : stroke.averagePressure
        return renderedMetrics(
            brushStyle: stroke.brushStyle,
            lineWidth: stroke.lineWidth,
            pressure: pressure
        )
    }

    /// Primitive brush metrics from raw values — the core formula, decoupled
    /// from the `Stroke` model. Use this from the ObjC bridge where the caller
    /// has already resolved eraser pressure in the drawing code.
    ///
    /// The prototype's per-brush formulas:
    /// - **Pencil**: alpha = `min(0.92, 0.62 + pressure × 0.18)`;
    ///   width = `lineWidth × 0.9 × pressure`
    /// - **Pen**: alpha = `1.0`; width = `lineWidth × 0.72 × min(1.18, max(0.88, pressure))`
    /// - **Crayon**: alpha = `min(0.92, 0.58 + pressure × 0.20)`;
    ///   width = `lineWidth × 1.12 × pressure`
    ///
    /// Returned width is floored at 1.0, matching the prototype's `MAX(1.0, …)`.
    public static func renderedMetrics(
        brushStyle: BrushStyle,
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

    /// The configured width an eraser stroke receives when it begins drawing,
    /// matching the prototype's `MAX(16.0, currentLineWidth * 1.35)`.
    public static func eraserConfiguredWidth(from baseWidth: Double) -> Double {
        max(16.0, baseWidth * 1.35)
    }
}
