//
//  KCBrushDabGeneratorTests.swift
//  KCDrawingEngineTests
//
//  Created by 小大 on 2026/07/08.
//

import XCTest
@testable import KCDrawingEngine
import KCDomain
import CoreGraphics

/// T093：专业画笔 dab 引擎的纯单元测试。
///
/// 覆盖看板 TDD 硬要求：压力、速度、倾角、间距、确定性 seed。
/// 这些测试只驱动纯 Swift/UIKit-free 引擎，不涉及 UIKit 光栅化（T094）。
final class KCBrushDabGeneratorTests: XCTestCase {

    private static let vertical = Double.pi / 2.0

    /// 构造一个输入采样，方便测试只指定关键字段。
    private func sample(
        x: Double,
        y: Double,
        pressure: Double = 1.0,
        velocity: Double = 0.0,
        altitude: Double = KCBrushDabGeneratorTests.vertical,
        azimuth: Double = 0.0,
        isPencil: Bool = true,
        timestamp: TimeInterval = 0
    ) -> KCBrushInputSample {
        KCBrushInputSample(
            point: CGPoint(x: x, y: y),
            timestamp: timestamp,
            pressure: pressure,
            velocity: velocity,
            altitude: altitude,
            azimuth: azimuth,
            isPencil: isPencil
        )
    }

    private func line(samples: Int, spacing: Double, pressure: Double = 1.0) -> [KCBrushInputSample] {
        (0..<samples).map { index in
            sample(x: Double(index) * spacing, y: 0, pressure: pressure, timestamp: Double(index) * 0.016)
        }
    }

    // MARK: - 基础形态

    func testSingleSampleEmitsExactlyOneDab() {
        let generator = KCBrushDabGenerator(preset: .preset(for: .pen))
        let dabs = generator.dabs(for: [sample(x: 5, y: 5)])
        XCTAssertEqual(dabs.count, 1)
    }

    func testDabCenterMatchesSamplePoint() {
        // 钢笔 jitter 为 0，单采样的 dab 中心必须严格落在采样点上。
        let generator = KCBrushDabGenerator(preset: .preset(for: .pen))
        let dabs = generator.dabs(for: [sample(x: 10, y: 20)])
        XCTAssertEqual(dabs.count, 1)
        XCTAssertEqual(dabs.first?.center, CGPoint(x: 10, y: 20))
    }

    func testEmptySamplesProduceNoDabs() {
        let generator = KCBrushDabGenerator(preset: .preset(for: .pencil))
        XCTAssertTrue(generator.dabs(for: []).isEmpty)
    }

    // MARK: - 压力 → 半径 / 流量

    func testHigherPressureYieldsLargerRadius() {
        let generator = KCBrushDabGenerator(preset: .preset(for: .pencil))
        let light = generator.dabs(for: [sample(x: 0, y: 0, pressure: 0.2)]).first?.radius ?? 0
        let heavy = generator.dabs(for: [sample(x: 0, y: 0, pressure: 1.0)]).first?.radius ?? 0
        XCTAssertGreaterThan(heavy, light)
    }

    func testPencilLowPressureStaysFaint() {
        // 铅笔轻压必须保持淡（低 flow / 低 alpha），不能变成马克笔。
        let generator = KCBrushDabGenerator(preset: .preset(for: .pencil))
        let dab = generator.dabs(for: [sample(x: 0, y: 0, pressure: 0.15)]).first!
        XCTAssertLessThan(dab.flow, 0.30)
        XCTAssertLessThanOrEqual(dab.alpha, 0.60)
    }

    func testPencilHighPressureStillLighterThanPen() {
        // 即便满压，铅笔也不应比钢笔更实，避免重压退化成墨水笔。
        let pencilGen = KCBrushDabGenerator(preset: .preset(for: .pencil))
        let penGen = KCBrushDabGenerator(preset: .preset(for: .pen))
        let pencil = pencilGen.dabs(for: [sample(x: 0, y: 0, pressure: 1.0)]).first!
        let pen = penGen.dabs(for: [sample(x: 0, y: 0, pressure: 1.0)]).first!
        XCTAssertLessThan(pencil.alpha, pen.alpha)
    }

    func testPenDabsNearSolidLowJitterRound() {
        // 钢笔：高不透明、无抖动、正圆。
        let generator = KCBrushDabGenerator(preset: .preset(for: .pen))
        let dab = generator.dabs(for: [sample(x: 0, y: 0, pressure: 1.0)]).first!
        XCTAssertGreaterThan(dab.alpha, 0.90)
        XCTAssertEqual(dab.aspectRatio, 1.0, accuracy: 1e-9)
        XCTAssertEqual(dab.center, CGPoint(x: 0, y: 0))
    }

    func testCrayonDabsHaveHigherTextureAndJitterThanPencil() {
        // 蜡笔的纸纹强度和抖动必须明显大于铅笔。
        let pencil = KCBrushPreset.preset(for: .pencil)
        let crayon = KCBrushPreset.preset(for: .crayon)
        XCTAssertGreaterThan(crayon.textureStrength, pencil.textureStrength)
        XCTAssertGreaterThan(crayon.jitter, pencil.jitter)
    }

    func testCrayonJitterIsBoundedForZoomStableGeometry() {
        let preset = KCBrushPreset.preset(for: .crayon)
        XCTAssertEqual(preset.jitter, 0.06, accuracy: 1e-9)

        let input = sample(x: 100, y: 100, pressure: 1.0)
        let dab = KCBrushDabGenerator(preset: preset).dabs(for: [input]).first!
        let offset = hypot(dab.center.x - input.point.x, dab.center.y - input.point.y)
        XCTAssertLessThanOrEqual(offset, dab.radius * 0.06 + 1e-9)
    }

    func testNonFiniteTiltFallsBackToStableRoundDab() {
        let input = sample(x: 0, y: 0, altitude: .nan, azimuth: .infinity)
        let dab = KCBrushDabGenerator(preset: .preset(for: .crayon)).dabs(for: [input]).first!

        XCTAssertTrue(dab.radius.isFinite)
        XCTAssertTrue(dab.rotation.isFinite)
        XCTAssertEqual(dab.aspectRatio, 1.0, accuracy: 1e-9)
    }

    func testNonFiniteInputProducesFiniteDabGeometry() {
        let input = sample(
            x: .nan,
            y: .infinity,
            pressure: .nan,
            velocity: .infinity,
            altitude: -.infinity,
            azimuth: .nan,
            timestamp: .infinity
        )
        let dab = KCBrushDabGenerator(preset: .preset(for: .crayon)).dabs(for: [input]).first!

        XCTAssertTrue(dab.center.x.isFinite)
        XCTAssertTrue(dab.center.y.isFinite)
        XCTAssertTrue(dab.radius.isFinite)
        XCTAssertTrue(dab.rotation.isFinite)
        XCTAssertTrue(dab.aspectRatio.isFinite)
    }

    // MARK: - 间距

    func testTwoSamplesEmitEvenlySpacedDabs() {
        // 钢笔 jitter 为 0，所有 dab 应严格落在两点连线上，且数量与 D/spacing 相当。
        let generator = KCBrushDabGenerator(preset: .preset(for: .pen))
        let dabs = generator.dabs(for: [sample(x: 0, y: 0), sample(x: 40, y: 0)])
        XCTAssertGreaterThanOrEqual(dabs.count, 2)

        // 全部 dab 必须在连线段内，y 为 0，x 单调。
        for dab in dabs {
            XCTAssertEqual(dab.center.y, 0, accuracy: 1e-9)
            XCTAssertGreaterThanOrEqual(dab.center.x, -1e-9)
            XCTAssertLessThanOrEqual(dab.center.x, 40 + 1e-9)
        }
        let xs = dabs.map { $0.center.x }
        XCTAssertEqual(xs, xs.sorted(), "dabs must be ordered along the path")

        // 数量与 D/spacing 一致（允许 ±2 的端点误差）。
        let pen = KCBrushPreset.preset(for: .pen)
        let radius = pen.radiusMax
        let spacing = radius * pen.spacingFactor
        let expected = Int(40.0 / spacing)
        XCTAssertGreaterThanOrEqual(dabs.count, expected)
        XCTAssertLessThanOrEqual(dabs.count, expected + 2)
    }

    func testLargerRadiusYieldsFewerDabsPerLength() {
        // 蜡笔半径与间距远大于钢笔，同长度下 dab 数量更少。
        let penGen = KCBrushDabGenerator(preset: .preset(for: .pen))
        let crayonGen = KCBrushDabGenerator(preset: .preset(for: .crayon))
        let samples = [sample(x: 0, y: 0), sample(x: 40, y: 0)]
        XCTAssertLessThan(crayonGen.dabs(for: samples).count, penGen.dabs(for: samples).count)
    }

    // MARK: - 速度

    func testHighVelocityIncreasesSpacing() {
        // 相同几何下，高速采样的 dab 更稀疏（数量更少）。
        let generator = KCBrushDabGenerator(preset: .preset(for: .pen))
        let samples = [sample(x: 0, y: 0), sample(x: 40, y: 0)]
        let slow = generator.dabs(for: samples.map { $0.withVelocity(0) }).count
        let fast = generator.dabs(for: samples.map { $0.withVelocity(2000) }).count
        XCTAssertLessThan(fast, slow)
    }

    func testHighVelocityReducesFlow() {
        // 铅笔高速时流量应下降。
        let generator = KCBrushDabGenerator(preset: .preset(for: .pencil))
        let slow = generator.dabs(for: [sample(x: 0, y: 0, pressure: 1.0, velocity: 0)]).first!.flow
        let fast = generator.dabs(for: [sample(x: 0, y: 0, pressure: 1.0, velocity: 2000)]).first!.flow
        XCTAssertLessThan(fast, slow)
    }

    // MARK: - 倾角

    func testLowAltitudeFlattensPencilAspect() {
        // Pencil 低 altitude（接近平放）→ dab 被压扁成椭圆；垂直时为正圆。
        let generator = KCBrushDabGenerator(preset: .preset(for: .pencil))
        let flat = generator.dabs(for: [sample(x: 0, y: 0, altitude: 0.02)]).first!.aspectRatio
        let upright = generator.dabs(for: [sample(x: 0, y: 0, altitude: KCBrushDabGeneratorTests.vertical)]).first!.aspectRatio
        XCTAssertGreaterThan(flat, 1.3)
        XCTAssertEqual(upright, 1.0, accuracy: 1e-9)
    }

    func testFingerSampleIgnoresTiltForAspect() {
        // 手指（非 Pencil）即使 altitude 很低也不应产生倾角塑形，保持正圆。
        let generator = KCBrushDabGenerator(preset: .preset(for: .pencil))
        let dab = generator.dabs(for: [sample(x: 0, y: 0, altitude: 0.02, isPencil: false)]).first!
        XCTAssertEqual(dab.aspectRatio, 1.0, accuracy: 1e-9)
    }

    // MARK: - 确定性

    func testIncrementalBatchesExactlyMatchFullGeneration() {
        let samples = line(samples: 80, spacing: 3.0)
        let generator = KCBrushDabGenerator(preset: .preset(for: .crayon))
        let expected = generator.dabs(for: samples)
        var state = KCBrushDabGenerationState()
        var actual: [KCBrushDab] = []

        for batch in samples.chunked(sizes: [1, 3, 7, 2, 11]) {
            actual.append(contentsOf: generator.appendDabs(for: batch, state: &state))
        }

        XCTAssertEqual(actual, expected)
    }

    func testIncrementalDuplicateSamplesMatchFullGeneration() {
        let samples = [
            sample(x: 0, y: 0),
            sample(x: 0, y: 0),
            sample(x: 12, y: 0)
        ]
        let generator = KCBrushDabGenerator(preset: .preset(for: .pencil))
        var state = KCBrushDabGenerationState()
        let actual = samples.flatMap { generator.appendDabs(for: [$0], state: &state) }

        XCTAssertEqual(actual, generator.dabs(for: samples))
    }

    func testIdenticalInputsProduceIdenticalDabs() {
        let generator = KCBrushDabGenerator(preset: .preset(for: .crayon))
        let samples = line(samples: 20, spacing: 3.0)
        let first = generator.dabs(for: samples)
        let second = generator.dabs(for: samples)
        XCTAssertEqual(first, second, "same inputs must produce identical dab sequences including seeds")
    }

    func testDifferentTextureSeedChangesDabSeeds() {
        var preset = KCBrushPreset.preset(for: .pencil)
        let originalSeed = preset.textureSeed
        let genA = KCBrushDabGenerator(preset: preset)
        preset.textureSeed = originalSeed &+ 0x9E37_79B9_7F4A_7C15
        let genB = KCBrushDabGenerator(preset: preset)

        let samples = line(samples: 5, spacing: 4.0)
        let seedsA = genA.dabs(for: samples).map(\.seed)
        let seedsB = genB.dabs(for: samples).map(\.seed)
        XCTAssertEqual(seedsA.count, seedsB.count)
        XCTAssertFalse(seedsA == seedsB, "different texture seeds must change dab seeds")
    }

    func testDabsOrderedAlongPath() {
        // 钢笔 jitter 0，沿 +x 折线的 dab 中心必须按 x 单调推进。
        let generator = KCBrushDabGenerator(preset: .preset(for: .pen))
        let dabs = generator.dabs(for: [sample(x: 0, y: 0), sample(x: 50, y: 0), sample(x: 100, y: 0)])
        let xs = dabs.map { $0.center.x }
        for index in 1..<xs.count {
            XCTAssertGreaterThanOrEqual(xs[index], xs[index - 1] - 1e-9, "dabs must not jump backward along the path")
        }
        XCTAssertLessThan(xs.first ?? -1, xs.last ?? -1)
    }

    // MARK: - canvasScale

    func testCanvasScaleScalesRadius() {
        let small = KCBrushDabGenerator(preset: .preset(for: .pencil), canvasScale: 1.0)
        let large = KCBrushDabGenerator(preset: .preset(for: .pencil), canvasScale: 2.0)
        let r1 = small.dabs(for: [sample(x: 0, y: 0, pressure: 1.0)]).first!.radius
        let r2 = large.dabs(for: [sample(x: 0, y: 0, pressure: 1.0)]).first!.radius
        XCTAssertEqual(r2, r1 * 2.0, accuracy: 1e-9)
    }

    // MARK: - 尺寸（T111：铅笔/蜡笔尺寸 slider 生效）

    func testScaledForLineWidthScalesRadiusProportionally() {
        let base = KCBrushPreset.preset(for: .pencil)
        // referenceLineWidth 时缩放为 1.0，半径不变。
        let atReference = base.scaledForLineWidth(base.referenceLineWidth)
        XCTAssertEqual(atReference.radiusMax, base.radiusMax, accuracy: 1e-9)
        XCTAssertEqual(atReference.radiusMin, base.radiusMin, accuracy: 1e-9)
        // 更大尺寸 → 更大半径；更小尺寸 → 更小半径。
        let bigger = base.scaledForLineWidth(base.referenceLineWidth * 2.0)
        let smaller = base.scaledForLineWidth(base.referenceLineWidth / 2.0)
        XCTAssertGreaterThan(bigger.radiusMax, base.radiusMax)
        XCTAssertLessThan(smaller.radiusMax, base.radiusMax)
        // 半径以外的属性（间距/纹理/曲线…）不随尺寸变化。
        XCTAssertEqual(bigger.spacingFactor, base.spacingFactor)
        XCTAssertEqual(bigger.textureStrength, base.textureStrength)
        XCTAssertEqual(bigger.radiusCurve, base.radiusCurve)
    }

    func testScaledForLineWidthClampsExtremes() {
        let base = KCBrushPreset.preset(for: .crayon)
        // 过大 → 钳到 3.0 倍；过小 → 钳到 0.2 倍；半径下限 0.15。
        let huge = base.scaledForLineWidth(1_000_000)
        let tiny = base.scaledForLineWidth(0.0)
        XCTAssertEqual(huge.radiusMax, base.radiusMax * 3.0, accuracy: 1e-9)
        XCTAssertEqual(tiny.radiusMax, base.radiusMax * 0.2, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(huge.radiusMin, 0.15)
        XCTAssertGreaterThanOrEqual(tiny.radiusMin, 0.15)
    }

    func testPencilDabRadiusRespondsToLineWidth() {
        // 同压力下，大尺寸铅笔的 dab 半径必须明显大于小尺寸（修复点）。
        let samples = [sample(x: 0, y: 0, pressure: 1.0)]
        let small = KCBrushDabGenerator(preset: .preset(for: .pencil).scaledForLineWidth(4.0)).dabs(for: samples).first!.radius
        let large = KCBrushDabGenerator(preset: .preset(for: .pencil).scaledForLineWidth(36.0)).dabs(for: samples).first!.radius
        XCTAssertGreaterThan(large / max(small, 1e-9), 3.0)
    }

    func testCrayonDabRadiusRespondsToLineWidth() {
        let samples = [sample(x: 0, y: 0, pressure: 1.0)]
        let small = KCBrushDabGenerator(preset: .preset(for: .crayon).scaledForLineWidth(4.0)).dabs(for: samples).first!.radius
        let large = KCBrushDabGenerator(preset: .preset(for: .crayon).scaledForLineWidth(36.0)).dabs(for: samples).first!.radius
        XCTAssertGreaterThan(large / max(small, 1e-9), 3.0)
    }

    func testReferenceLineWidthPerStyleMatchesDefaults() {
        // 各风格的 referenceLineWidth 对应产品默认 slider 值（App clampedBrushWidth 同口径）。
        XCTAssertEqual(KCBrushPreset.preset(for: .pencil).referenceLineWidth, 12.0, accuracy: 1e-9)
        XCTAssertEqual(KCBrushPreset.preset(for: .pen).referenceLineWidth, 9.0, accuracy: 1e-9)
        XCTAssertEqual(KCBrushPreset.preset(for: .crayon).referenceLineWidth, 18.0, accuracy: 1e-9)
    }
}

private extension Array {
    /// 按循环批量大小切分输入，模拟 coalesced touches 的不规则分批。
    func chunked(sizes: [Int]) -> [[Element]] {
        precondition(sizes.allSatisfy { $0 > 0 })
        guard !isEmpty, !sizes.isEmpty else { return [] }

        var batches: [[Element]] = []
        var startIndex = 0
        var sizeIndex = 0
        while startIndex < count {
            let endIndex = Swift.min(startIndex + sizes[sizeIndex % sizes.count], count)
            batches.append(Array(self[startIndex..<endIndex]))
            startIndex = endIndex
            sizeIndex += 1
        }
        return batches
    }
}

private extension KCBrushInputSample {
    /// 测试辅助：替换速度字段。
    func withVelocity(_ velocity: Double) -> KCBrushInputSample {
        KCBrushInputSample(
            point: point,
            timestamp: timestamp,
            pressure: pressure,
            velocity: velocity,
            altitude: altitude,
            azimuth: azimuth,
            isPencil: isPencil
        )
    }
}
