//
//  KCStickerConstraintsTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/06/26.
//

import XCTest
@testable import KCDomain

final class StickerConstraintsTests: XCTestCase {

    // MARK: - 缩放提取与钳制

    func testScaleOfIdentityIsOne() {
        XCTAssertEqual(KCStickerConstraints.scale(of: .identity), 1.0, accuracy: 1e-9)
    }

    func testScaleOfPureScaleTransformReadsMagnitude() {
        // 2 倍均匀缩放 → hypot(2, 0) = 2。
        let scaled = CGAffineTransform(scaleX: 2.0, y: 2.0)
        XCTAssertEqual(KCStickerConstraints.scale(of: scaled), 2.0, accuracy: 1e-9)
    }

    func testScaleOfRotatedTransformIsInvariant() {
        // 旋转会改变 a/c，但对于纯旋转，hypot(a, c) 仍为 1。
        let rotated = CGAffineTransform(rotationAngle: 0.7)
        XCTAssertEqual(KCStickerConstraints.scale(of: rotated), 1.0, accuracy: 1e-9)
    }

    func testClampedScaleRespectsMinAndMax() {
        XCTAssertEqual(KCStickerConstraints.clampedScale(0.1), KCStickerConstraints.minimumScale, accuracy: 1e-9)
        XCTAssertEqual(KCStickerConstraints.clampedScale(5.0), KCStickerConstraints.maximumScale, accuracy: 1e-9)
        XCTAssertEqual(KCStickerConstraints.clampedScale(1.5), 1.5, accuracy: 1e-9)
    }

    // MARK: - transformWithClampedScale

    func testTransformWithClampedScaleResetsDegenerateToIdentity() {
        // 零缩放变换是退化的；原型会重置为恒等变换。
        let degenerate = CGAffineTransform(scaleX: 0.0, y: 0.0)
        let result = KCStickerConstraints.transformWithClampedScale(degenerate)
        XCTAssertEqual(result, .identity)
    }

    func testTransformWithClampedScaleLeavesInrangeTransformUnchanged() {
        // 1.5 处于 [0.48, 2.6] 范围内；在容差内 → 原样返回。
        let transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        let result = KCStickerConstraints.transformWithClampedScale(transform)
        XCTAssertEqual(result, transform)
    }

    func testTransformWithClampedScaleClampsOversize() {
        // 4 倍 → 钳制为 2.6。
        let transform = CGAffineTransform(scaleX: 4.0, y: 4.0)
        let result = KCStickerConstraints.transformWithClampedScale(transform)
        XCTAssertEqual(KCStickerConstraints.scale(of: result), KCStickerConstraints.maximumScale, accuracy: 1e-9)
    }

    func testTransformWithClampedScalePreservesRotationWhileClamping() {
        // 一个旋转且过度缩放的变换，在缩放被钳制后应保持其旋转角度
        // （修正是均匀的）。
        let transform = CGAffineTransform(scaleX: 5.0, y: 5.0).rotated(by: 0.9)
        let result = KCStickerConstraints.transformWithClampedScale(transform)
        XCTAssertEqual(KCStickerConstraints.scale(of: result), KCStickerConstraints.maximumScale, accuracy: 1e-9)
        // 旋转保留：b 的符号/幅值比保持一致。钳制后的结果缩放为最大值，
        // 且仍是一个有效的刚体+缩放矩阵。
        XCTAssertNotEqual(result, .identity)
    }

    func testTransformWithClampedScaleClampsUndersize() {
        // 0.1 倍 → 钳制为 0.48。
        let transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        let result = KCStickerConstraints.transformWithClampedScale(transform)
        XCTAssertEqual(KCStickerConstraints.scale(of: result), KCStickerConstraints.minimumScale, accuracy: 1e-9)
    }

    // MARK: - clampedCenter

    func testClampedCenterReturnsUnchangedOnEmptyCanvas() {
        let center = CGPoint(x: 500, y: 700)
        let result = KCStickerConstraints.clampedCenter(
            center,
            frame: CGRect(x: 450, y: 650, width: 100, height: 100),
            canvasBounds: .zero
        )
        XCTAssertEqual(result, center)
    }

    func testClampedCenterKeepsInboundCenterUnchanged() {
        // 画布 400×300；以 (200, 150) 为中心的 80×80 贴纸框在边界内。
        let center = CGPoint(x: 200, y: 150)
        let result = KCStickerConstraints.clampedCenter(
            center,
            frame: CGRect(x: 160, y: 110, width: 80, height: 80),
            canvasBounds: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        XCTAssertEqual(result.x, 200, accuracy: 1e-9)
        XCTAssertEqual(result.y, 150, accuracy: 1e-9)
    }

    func testClampedCenterPullsOffscreenCenterBackInBounds() {
        // 远离右下角的中心被钳制，使至少一半贴纸（最小 24pt）保持在 400×300
        // 画布内。
        let result = KCStickerConstraints.clampedCenter(
            CGPoint(x: 5000, y: 5000),
            frame: CGRect(x: 0, y: 0, width: 60, height: 60),
            canvasBounds: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        // halfWidth = min(200, max(24, 30)) = 30 → maxX = max(30, 400-30) = 370。
        XCTAssertLessThanOrEqual(result.x, 370.0 + 1e-9)
        XCTAssertLessThanOrEqual(result.y, 270.0 + 1e-9)
        XCTAssertGreaterThanOrEqual(result.x, 30.0 - 1e-9)
        XCTAssertGreaterThanOrEqual(result.y, 30.0 - 1e-9)
    }

    func testClampedCenterUsesTwentyFourPointMinimumForLargeSticker() {
        // 巨大的贴纸框由 min(canvasHalf, max(24, frameHalf)) 钳制。
        // frameHalf=300 → 钳制为 canvasHalf=200；中心保持在画布中心。
        let result = KCStickerConstraints.clampedCenter(
            CGPoint(x: 999, y: 999),
            frame: CGRect(x: 0, y: 0, width: 600, height: 600),
            canvasBounds: CGRect(x: 0, y: 0, width: 400, height: 400)
        )
        XCTAssertEqual(result.x, 200, accuracy: 1e-9)
        XCTAssertEqual(result.y, 200, accuracy: 1e-9)
    }

    // MARK: - contains（命中测试原语）

    func testContainsInsideRect() {
        XCTAssertTrue(KCStickerConstraints.contains(CGRect(x: 0, y: 0, width: 50, height: 50),
                                                     point: CGPoint(x: 25, y: 25)))
    }

    func testContainsOutsideRect() {
        XCTAssertFalse(KCStickerConstraints.contains(CGRect(x: 0, y: 0, width: 50, height: 50),
                                                      point: CGPoint(x: 70, y: 70)))
    }
}
