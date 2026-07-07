//
//  KCStrokeRenderMathTests.swift
//  KCDrawingEngineTests
//
//  Created by 小大 on 2026/06/25.
//

import XCTest
@testable import KCDrawingEngine
import KCDomain
import KCCommon

final class StrokeRenderMathTests: XCTestCase {
    private func stroke(tool: KCToolMode, brush: KCBrushStyle, width: Double, pressure: Double) -> KCStroke {
        var s = KCStroke(toolMode: tool, brushStyle: brush, eraserShape: .circle,
                       color: KCHexColor(red: 0.1, green: 0.2, blue: 0.3), lineWidth: width)
        s.recordPressure(pressure)
        return s
    }

    func testPenAtFullPressureUsesSolidProductFormula() {
        // 钢笔应保持实色、利落，宽度接近配置值但不过分膨胀。
        let metrics = KCStrokeRenderMath.metrics(for: stroke(tool: .brush, brush: .pen, width: 20, pressure: 1.0))
        XCTAssertEqual(metrics.renderedLineWidth, 18.4, accuracy: 1e-9)
        XCTAssertEqual(metrics.alpha, 1.0)
    }

    func testPencilAlphaIsLightAtFullPressure() {
        let metrics = KCStrokeRenderMath.metrics(for: stroke(tool: .brush, brush: .pencil, width: 12, pressure: 1.0))
        // 铅笔应比钢笔更轻、更淡，而不是只比钢笔细一点。
        XCTAssertEqual(metrics.alpha, 0.26, accuracy: 1e-9)
        XCTAssertEqual(metrics.renderedLineWidth, 3.84, accuracy: 1e-9)
    }

    func testPencilAlphaCapsBelowSolidInkAtHighPressure() {
        let metrics = KCStrokeRenderMath.metrics(for: stroke(tool: .brush, brush: .pencil, width: 12, pressure: 2.0))
        XCTAssertEqual(metrics.alpha, 0.30, accuracy: 1e-9)
    }

    func testCrayonFormula() {
        let metrics = KCStrokeRenderMath.metrics(for: stroke(tool: .brush, brush: .crayon, width: 10, pressure: 1.0))
        // 蜡笔基础笔画必须退后，蜡感由断续蜡痕和颗粒层共同形成。
        XCTAssertEqual(metrics.alpha, 0.22, accuracy: 1e-9)
        XCTAssertEqual(metrics.renderedLineWidth, 15.2, accuracy: 1e-9)
    }

    func testRenderedWidthFloorsToOne() {
        // 极小的宽度 + 极小的压力不得低于 1.0。
        let metrics = KCStrokeRenderMath.metrics(for: stroke(tool: .brush, brush: .pencil, width: 0.1, pressure: 0.01))
        XCTAssertGreaterThanOrEqual(metrics.renderedLineWidth, 1.0)
    }

    func testEraserIgnoresPressureAndUsesFullAlpha() {
        let metrics = KCStrokeRenderMath.metrics(for: stroke(tool: .eraser, brush: .pen, width: 30, pressure: 0.3))
        // 橡皮擦使用自己的配置宽度，不再叠加画笔质感公式。
        XCTAssertEqual(metrics.alpha, 1.0)
        XCTAssertEqual(metrics.renderedLineWidth, 30.0, accuracy: 1e-9)
    }

    func testEraserWidthDoesNotDependOnCurrentBrushStyle() {
        let pencil = KCStrokeRenderMath.metrics(for: stroke(tool: .eraser, brush: .pencil, width: 30, pressure: 0.3))
        let pen = KCStrokeRenderMath.metrics(for: stroke(tool: .eraser, brush: .pen, width: 30, pressure: 0.3))
        let crayon = KCStrokeRenderMath.metrics(for: stroke(tool: .eraser, brush: .crayon, width: 30, pressure: 0.3))

        XCTAssertEqual(pencil, pen)
        XCTAssertEqual(crayon, pen)
    }

    func testEraserConfiguredWidthAppliesOnePointThreeFiveMultiplier() {
        XCTAssertEqual(KCStrokeRenderMath.eraserConfiguredWidth(from: 20), 27.0, accuracy: 1e-9)
        // 小宽度被提升到 16 的下限。
        XCTAssertEqual(KCStrokeRenderMath.eraserConfiguredWidth(from: 4), 16.0, accuracy: 1e-9)
    }

    // MARK: - 基础 renderedMetrics

    func testRenderedMetricsPrimitiveMatchesFullModel() {
        // 基础方法应产生与 metrics(for:) 完全一致的结果。
        let s = stroke(tool: .brush, brush: .crayon, width: 16, pressure: 0.8)
        let full = KCStrokeRenderMath.metrics(for: s)
        let primitive = KCStrokeRenderMath.renderedMetrics(brushStyle: .crayon, lineWidth: 16, pressure: 0.8)
        XCTAssertEqual(full.renderedLineWidth, primitive.renderedLineWidth, accuracy: 1e-9)
        XCTAssertEqual(full.alpha, primitive.alpha, accuracy: 1e-9)
    }

    func testRenderedMetricsFloorAtOne() {
        let m = KCStrokeRenderMath.renderedMetrics(brushStyle: .pencil, lineWidth: 0.01, pressure: 0.001)
        XCTAssertEqual(m.renderedLineWidth, 1.0, accuracy: 1e-9)
    }

    func testRenderedMetricsCrayonPressureScales() {
        let m = KCStrokeRenderMath.renderedMetrics(brushStyle: .crayon, lineWidth: 8, pressure: 0.5)
        XCTAssertEqual(m.alpha, 0.16, accuracy: 1e-9)
        XCTAssertEqual(m.renderedLineWidth, 6.08, accuracy: 1e-9)
    }

    func testBrushStylesAreVisuallySeparatedAtSameWidthAndPressure() {
        let pencil = KCStrokeRenderMath.renderedMetrics(brushStyle: .pencil, lineWidth: 16, pressure: 1.0)
        let pen = KCStrokeRenderMath.renderedMetrics(brushStyle: .pen, lineWidth: 16, pressure: 1.0)
        let crayon = KCStrokeRenderMath.renderedMetrics(brushStyle: .crayon, lineWidth: 16, pressure: 1.0)

        XCTAssertLessThan(pencil.alpha, pen.alpha)
        XCTAssertLessThan(pencil.renderedLineWidth, pen.renderedLineWidth)
        XCTAssertGreaterThan(crayon.renderedLineWidth, pen.renderedLineWidth)
        XCTAssertLessThan(crayon.alpha, pencil.alpha)

        let crayonProfile = KCStrokeRenderMath.renderProfile(brushStyle: .crayon, lineWidth: 16, pressure: 1.0)
        let waxStrength = crayonProfile.textureLayers
            .filter { $0.kind == .waxSmear }
            .reduce(0.0) { $0 + $1.alpha * $1.widthMultiplier }
        XCTAssertGreaterThan(waxStrength, crayon.alpha * 4.0)
    }

    func testBrushRenderProfilesEncodeDifferentTextures() {
        let pencil = KCStrokeRenderMath.renderProfile(brushStyle: .pencil, lineWidth: 16, pressure: 1.0)
        let pen = KCStrokeRenderMath.renderProfile(brushStyle: .pen, lineWidth: 16, pressure: 1.0)
        let crayon = KCStrokeRenderMath.renderProfile(brushStyle: .crayon, lineWidth: 16, pressure: 1.0)

        XCTAssertFalse(pencil.usesButtLineCap)
        XCTAssertTrue(pencil.textureLayers.contains { $0.kind == .softHalo })
        XCTAssertGreaterThanOrEqual(pencil.textureLayers.filter { $0.kind == .sketchLine }.count, 2)

        XCTAssertTrue(pen.usesButtLineCap)
        XCTAssertTrue(pen.textureLayers.isEmpty)
        XCTAssertEqual(pen.grainAlpha, 0.0, accuracy: 1e-9)

        XCTAssertFalse(crayon.usesButtLineCap)
        let waxLayers = crayon.textureLayers.filter { $0.kind == .waxSmear }
        XCTAssertGreaterThanOrEqual(waxLayers.count, 4)
        XCTAssertTrue(waxLayers.allSatisfy { !$0.dashPatternMultipliers.isEmpty })
        XCTAssertTrue(waxLayers.contains { $0.dashPhaseMultiplier > 0.0 })
        XCTAssertGreaterThan(crayon.grainAlpha, 0.35)
        XCTAssertGreaterThan(crayon.grainClipWidthMultiplier, 1.1)
    }

    func testPencilSketchLinesUseBrokenGraphiteTexture() {
        let pencil = KCStrokeRenderMath.renderProfile(brushStyle: .pencil, lineWidth: 16, pressure: 1.0)
        let sketchLayers = pencil.textureLayers.filter { $0.kind == .sketchLine }

        // 铅笔不能只是一条淡色实线；草稿线必须带断续纹理，形成石墨颗粒感。
        XCTAssertGreaterThanOrEqual(sketchLayers.count, 3)
        XCTAssertTrue(sketchLayers.allSatisfy { !$0.dashPatternMultipliers.isEmpty })
        XCTAssertTrue(sketchLayers.contains { $0.widthMultiplier <= 0.20 })
    }

    func testCrayonProfileIsTextureDominantInsteadOfSolidMarker() {
        let crayon = KCStrokeRenderMath.renderProfile(brushStyle: .crayon, lineWidth: 16, pressure: 1.0)
        let waxLayers = crayon.textureLayers.filter { $0.kind == .waxSmear }

        // 蜡笔的主体应更像堆叠蜡痕，而不是一条高透明度实心粗线。
        XCTAssertLessThanOrEqual(crayon.metrics.alpha, 0.56)
        XCTAssertTrue(waxLayers.contains { $0.widthMultiplier >= 1.45 && !$0.dashPatternMultipliers.isEmpty })
        XCTAssertGreaterThanOrEqual(crayon.grainAlpha, 0.90)
    }

    func testPencilAndCrayonTextureDominatesBaseStroke() {
        let pencil = KCStrokeRenderMath.renderProfile(brushStyle: .pencil, lineWidth: 16, pressure: 1.0)
        let pen = KCStrokeRenderMath.renderProfile(brushStyle: .pen, lineWidth: 16, pressure: 1.0)
        let crayon = KCStrokeRenderMath.renderProfile(brushStyle: .crayon, lineWidth: 16, pressure: 1.0)

        let pencilSketchStrength = pencil.textureLayers
            .filter { $0.kind == .sketchLine }
            .reduce(0.0) { $0 + $1.alpha * $1.widthMultiplier }
        let crayonWaxStrength = crayon.textureLayers
            .filter { $0.kind == .waxSmear }
            .reduce(0.0) { $0 + $1.alpha * $1.widthMultiplier }

        // 非钢笔工具的基础实线不能主导观感，否则用户看到的只会是粗细差异。
        XCTAssertLessThanOrEqual(pencil.metrics.alpha, 0.34)
        XCTAssertGreaterThan(pencilSketchStrength, pencil.metrics.alpha * 0.55)
        XCTAssertLessThan(pencil.metrics.renderedLineWidth, pen.metrics.renderedLineWidth * 0.45)

        XCTAssertLessThanOrEqual(crayon.metrics.alpha, 0.24)
        XCTAssertGreaterThan(crayonWaxStrength, crayon.metrics.alpha * 4.0)
        XCTAssertGreaterThanOrEqual(crayon.grainAlpha, 0.92)
    }

    func testUserVisibleBrushSignaturesAreNotWidthOnly() {
        let pencil = KCStrokeRenderMath.renderProfile(brushStyle: .pencil, lineWidth: 16, pressure: 1.0)
        let pen = KCStrokeRenderMath.renderProfile(brushStyle: .pen, lineWidth: 16, pressure: 1.0)
        let crayon = KCStrokeRenderMath.renderProfile(brushStyle: .crayon, lineWidth: 16, pressure: 1.0)

        let graphiteLayers = pencil.textureLayers.filter { $0.kind == .sketchLine }
        let graphiteStrength = graphiteLayers.reduce(0.0) { $0 + $1.alpha * $1.widthMultiplier }
        let waxLayers = crayon.textureLayers.filter { $0.kind == .waxSmear }
        let waxStrength = waxLayers.reduce(0.0) { $0 + $1.alpha * $1.widthMultiplier }

        // 用户反馈三种画笔观感像“只差粗细”后，画笔 profile 必须把视觉重心推到工具特征：
        // 铅笔是断续石墨线，钢笔是干净实线，蜡笔是宽蜡痕和颗粒，而不是一条半透明粗线。
        XCTAssertLessThanOrEqual(pencil.metrics.alpha, 0.28)
        XCTAssertGreaterThan(graphiteStrength, pencil.metrics.alpha * 1.15)
        XCTAssertTrue(graphiteLayers.contains { $0.widthMultiplier >= 0.42 && $0.alpha >= 0.34 })

        XCTAssertEqual(pen.metrics.alpha, 1.0, accuracy: 1e-9)
        XCTAssertEqual(pen.textureLayers.count, 0)

        XCTAssertLessThanOrEqual(crayon.metrics.alpha, 0.24)
        XCTAssertTrue(waxLayers.contains { $0.widthMultiplier >= 1.45 && $0.alpha >= 0.22 })
        XCTAssertTrue(waxLayers.contains { $0.widthMultiplier <= 0.28 && $0.dashPhaseMultiplier > 0.70 })
        XCTAssertGreaterThan(waxStrength, crayon.metrics.alpha * 4.4)
        XCTAssertGreaterThanOrEqual(crayon.grainAlpha, 0.92)
        XCTAssertGreaterThanOrEqual(crayon.grainClipWidthMultiplier, 1.70)
    }
}
