//
//  KCStickerConstraintsTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/06/26.
//

import XCTest
@testable import KCDomain

final class StickerConstraintsTests: XCTestCase {

    // MARK: - Scale extraction & clamping

    func testScaleOfIdentityIsOne() {
        XCTAssertEqual(KCStickerConstraints.scale(of: .identity), 1.0, accuracy: 1e-9)
    }

    func testScaleOfPureScaleTransformReadsMagnitude() {
        // 2x uniform scale → hypot(2, 0) = 2.
        let scaled = CGAffineTransform(scaleX: 2.0, y: 2.0)
        XCTAssertEqual(KCStickerConstraints.scale(of: scaled), 2.0, accuracy: 1e-9)
    }

    func testScaleOfRotatedTransformIsInvariant() {
        // Rotation changes a/c but hypot(a, c) stays 1 for a pure rotation.
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
        // A zero-scale transform is degenerate; prototype resets to identity.
        let degenerate = CGAffineTransform(scaleX: 0.0, y: 0.0)
        let result = KCStickerConstraints.transformWithClampedScale(degenerate)
        XCTAssertEqual(result, .identity)
    }

    func testTransformWithClampedScaleLeavesInrangeTransformUnchanged() {
        // 1.5 is within [0.48, 2.6]; within tolerance → returned as-is.
        let transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        let result = KCStickerConstraints.transformWithClampedScale(transform)
        XCTAssertEqual(result, transform)
    }

    func testTransformWithClampedScaleClampsOversize() {
        // 4x → clamped to 2.6.
        let transform = CGAffineTransform(scaleX: 4.0, y: 4.0)
        let result = KCStickerConstraints.transformWithClampedScale(transform)
        XCTAssertEqual(KCStickerConstraints.scale(of: result), KCStickerConstraints.maximumScale, accuracy: 1e-9)
    }

    func testTransformWithClampedScalePreservesRotationWhileClamping() {
        // A rotated, over-scaled transform should keep its rotation angle after
        // the scale is clamped (correction is uniform).
        let transform = CGAffineTransform(scaleX: 5.0, y: 5.0).rotated(by: 0.9)
        let result = KCStickerConstraints.transformWithClampedScale(transform)
        XCTAssertEqual(KCStickerConstraints.scale(of: result), KCStickerConstraints.maximumScale, accuracy: 1e-9)
        // Rotation preserved: b sign/magnitude ratio stays consistent. The clamped
        // result's scale is the max, and it is still a valid rigid+scale matrix.
        XCTAssertNotEqual(result, .identity)
    }

    func testTransformWithClampedScaleClampsUndersize() {
        // 0.1x → clamped to 0.48.
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
        // Canvas 400×300; sticker frame 80×80 centered at (200, 150) is inbound.
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
        // Center far off the bottom-right corner is clamped so at least half the
        // sticker (min 24pt) stays inside the 400×300 canvas.
        let result = KCStickerConstraints.clampedCenter(
            CGPoint(x: 5000, y: 5000),
            frame: CGRect(x: 0, y: 0, width: 60, height: 60),
            canvasBounds: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        // halfWidth = min(200, max(24, 30)) = 30 → maxX = max(30, 400-30) = 370.
        XCTAssertLessThanOrEqual(result.x, 370.0 + 1e-9)
        XCTAssertLessThanOrEqual(result.y, 270.0 + 1e-9)
        XCTAssertGreaterThanOrEqual(result.x, 30.0 - 1e-9)
        XCTAssertGreaterThanOrEqual(result.y, 30.0 - 1e-9)
    }

    func testClampedCenterUsesTwentyFourPointMinimumForLargeSticker() {
        // A huge sticker frame is clamped by min(canvasHalf, max(24, frameHalf)).
        // frameHalf=300 → clamped to canvasHalf=200; center stays at canvas center.
        let result = KCStickerConstraints.clampedCenter(
            CGPoint(x: 999, y: 999),
            frame: CGRect(x: 0, y: 0, width: 600, height: 600),
            canvasBounds: CGRect(x: 0, y: 0, width: 400, height: 400)
        )
        XCTAssertEqual(result.x, 200, accuracy: 1e-9)
        XCTAssertEqual(result.y, 200, accuracy: 1e-9)
    }

    // MARK: - contains (hit-test primitive)

    func testContainsInsideRect() {
        XCTAssertTrue(KCStickerConstraints.contains(CGRect(x: 0, y: 0, width: 50, height: 50),
                                                     point: CGPoint(x: 25, y: 25)))
    }

    func testContainsOutsideRect() {
        XCTAssertFalse(KCStickerConstraints.contains(CGRect(x: 0, y: 0, width: 50, height: 50),
                                                      point: CGPoint(x: 70, y: 70)))
    }
}
