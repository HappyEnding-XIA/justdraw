//
//  KCCanvasViewportStateTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/07/09.
//

import XCTest
import CoreGraphics
@testable import KCDomain

final class KCCanvasViewportStateTests: XCTestCase {

    /// 断言两个点在 `accuracy` 容差内相等（CGPoint 无 accuracy 重载，逐分量比较）。
    private func assertPointEqual(
        _ lhs: CGPoint,
        _ rhs: CGPoint,
        accuracy: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.x, rhs.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.y, rhs.y, accuracy: accuracy, file: file, line: line)
    }

    /// 断言缩放后的内容矩形完全落在安全创作区内（画纸未移出创作区、未压到工具轨/面板）。
    /// 内容原点 = `viewPoint(forCanvasPoint: .zero)`，内容末端 = 内容右下角的屏幕投影。
    private func assertContentInsideViewport(
        _ state: KCCanvasViewportState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let origin = state.viewPoint(forCanvasPoint: .zero)
        let far = state.viewPoint(forCanvasPoint: CGPoint(x: state.contentSize.width, y: state.contentSize.height))
        // 完全在内条件（含边界相切）：内容原点 ≥ 创作区左沿、内容末端 ≤ 创作区右沿。
        let insideX = origin.x >= state.viewportRect.minX && far.x <= state.viewportRect.maxX
        let insideY = origin.y >= state.viewportRect.minY && far.y <= state.viewportRect.maxY
        XCTAssertTrue(insideX, "content must stay inside viewport on x axis", file: file, line: line)
        XCTAssertTrue(insideY, "content must stay inside viewport on y axis", file: file, line: line)
    }

    /// 画布内容 800×600，安全创作区居中且比内容小（模拟左右面板各占 100）。
    private func centeredState() -> KCCanvasViewportState {
        let contentSize = CGSize(width: 800.0, height: 600.0)
        // 创作区：x∈[100,700]，y∈[80,520]，中心 (400, 300)。
        let viewportRect = CGRect(x: 100.0, y: 80.0, width: 600.0, height: 440.0)
        return KCCanvasViewportState(contentSize: contentSize, viewportRect: viewportRect)
    }

    // MARK: - 默认视图与居中

    func testDefaultStateCentersContentOnSafeAreaCenter() {
        let state = centeredState().defaultState
        // 内容中心 (400,300) 经默认变换后应落在创作区中心 (400,300)。
        let projected = state.viewPoint(forCanvasPoint: CGPoint(x: 400.0, y: 300.0))
        assertPointEqual(projected, CGPoint(x: 400.0, y: 300.0), accuracy: 1e-6)
        XCTAssertTrue(state.isDefault)
    }

    func testDefaultCentersOnSafeAreaCenterNotScreenCenter() {
        // 创作区中心偏左上时（右侧/底部面板更宽），默认平移应随之偏移，
        // 而不是把内容对齐到内容几何中心（即平移非 0）。
        let contentSize = CGSize(width: 800.0, height: 600.0)
        let viewportRect = CGRect(x: 60.0, y: 60.0, width: 500.0, height: 400.0)
        let state = KCCanvasViewportState(contentSize: contentSize, viewportRect: viewportRect).defaultState
        let projectedCenter = state.viewPoint(forCanvasPoint: CGPoint(x: 400.0, y: 300.0))
        assertPointEqual(projectedCenter, CGPoint(x: viewportRect.midX, y: viewportRect.midY), accuracy: 1e-6)
        // 默认平移显然不为 0（创作区中心 != 内容中心）。
        XCTAssertTrue(state.translation.x != 0.0 || state.translation.y != 0.0)
    }

    // MARK: - isDefault

    func testFreshZeroTranslationIsNotDefaultWhenSafeAreaOffset() {
        let contentSize = CGSize(width: 800.0, height: 600.0)
        let viewportRect = CGRect(x: 60.0, y: 60.0, width: 500.0, height: 400.0)
        let offset = KCCanvasViewportState(contentSize: contentSize, viewportRect: viewportRect)
        XCTAssertFalse(offset.isDefault)
    }

    func testIsDefaultFalseAfterZoom() {
        var state = centeredState().defaultState
        XCTAssertTrue(state.isDefault)
        state = state.applyingScale(2.0, aroundViewPoint: CGPoint(x: 400.0, y: 300.0))
        XCTAssertFalse(state.isDefault)
    }

    func testIsDefaultFalseAfterPan() {
        var state = centeredState().defaultState
        state = state.translating(by: CGPoint(x: 40.0, y: 30.0))
        XCTAssertFalse(state.isDefault)
    }

    func testResettingToDefaultReturnsToDefault() {
        var state = centeredState().defaultState
        state = state.applyingScale(2.4, aroundViewPoint: CGPoint(x: 200.0, y: 150.0))
        state = state.translating(by: CGPoint(x: -60.0, y: 80.0))
        XCTAssertFalse(state.isDefault)
        state = state.resettingToDefault()
        XCTAssertTrue(state.isDefault)
    }

    // MARK: - 缩放钳制

    func testScaleClampedToRange() {
        XCTAssertEqual(KCCanvasViewportState.clampedScale(0.1), 0.5, accuracy: 1e-9)
        XCTAssertEqual(KCCanvasViewportState.clampedScale(10.0), 3.0, accuracy: 1e-9)
        XCTAssertEqual(KCCanvasViewportState.clampedScale(1.7), 1.7, accuracy: 1e-9)
    }

    func testApplyingScaleNeverExceedsRange() {
        var state = centeredState().defaultState
        state = state.applyingScale(10.0, aroundViewPoint: CGPoint(x: 400.0, y: 300.0))
        XCTAssertEqual(state.scale, 3.0, accuracy: 1e-9)
        state = state.applyingScale(0.001, aroundViewPoint: CGPoint(x: 400.0, y: 300.0))
        XCTAssertEqual(state.scale, 0.5, accuracy: 1e-9)
    }

    // MARK: - 坐标转换

    func testPointConversionRoundTrips() {
        let state = centeredState().defaultState
        let canvasPoint = CGPoint(x: 123.0, y: 217.0)
        let screen = state.viewPoint(forCanvasPoint: canvasPoint)
        assertPointEqual(state.canvasPoint(forViewPoint: screen), canvasPoint, accuracy: 1e-6)
    }

    func testPointConversionUnderZoom() {
        var state = centeredState().defaultState
        state = state.applyingScale(2.0, aroundViewPoint: CGPoint(x: 400.0, y: 300.0))
        // 内容原点 (0,0) 在 2 倍缩放下的屏幕位置再反解回内容坐标应仍为原点。
        let origin = state.viewPoint(forCanvasPoint: .zero)
        assertPointEqual(state.canvasPoint(forViewPoint: origin), .zero, accuracy: 1e-6)
    }

    func testAffineTransformMatchesDefinition() {
        let state = KCCanvasViewportState(
            contentSize: CGSize(width: 100.0, height: 100.0),
            viewportRect: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0),
            scale: 2.0,
            translation: CGPoint(x: 10.0, y: -5.0)
        )
        let transform = state.affineTransform
        // CGAffineTransform(a,b,c,d,tx,ty)：x' = x*a + y*c + tx
        XCTAssertEqual(transform.a, 2.0, accuracy: 1e-9)
        XCTAssertEqual(transform.d, 2.0, accuracy: 1e-9)
        XCTAssertEqual(transform.tx, 10.0, accuracy: 1e-9)
        XCTAssertEqual(transform.ty, -5.0, accuracy: 1e-9)
        let projected = CGPoint(x: 3.0, y: 4.0).applying(transform)
        XCTAssertEqual(projected.x, 3.0 * 2.0 + 10.0, accuracy: 1e-9)
        XCTAssertEqual(projected.y, 4.0 * 2.0 - 5.0, accuracy: 1e-9)
    }

    // MARK: - 围绕焦点缩放

    func testZoomAroundFocusKeepsFocusStableBeforeClamp() {
        // 用对称创作区保证默认平移为 0，焦点稳定不被钳制干扰。
        let contentSize = CGSize(width: 800.0, height: 600.0)
        let viewportRect = CGRect(x: 0.0, y: 0.0, width: 800.0, height: 600.0)
        var state = KCCanvasViewportState(contentSize: contentSize, viewportRect: viewportRect)
        let focus = CGPoint(x: 250.0, y: 180.0)
        state = state.applyingScale(2.0, aroundViewPoint: focus)
        // 焦点下的内容点在新视口下应仍投影到焦点。
        let projected = state.viewPoint(forCanvasPoint: state.canvasPoint(forViewPoint: focus))
        assertPointEqual(projected, focus, accuracy: 1e-6)
    }

    // MARK: - 平移钳制

    func testPanClampedWhenContentLargerThanViewport() {
        let contentSize = CGSize(width: 800.0, height: 600.0)
        let viewportRect = CGRect(x: 100.0, y: 80.0, width: 600.0, height: 440.0)
        var state = KCCanvasViewportState(contentSize: contentSize, viewportRect: viewportRect, scale: 2.0)
        // scale 2 → 内容 1600×1200 > 创作区 600×440；x 钳制范围 [700-1600, 100] = [-900, 100]。
        state = state.translating(by: CGPoint(x: 5000.0, y: 5000.0))
        XCTAssertEqual(state.translation.x, 100.0, accuracy: 1e-6)
        XCTAssertEqual(state.translation.y, 80.0, accuracy: 1e-6)
        state = state.translating(by: CGPoint(x: -5000.0, y: -5000.0))
        XCTAssertEqual(state.translation.x, -900.0, accuracy: 1e-6)
        XCTAssertEqual(state.translation.y, viewportRect.maxY - contentSize.height * 2.0, accuracy: 1e-6)
    }

    func testPanKeepsContentFullyInsideViewportWhenSmaller() {
        // 缩小态（内容 < 创作区）：T107 后不再强制吸回中心，而是允许用户在创作区内滑动画纸，
        // 但画纸完全留在创作区内、不移出创作区、不压到工具轨/面板。
        // 范围 [viewportMin, viewportMax - 内容尺寸]：内容 200，创作区 800×600。
        let contentSize = CGSize(width: 200.0, height: 200.0)
        let viewportRect = CGRect(x: 0.0, y: 0.0, width: 800.0, height: 600.0)
        var state = KCCanvasViewportState(contentSize: contentSize, viewportRect: viewportRect, scale: 1.0)
        // 向右下大幅平移：x 钳到上界 viewportMax - 内容尺寸 = 800-200 = 600，y 钳到 600-200 = 400。
        state = state.translating(by: CGPoint(x: 9999.0, y: 9999.0))
        XCTAssertEqual(state.translation.x, viewportRect.maxX - contentSize.width, accuracy: 1e-6)
        XCTAssertEqual(state.translation.y, viewportRect.maxY - contentSize.height, accuracy: 1e-6)
        assertContentInsideViewport(state)
        // 向左上大幅平移：钳到下界 viewportMin = 0（内容原点对齐创作区左上沿）。
        state = state.translating(by: CGPoint(x: -99999.0, y: -99999.0))
        XCTAssertEqual(state.translation.x, viewportRect.minX, accuracy: 1e-6)
        XCTAssertEqual(state.translation.y, viewportRect.minY, accuracy: 1e-6)
        assertContentInsideViewport(state)
    }

    // MARK: - 缩小态平移（T107）

    func testScaledDownPanNotForcedToCenter() {
        // PRD 最低验收项：scale < 1.0 时也必须允许双指拖拽移动画纸，不能强制吸回中心。
        // scale=0.75 让缩放后内容（300×225）小于创作区（800×600）。用户主动平移后，
        // translation 应被保留（非 0、非默认居中），且画纸完全留在创作区内。
        let contentSize = CGSize(width: 400.0, height: 300.0)
        let viewportRect = CGRect(x: 0.0, y: 0.0, width: 800.0, height: 600.0)
        let scale: CGFloat = 0.75
        let centered = KCCanvasViewportState(contentSize: contentSize, viewportRect: viewportRect)
            .defaultTranslation(forScale: scale)
        // 用户主动把画纸向右下平移。
        var state = KCCanvasViewportState(
            contentSize: contentSize,
            viewportRect: viewportRect,
            scale: scale,
            translation: CGPoint(x: centered.x + 120.0, y: centered.y + 90.0)
        ).clamped
        // 不会被强制吸回中心，也未被归零。
        XCTAssertFalse(abs(state.translation.x - centered.x) < 1.0 && abs(state.translation.y - centered.y) < 1.0)
        XCTAssertTrue(abs(state.translation.x) > 1.0 || abs(state.translation.y) > 1.0)
        assertContentInsideViewport(state)

        // 再模拟一次双指平移：translation 继续变化、仍不吸回中心、画纸仍完全在创作区内。
        let beforePan = state.translation
        state = state.translating(by: CGPoint(x: 60.0, y: 40.0))
        XCTAssertTrue(abs(state.translation.x - beforePan.x) > 1.0 || abs(state.translation.y - beforePan.y) > 1.0)
        XCTAssertFalse(abs(state.translation.x - centered.x) < 1.0 && abs(state.translation.y - centered.y) < 1.0)
        assertContentInsideViewport(state)
    }

    func testDefaultCenteringUnchangedByScaledDownClamp() {
        // T107 只放宽缩小态的“主动平移”钳制边界，不改变默认居中策略：
        // defaultState / resettingToDefault() 始终回到 scale 1.0 + 内容中心对齐创作区中心，
        // 且该路径直接给出居中平移量、不经过缩小态钳制分支。
        let contentSize = CGSize(width: 400.0, height: 300.0)
        let viewportRect = CGRect(x: 100.0, y: 80.0, width: 600.0, height: 440.0)
        let centeredAtOne = KCCanvasViewportState(contentSize: contentSize, viewportRect: viewportRect)
            .defaultTranslation(forScale: 1.0)
        // 从一个缩小态 + 已大幅平移的状态恢复默认。
        let restored = KCCanvasViewportState(
            contentSize: contentSize,
            viewportRect: viewportRect,
            scale: 0.75,
            translation: CGPoint(x: 9999.0, y: -9999.0)
        ).resettingToDefault()
        XCTAssertEqual(restored.scale, 1.0, accuracy: 1e-9)
        assertPointEqual(restored.translation, centeredAtOne, accuracy: 1e-6)
        XCTAssertTrue(restored.isDefault)
        // 缩小态本身不是默认视图（isDefault 要求 scale == 1）。
        let scaledDown = KCCanvasViewportState(
            contentSize: contentSize,
            viewportRect: viewportRect,
            scale: 0.75,
            translation: centeredAtOne
        )
        XCTAssertFalse(scaledDown.isDefault)
    }

    func testContentAlwaysCoversViewportWhenLargerAfterClamp() {
        // 内容大于创作区时，钳制后创作区四角都不应露出空隙（内容始终覆盖创作区）。
        let contentSize = CGSize(width: 800.0, height: 600.0)
        let viewportRect = CGRect(x: 100.0, y: 80.0, width: 600.0, height: 440.0)
        let scale: CGFloat = 2.0
        var state = KCCanvasViewportState(contentSize: contentSize, viewportRect: viewportRect, scale: scale)
        state = state.translating(by: CGPoint(x: 1234.0, y: -4321.0))
        let projectedOrigin = state.viewPoint(forCanvasPoint: .zero)
        let projectedFar = state.viewPoint(forCanvasPoint: CGPoint(x: contentSize.width, y: contentSize.height))
        XCTAssertLessThanOrEqual(projectedOrigin.x, viewportRect.minX + 1e-6)
        XCTAssertLessThanOrEqual(projectedOrigin.y, viewportRect.minY + 1e-6)
        XCTAssertGreaterThanOrEqual(projectedFar.x, viewportRect.maxX - 1e-6)
        XCTAssertGreaterThanOrEqual(projectedFar.y, viewportRect.maxY - 1e-6)
    }

    // MARK: - 退化与边界

    func testEmptyViewportRectKeepsTranslationUnclamped() {
        let contentSize = CGSize(width: 800.0, height: 600.0)
        let state = KCCanvasViewportState(
            contentSize: contentSize,
            viewportRect: .zero,
            scale: 1.0,
            translation: CGPoint(x: 42.0, y: -7.0)
        )
        XCTAssertEqual(state.clampedTranslation.x, 42.0, accuracy: 1e-9)
        XCTAssertEqual(state.clampedTranslation.y, -7.0, accuracy: 1e-9)
    }
}
