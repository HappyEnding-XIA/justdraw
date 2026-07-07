//
//  KCCrayonGrainTests.swift
//  KCDrawingEngineTests
//
//  Created by 小大 on 2026/06/26.
//

import XCTest
@testable import KCDrawingEngine

final class CrayonGrainTests: XCTestCase {

    // 根据产品化蜡笔颗粒数学手工计算的参考用例：
    // bounds {0,0,100,50}，lineWidth 10。
    // grainBounds {-5,-5,110,60}；spacing = max(3.0, 2.4) = 3.0；
    // columnCount = ceil(110/3.0) = 37；rowCount = ceil(60/3.0) = 20；
    // dash count = (20+1) * (37+1) = 798；dashWidth = max(1.4, 2.4) = 2.4。
    private static let referenceBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
    private static let referenceLineWidth: CGFloat = 10

    func testEmptyBoundsReturnsNoDashes() {
        XCTAssertTrue(KCCrayonGrain.dashes(pathBounds: .zero, lineWidth: 10).isEmpty)
        XCTAssertTrue(KCCrayonGrain.dashes(pathBounds: CGRect(x: 5, y: 5, width: 0, height: 0),
                                           lineWidth: 10).isEmpty)
    }

    func testDashCountAndConstantWidthForReferenceBounds() {
        let dashes = KCCrayonGrain.dashes(pathBounds: CrayonGrainTests.referenceBounds,
                                          lineWidth: CrayonGrainTests.referenceLineWidth)
        XCTAssertEqual(dashes.count, 798)
        for dash in dashes {
            XCTAssertEqual(dash.lineWidth, 2.4, accuracy: 1e-9)
        }
    }

    func testFirstDashGeometryMatchesPrototype() {
        // row 0, column 0：seed 0 → jitter (-1.38, -1.14)；center (-6.38, -6.14)；
        // dashLength 1.8；y offset +0.95（偶数 seed）。
        let dashes = KCCrayonGrain.dashes(pathBounds: CrayonGrainTests.referenceBounds,
                                          lineWidth: CrayonGrainTests.referenceLineWidth)
        let first = dashes[0]
        XCTAssertEqual(first.start.x, -7.28, accuracy: 1e-9)
        XCTAssertEqual(first.start.y, -6.14, accuracy: 1e-9)
        XCTAssertEqual(first.end.x, -5.48, accuracy: 1e-9)
        XCTAssertEqual(first.end.y, -5.19, accuracy: 1e-9)
    }

    func testDashGeometryAtRowColumnMatchesPrototype() {
        // row 1, column 1（行优先索引 38 + 1 = 39）：seed 54。
        // jitter (0.92, 0.38)；center (-1.08, -1.62)；
        // dashLength = 10 * (0.18 + 4*0.035) = 3.2；y offset +0.95。
        let dashes = KCCrayonGrain.dashes(pathBounds: CrayonGrainTests.referenceBounds,
                                          lineWidth: CrayonGrainTests.referenceLineWidth)
        let dash = dashes[39]
        XCTAssertEqual(dash.start.x, -2.68, accuracy: 1e-9)
        XCTAssertEqual(dash.start.y, -1.62, accuracy: 1e-9)
        XCTAssertEqual(dash.end.x, 0.52, accuracy: 1e-9)
        XCTAssertEqual(dash.end.y, -0.67, accuracy: 1e-9)
    }

    func testGridRespectsColumnAndRowCaps() {
        // 巨大的 bounds 配合较小的 spacing 会同时触发两个上限：220 列 × 180 行。
        // lineWidth 4 → spacing = max(3.0, 0.96) = 3.0；grainBounds 每侧扩展 2。
        let dashes = KCCrayonGrain.dashes(pathBounds: CGRect(x: 0, y: 0, width: 10000, height: 10000),
                                          lineWidth: 4)
        XCTAssertEqual(dashes.count, (180 + 1) * (220 + 1))
    }

    func testDashWidthFloorsToOnePointOneForThinLines() {
        let dashes = KCCrayonGrain.dashes(pathBounds: CGRect(x: 0, y: 0, width: 20, height: 20),
                                          lineWidth: 0.01)
        XCTAssertFalse(dashes.isEmpty)
        for dash in dashes {
            XCTAssertEqual(dash.lineWidth, 1.4, accuracy: 1e-9)
        }
    }

    func testDashWidthScalesForWideCrayonLines() {
        let dashes = KCCrayonGrain.dashes(pathBounds: CGRect(x: 0, y: 0, width: 80, height: 40),
                                          lineWidth: 24.0)

        // 宽蜡笔需要更明显的颗粒短线，否则实际观感会退化成平滑粗笔。
        XCTAssertFalse(dashes.isEmpty)
        for dash in dashes {
            XCTAssertEqual(dash.lineWidth, 5.76, accuracy: 1e-9)
        }
    }

    func testDefaultCrayonGrainIsChunkyEnoughForFingerDrawing() {
        let dashes = KCCrayonGrain.dashes(pathBounds: CGRect(x: 0, y: 0, width: 120, height: 80),
                                          lineWidth: 24.0)

        // 默认蜡笔在手指绘制时需要肉眼可见的蜡粒，不能只留下细碎噪点。
        XCTAssertFalse(dashes.isEmpty)
        XCTAssertGreaterThanOrEqual(dashes[0].lineWidth, 5.2)
    }

    func testProductizedGrainIsDenseEnoughForVisibleCrayonTexture() {
        let dashes = KCCrayonGrain.dashes(pathBounds: CGRect(x: 0, y: 0, width: 120, height: 80),
                                          lineWidth: 16.0)

        // 中等蜡笔线宽下，颗粒要有明显厚度，同时不能密到把纸纹空隙糊平。
        XCTAssertGreaterThanOrEqual(dashes.count, 1_200)
        XCTAssertLessThanOrEqual(dashes.count, 1_450)
        XCTAssertGreaterThanOrEqual(dashes[0].lineWidth, 3.6)
    }

    func testMediumCrayonUsesChunkierAndDenserWaxGrain() {
        let dashes = KCCrayonGrain.dashes(pathBounds: CGRect(x: 0, y: 0, width: 120, height: 80),
                                          lineWidth: 16.0)

        // 用户侧反馈蜡笔观感不明显后，中等线宽必须能看出蜡笔碎粒和纸纹断续感。
        XCTAssertGreaterThanOrEqual(dashes.count, 1_200)
        XCTAssertLessThanOrEqual(dashes.count, 1_450)
        XCTAssertGreaterThanOrEqual(dashes[0].lineWidth, 3.6)
    }

    func testMediumCrayonGrainKeepsVisiblePaperToothDensity() {
        let dashes = KCCrayonGrain.dashes(pathBounds: CGRect(x: 0, y: 0, width: 120, height: 80),
                                          lineWidth: 16.0)

        // 中等线宽不能稀疏到像半透明宽线；颗粒密度要足够让纸纹和蜡痕在默认手指绘制时可见。
        XCTAssertGreaterThanOrEqual(dashes.count, 1_200)
        XCTAssertLessThanOrEqual(dashes.count, 1_450)
    }
}
