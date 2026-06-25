import XCTest
@testable import KCDrawingEngine
import KCDomain
import KCCommon

final class StrokeRenderMathTests: XCTestCase {
    private func stroke(tool: ToolMode, brush: BrushStyle, width: Double, pressure: Double) -> Stroke {
        var s = Stroke(toolMode: tool, brushStyle: brush, eraserShape: .circle,
                       color: HexColor(red: 0.1, green: 0.2, blue: 0.3), lineWidth: width)
        s.recordPressure(pressure)
        return s
    }

    func testPenAtFullPressureMatchesPrototypeFormula() {
        // width * 0.72 * min(1.18, max(0.88, 1.0)) = 20 * 0.72 * 1.0 = 14.4
        let metrics = StrokeRenderMath.metrics(for: stroke(tool: .brush, brush: .pen, width: 20, pressure: 1.0))
        XCTAssertEqual(metrics.renderedLineWidth, 14.4, accuracy: 1e-9)
        XCTAssertEqual(metrics.alpha, 1.0)
    }

    func testPencilAlphaClampsBelowPointNineTwo() {
        let metrics = StrokeRenderMath.metrics(for: stroke(tool: .brush, brush: .pencil, width: 12, pressure: 1.0))
        // alpha = min(0.92, 0.62 + 1.0*0.18) = min(0.92, 0.80) = 0.80
        XCTAssertEqual(metrics.alpha, 0.80, accuracy: 1e-9)
        // width = 12 * 0.9 * 1.0 = 10.8
        XCTAssertEqual(metrics.renderedLineWidth, 10.8, accuracy: 1e-9)
    }

    func testPencilAlphaCapsAtPointNineTwoAtHighPressure() {
        let metrics = StrokeRenderMath.metrics(for: stroke(tool: .brush, brush: .pencil, width: 12, pressure: 2.0))
        // alpha = min(0.92, 0.62 + 0.36) = 0.92
        XCTAssertEqual(metrics.alpha, 0.92, accuracy: 1e-9)
    }

    func testCrayonFormula() {
        let metrics = StrokeRenderMath.metrics(for: stroke(tool: .brush, brush: .crayon, width: 10, pressure: 1.0))
        // alpha = min(0.92, 0.58 + 0.20) = 0.78; width = 10 * 1.12 = 11.2
        XCTAssertEqual(metrics.alpha, 0.78, accuracy: 1e-9)
        XCTAssertEqual(metrics.renderedLineWidth, 11.2, accuracy: 1e-9)
    }

    func testRenderedWidthFloorsToOne() {
        // Tiny width + tiny pressure must not drop below 1.0.
        let metrics = StrokeRenderMath.metrics(for: stroke(tool: .brush, brush: .pencil, width: 0.1, pressure: 0.01))
        XCTAssertGreaterThanOrEqual(metrics.renderedLineWidth, 1.0)
    }

    func testEraserIgnoresPressureAndUsesFullAlpha() {
        let metrics = StrokeRenderMath.metrics(for: stroke(tool: .eraser, brush: .pen, width: 30, pressure: 0.3))
        // Eraser forces pressure to 1.0; pen width = 30 * 0.72 * 1.0 = 21.6; alpha 1.0.
        XCTAssertEqual(metrics.alpha, 1.0)
        XCTAssertEqual(metrics.renderedLineWidth, 21.6, accuracy: 1e-9)
    }

    func testEraserConfiguredWidthAppliesOnePointThreeFiveMultiplier() {
        XCTAssertEqual(StrokeRenderMath.eraserConfiguredWidth(from: 20), 27.0, accuracy: 1e-9)
        // Small widths are lifted to the 16 floor.
        XCTAssertEqual(StrokeRenderMath.eraserConfiguredWidth(from: 4), 16.0, accuracy: 1e-9)
    }

    // MARK: - Primitive renderedMetrics

    func testRenderedMetricsPrimitiveMatchesFullModel() {
        // The primitive method should produce identical results to metrics(for:).
        let s = stroke(tool: .brush, brush: .crayon, width: 16, pressure: 0.8)
        let full = StrokeRenderMath.metrics(for: s)
        let primitive = StrokeRenderMath.renderedMetrics(brushStyle: .crayon, lineWidth: 16, pressure: 0.8)
        XCTAssertEqual(full.renderedLineWidth, primitive.renderedLineWidth, accuracy: 1e-9)
        XCTAssertEqual(full.alpha, primitive.alpha, accuracy: 1e-9)
    }

    func testRenderedMetricsFloorAtOne() {
        let m = StrokeRenderMath.renderedMetrics(brushStyle: .pencil, lineWidth: 0.01, pressure: 0.001)
        XCTAssertEqual(m.renderedLineWidth, 1.0, accuracy: 1e-9)
    }

    func testRenderedMetricsCrayonPressureScales() {
        // crayon alpha = min(0.92, 0.58 + 0.5*0.20) = 0.68; width = 8 * 1.12 * 0.5 = 4.48
        let m = StrokeRenderMath.renderedMetrics(brushStyle: .crayon, lineWidth: 8, pressure: 0.5)
        XCTAssertEqual(m.alpha, 0.68, accuracy: 1e-9)
        XCTAssertEqual(m.renderedLineWidth, 4.48, accuracy: 1e-9)
    }
}
