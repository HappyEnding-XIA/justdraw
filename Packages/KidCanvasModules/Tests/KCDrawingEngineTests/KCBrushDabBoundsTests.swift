//
//  KCBrushDabBoundsTests.swift
//  KCDrawingEngineTests
//
//  Created by 小大 on 2026/07/08.
//

import XCTest
@testable import KCDrawingEngine
import CoreGraphics

/// T094：`KCBrushDab.bounds(inset:)` 的几何测试，供 UIKit dirty rect 使用。
final class KCBrushDabBoundsTests: XCTestCase {

    private func dab(center: CGPoint = .zero,
                     radius: Double,
                     aspectRatio: Double = 1.0,
                     rotation: Double = 0.0) -> KCBrushDab {
        KCBrushDab(center: center, radius: radius, alpha: 1.0, flow: 1.0,
                   rotation: rotation, aspectRatio: aspectRatio,
                   hardness: 0.5, textureStrength: 0.0, seed: 0)
    }

    func testRoundDabBoundsAtOrigin() {
        let bounds = dab(radius: 10.0).bounds()
        XCTAssertEqual(bounds.minX, -10.0, accuracy: 1e-6)
        XCTAssertEqual(bounds.minY, -10.0, accuracy: 1e-6)
        XCTAssertEqual(bounds.width, 20.0, accuracy: 1e-6)
        XCTAssertEqual(bounds.height, 20.0, accuracy: 1e-6)
    }

    func testInsetExpandsBounds() {
        let bounds = dab(radius: 10.0).bounds(inset: 2.0)
        XCTAssertEqual(bounds.minX, -12.0, accuracy: 1e-6)
        XCTAssertEqual(bounds.width, 24.0, accuracy: 1e-6)
    }

    func testFlattenedDabIsWiderThanTall() {
        // aspectRatio 2、未旋转：x 半轴 = 20，y 半轴 = 10。
        let bounds = dab(radius: 10.0, aspectRatio: 2.0).bounds()
        XCTAssertEqual(bounds.width, 40.0, accuracy: 1e-6)
        XCTAssertEqual(bounds.height, 20.0, accuracy: 1e-6)
    }

    func testRotatedFlatDabSwapsExtents() {
        // 旋转 90° 后，原本横向拉伸的椭圆变成纵向。
        let bounds = dab(radius: 10.0, aspectRatio: 2.0, rotation: .pi / 2.0).bounds()
        XCTAssertEqual(bounds.width, 20.0, accuracy: 1e-6)
        XCTAssertEqual(bounds.height, 40.0, accuracy: 1e-6)
    }

    func testBoundsCenteredOnDabCenter() {
        let bounds = dab(center: CGPoint(x: 100.0, y: 50.0), radius: 5.0).bounds()
        XCTAssertEqual(bounds.midX, 100.0, accuracy: 1e-6)
        XCTAssertEqual(bounds.midY, 50.0, accuracy: 1e-6)
        XCTAssertEqual(bounds.width, 10.0, accuracy: 1e-6)
    }
}
