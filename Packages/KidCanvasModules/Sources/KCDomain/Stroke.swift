import Foundation
import CoreGraphics
import KCCommon

/// A single brush or eraser stroke, modeled on the Objective-C `KDStroke`.
///
/// A stroke carries the sampled touch points, the average pressure accumulated
/// while drawing, and the tool/brush/eraser configuration in effect. Pressure is
/// stored as a running sum and count so the rendered width can be recomputed
/// (`averagePressure`) without keeping every sample.
public struct Stroke: Codable, Equatable, Sendable {
    public var toolMode: ToolMode
    public var brushStyle: BrushStyle
    public var eraserShape: EraserShape
    public var color: HexColor
    public var lineWidth: Double

    /// Touch points captured while drawing, in canvas coordinates.
    public var points: [CGPoint]
    /// The first touch location; used for dot (tap) strokes and jitter filtering.
    public var startPoint: CGPoint
    /// `true` when the stroke was a tap that never moved — rendered as a filled dot.
    public var dotStroke: Bool
    /// Running sum of normalized pressure samples (see `PressureModel`).
    public var pressureTotal: Double
    /// Number of pressure samples accumulated in `pressureTotal`.
    public var pressureSampleCount: Int

    public init(
        toolMode: ToolMode,
        brushStyle: BrushStyle,
        eraserShape: EraserShape,
        color: HexColor,
        lineWidth: Double,
        points: [CGPoint] = [],
        startPoint: CGPoint = .zero,
        dotStroke: Bool = false,
        pressureTotal: Double = 0,
        pressureSampleCount: Int = 0
    ) {
        self.toolMode = toolMode
        self.brushStyle = brushStyle
        self.eraserShape = eraserShape
        self.color = color
        self.lineWidth = lineWidth
        self.points = points
        self.startPoint = startPoint
        self.dotStroke = dotStroke
        self.pressureTotal = pressureTotal
        self.pressureSampleCount = pressureSampleCount
    }

    /// Mean normalized pressure, falling back to 1.0 when no samples exist,
    /// matching the prototype's `-[KDStroke averagePressure]`.
    public var averagePressure: Double {
        pressureSampleCount <= 0 ? 1.0 : pressureTotal / Double(pressureSampleCount)
    }

    /// Accumulates one normalized pressure sample.
    public mutating func recordPressure(_ normalizedPressure: Double) {
        pressureTotal += normalizedPressure
        pressureSampleCount += 1
    }
}
