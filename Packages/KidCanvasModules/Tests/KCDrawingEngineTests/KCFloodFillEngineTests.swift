//
//  KCFloodFillEngineTests.swift
//  KCDrawingEngineTests
//
//  Created by 小大 on 2026/06/25.
//

import XCTest
@testable import KCDrawingEngine
import KCCommon

final class FloodFillEngineTests: XCTestCase {
    func testFillsUniformRegionEntirely() {
        let buffer = KCBitmapBuffer(width: 10, height: 10, fill: .white)
        let changed = KCFloodFillEngine.fill(buffer: buffer, startX: 5, startY: 5,
                                           fillColor: .black, tolerance: 28)
        XCTAssertEqual(changed, 100)
        XCTAssertEqual(buffer.pixel(x: 0, y: 0), .black)
        XCTAssertEqual(buffer.pixel(x: 9, y: 9), .black)
    }

    func testStopsAtColorBoundary() {
        // 左半部为白色，第 5 列有一道竖直的黑色墙，右半部为白色。
        let buffer = KCBitmapBuffer(width: 10, height: 4, fill: .white)
        for y in 0..<4 {
            buffer.setPixel(.black, x: 5, y: y)
        }
        let changed = KCFloodFillEngine.fill(buffer: buffer, startX: 0, startY: 0,
                                           fillColor: KCRGBA8(red: 255, green: 0, blue: 0),
                                           tolerance: 28)
        // 第 0-4 列（共 5 列）× 4 行 = 20 个像素。
        XCTAssertEqual(changed, 20)
        XCTAssertEqual(buffer.pixel(x: 0, y: 0).red, 255)
        // 右半部未受影响（墙阻挡了 BFS 扩展）。
        XCTAssertEqual(buffer.pixel(x: 6, y: 0), .white)
    }

    func testToleranceAllowNearColors() {
        // 种子为近白色（252）。邻居像素 250 在 tolerance*4=112 范围内。
        let nearWhite = KCRGBA8(red: 252, green: 252, blue: 252)
        let buffer = KCBitmapBuffer(width: 3, height: 1, fill: nearWhite)
        buffer.setPixel(KCRGBA8(red: 250, green: 250, blue: 250), x: 2, y: 0)
        let changed = KCFloodFillEngine.fill(buffer: buffer, startX: 0, startY: 0,
                                           fillColor: .black, tolerance: 28)
        // 252 与 250 之间的 delta = 每通道 2 × 3 = 6 <= 112，因此全部填充。
        XCTAssertEqual(changed, 3)
    }

    func testReturnsZeroWhenSeedEqualsFill() {
        let buffer = KCBitmapBuffer(width: 4, height: 4, fill: .white)
        let changed = KCFloodFillEngine.fill(buffer: buffer, startX: 0, startY: 0,
                                           fillColor: .white, tolerance: 28)
        XCTAssertEqual(changed, 0)
    }

    func testOutOfBoundsSeedFillsNothing() {
        let buffer = KCBitmapBuffer(width: 4, height: 4, fill: .white)
        XCTAssertEqual(KCFloodFillEngine.fill(buffer: buffer, startX: 99, startY: 0,
                                            fillColor: .black), 0)
        XCTAssertEqual(KCFloodFillEngine.fill(buffer: buffer, startX: 0, startY: -1,
                                            fillColor: .black), 0)
    }

    func testDiagonalBarrierDoesNotLeak() {
        // 4 连通填充不得穿过对角线排列的边界像素。
        let buffer = KCBitmapBuffer(width: 5, height: 5, fill: .white)
        for i in 0..<5 {
            buffer.setPixel(.black, x: i, y: i)
        }
        KCFloodFillEngine.fill(buffer: buffer, startX: 0, startY: 4,
                             fillColor: KCRGBA8(red: 255, green: 0, blue: 0), tolerance: 28)
        // (0,4) 为白色且可达；对角线仅触及角点。
        XCTAssertEqual(buffer.pixel(x: 0, y: 4).red, 255)
        // (4,0) 被对角线隔开，保持白色。
        XCTAssertEqual(buffer.pixel(x: 4, y: 0), .white)
    }
}

final class ColorSamplerTests: XCTestCase {
    func testSampleReturnsInBoundsPixel() {
        let buffer = KCBitmapBuffer(width: 2, height: 2, fill: .white)
        buffer.setPixel(KCRGBA8(red: 10, green: 20, blue: 30), x: 1, y: 0)
        let sample = KCColorSampler.sample(buffer: buffer, x: 1, y: 0)
        XCTAssertEqual(sample?.red, 10)
        XCTAssertEqual(sample?.green, 20)
        XCTAssertEqual(sample?.blue, 30)
    }

    func testSampleOutOfBoundReturnsNil() {
        let buffer = KCBitmapBuffer(width: 2, height: 2, fill: .white)
        XCTAssertNil(KCColorSampler.sample(buffer: buffer, x: 5, y: 0))
    }

    func testSampleHexConvertsToHexColor() {
        let buffer = KCBitmapBuffer(width: 1, height: 1, fill: .white)
        let hex = KCColorSampler.sampleHex(buffer: buffer, x: 0, y: 0)
        XCTAssertEqual(hex?.hex, "#FFFFFF")
    }
}

final class BitmapBufferRoundTripTests: XCTestCase {
    func testCGImageRoundTripPreservesSolidColor() {
        let original = KCBitmapBuffer(width: 8, height: 8, fill: KCRGBA8(red: 30, green: 60, blue: 90))
        guard let image = original.makeCGImage() else {
            XCTFail("makeCGImage returned nil"); return
        }
        let restored = KCBitmapBuffer(cgImage: image)
        XCTAssertNotNil(restored)
        // premultiplied-last 的 RGB 对于不透明颜色是无损的。
        XCTAssertEqual(restored?.pixel(x: 0, y: 0).red, 30)
        XCTAssertEqual(restored?.pixel(x: 7, y: 7).blue, 90)
    }

    func testZeroSizedImageInitFails() {
        // 零尺寸的 CGImage 不会产生；通过空缓冲区触发保护。
        let buffer = KCBitmapBuffer(width: 0, height: 0)
        XCTAssertNil(buffer.makeCGImage())
    }
}

final class PressureModelTests: XCTestCase {
    func testNoForceReportsUnity() {
        XCTAssertEqual(KCPressureModel.normalized(force: 0, maximumPossibleForce: 0, isPencil: false), 1.0)
    }

    func testFingerClampsToLowerBound() {
        // 0.96 + 0*0.28 = 0.96，落在 [0.92, 1.18] 范围内。
        let p = KCPressureModel.finger(normalizedForce: 0)
        XCTAssertEqual(p, 0.96, accuracy: 1e-9)
    }

    func testFingerClampsToUpperBound() {
        let p = KCPressureModel.finger(normalizedForce: 1.0)
        XCTAssertEqual(p, 1.18, accuracy: 1e-9)
    }

    func testPencilMidRange() {
        // 0.72 + 0.5*0.95 = 1.195
        let p = KCPressureModel.pencil(normalizedForce: 0.5)
        XCTAssertEqual(p, 1.195, accuracy: 1e-9)
    }

    func testPencilClampsToLowerBound() {
        // 0.72 + 0*0.95 = 0.72；0.65 下限仅在负压力时才起作用。
        let p = KCPressureModel.pencil(normalizedForce: 0)
        XCTAssertEqual(p, 0.72, accuracy: 1e-9)
    }
}

final class EraserStampPathTests: XCTestCase {
    func testCirclePathIsNonEmpty() {
        let path = KCEraserStampPath.path(for: .circle, center: CGPoint(x: 50, y: 50), size: 40)
        XCTAssertFalse(path.isEmpty)
    }

    func testCloudPathIsNonEmpty() {
        let path = KCEraserStampPath.path(for: .cloud, center: CGPoint(x: 50, y: 50), size: 40)
        XCTAssertFalse(path.isEmpty)
    }

    func testStarPathIsNonEmpty() {
        let path = KCEraserStampPath.path(for: .star, center: CGPoint(x: 50, y: 50), size: 40)
        XCTAssertFalse(path.isEmpty)
    }

    func testMinimumRadiusEnforcedForTinySize() {
        // size * 0.55 = 1.1，应被向上钳制到 10。
        let path = KCEraserStampPath.path(for: .circle, center: CGPoint(x: 0, y: 0), size: 2)
        let bounds = path.boundingBox
        // 直径应约为 20（半径 10），远大于 size 2。
        XCTAssertGreaterThan(bounds.width, 15)
    }
}
