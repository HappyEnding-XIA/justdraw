//
//  KCBrushDabGenerator.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/07/08.
//

import Foundation
import CoreGraphics

/// dab 增量生成状态，用于跨触摸批次延续间距与确定性种子。
public struct KCBrushDabGenerationState: Sendable, Equatable {
    var previousSample: KCBrushInputSample?
    var residualDistance: Double = 0
    var nextDabIndex: UInt64 = 0

    public init() {}
}

/// 画笔 dab 生成器：把连续的高保真输入采样变成稳定、可重放的 dab 序列。
///
/// 这是 T093 的纯引擎核心，UIKit-free。每个 dab 的半径由该采样局部压力按曲线
/// 计算（不再是整条笔画的平均压力）；速度参与间距与流量；Pencil 倾角参与椭圆
/// 形状（手指回退为垂直、正圆）；抖动与纹理种子完全确定性，保证相同输入永远
/// 产出相同序列，供 T094 的 UIKit 渲染在不闪烁地 undo/redo。
///
/// 一期不接入 UIKit 渲染；本类型只输出 `[KCBrushDab]`，由上层（T094）光栅化。
public struct KCBrushDabGenerator: Sendable {
    /// 画笔预设。
    public let preset: KCBrushPreset
    /// 画布缩放，半径与间距会按此缩放（points）。
    public let canvasScale: Double

    /// 速度归一化基准（点/秒）：达到该速度时 velT = 1，间距最大、流量最低。
    private static let velocityReference: Double = 2000.0

    public init(preset: KCBrushPreset, canvasScale: Double = 1.0) {
        self.preset = preset
        self.canvasScale = canvasScale
    }

    /// 对一段连续采样生成 dab 序列。
    public func dabs(for samples: [KCBrushInputSample]) -> [KCBrushDab] {
        var state = KCBrushDabGenerationState()
        return appendDabs(for: samples, state: &state)
    }

    /// 只为新增采样生成 dab，并延续上一批次的间距余量与种子序列。
    public func appendDabs(
        for samples: [KCBrushInputSample],
        state: inout KCBrushDabGenerationState
    ) -> [KCBrushDab] {
        guard !samples.isEmpty else { return [] }

        var output: [KCBrushDab] = []
        var sampleIndex = 0
        var previous: KCBrushInputSample

        if let previousSample = state.previousSample {
            previous = previousSample
        } else {
            let first = stableSample(samples[0])
            appendDab(for: first, dabIndex: &state.nextDabIndex, into: &output)
            state.previousSample = first
            previous = first
            sampleIndex = 1
        }

        // 沿新增折线按间距盖章，跨批次保留余数，保证间距均匀。
        while sampleIndex < samples.count {
            let current = stableSample(samples[sampleIndex])
            let segment = CGPoint(x: current.point.x - previous.point.x,
                                  y: current.point.y - previous.point.y)
            let segmentLength = (segment.x * segment.x + segment.y * segment.y).squareRoot()

            if segmentLength > 0 {
                let velocity = localVelocity(previous: previous, current: current, segmentLength: segmentLength)
                let velocityT = Self.clamp01(velocity / Self.velocityReference)
                let spacing = self.spacing(pressure: midpoint(previous.pressure, current.pressure),
                                           velocityT: velocityT)

                if spacing > 0 {
                    var consumed: Double = 0.0
                    while (spacing - state.residualDistance) <= (segmentLength - consumed) + 1e-9 {
                        consumed += spacing - state.residualDistance
                        let t = consumed / segmentLength
                        let interpolated = KCBrushInputSample(
                            point: CGPoint(x: previous.point.x + segment.x * t,
                                           y: previous.point.y + segment.y * t),
                            timestamp: previous.timestamp + (current.timestamp - previous.timestamp) * t,
                            pressure: previous.pressure + (current.pressure - previous.pressure) * t,
                            velocity: velocity,
                            altitude: previous.altitude + (current.altitude - previous.altitude) * t,
                            azimuth: previous.azimuth + (current.azimuth - previous.azimuth) * t,
                            isPencil: current.isPencil
                        )
                        appendDab(for: interpolated, dabIndex: &state.nextDabIndex, into: &output)
                        state.residualDistance = 0.0
                    }
                    state.residualDistance += segmentLength - consumed
                }
            } else {
                // 与上一点重合：仍按当前采样补一个 dab，保留压力/倾角变化。
                appendDab(for: current, dabIndex: &state.nextDabIndex, into: &output)
            }

            previous = current
            state.previousSample = current
            sampleIndex += 1
        }

        return output
    }

    // MARK: - Dab 合成

    private func appendDab(
        for sample: KCBrushInputSample,
        dabIndex: inout UInt64,
        into output: inout [KCBrushDab]
    ) {
        let pressureT = Self.clamp01(sample.pressure)
        let radius = scaledRadius(pressureT: pressureT)
        let velocityT = Self.clamp01(sample.velocity / Self.velocityReference)
        let flow = Self.clamp01(preset.flow * flowPressureFactor(pressureT) * (1 - preset.velocityToFlow * velocityT))
        let (aspectRatio, rotation) = tiltShape(for: sample)
        let seed = kcBrushDabMix(seed: preset.textureSeed, index: dabIndex)

        var center = sample.point
        let jitterRadius = Self.finite(preset.jitter, fallback: 0) * radius
        if jitterRadius > 0 {
            let jitter = kcBrushDabJitter(hash: seed)
            // 两个独立分量的长度可能超过 1，归一化到单位圆避免实际偏移超过 jitter 合约。
            let jitterLength = max(1.0, hypot(jitter.dx, jitter.dy))
            center.x += jitter.dx / jitterLength * jitterRadius
            center.y += jitter.dy / jitterLength * jitterRadius
        }

        output.append(KCBrushDab(
            center: center,
            radius: radius,
            alpha: preset.opacity,
            flow: flow,
            rotation: rotation,
            aspectRatio: aspectRatio,
            hardness: preset.hardness,
            textureStrength: preset.textureStrength,
            seed: seed
        ))
        dabIndex &+= 1
    }

    // MARK: - 局部公式

    /// 半径 = (radiusMin + (radiusMax-radiusMin) * pow(p, gamma)) * canvasScale。
    private func scaledRadius(pressureT: Double) -> Double {
        let radiusMin = max(0, Self.finite(preset.radiusMin, fallback: 0))
        let radiusMax = max(radiusMin, Self.finite(preset.radiusMax, fallback: radiusMin))
        let radiusCurve = max(0, Self.finite(preset.radiusCurve, fallback: 1))
        let scale = max(0, Self.finite(canvasScale, fallback: 1))
        let span = radiusMax - radiusMin
        let base = radiusMin + span * pow(pressureT, radiusCurve)
        return Self.finite(base * scale, fallback: radiusMin * scale)
    }

    /// 间距 = 半径 * spacingFactor * (1 + velocityToSpacing * velT)。
    private func spacing(pressure: Double, velocityT: Double) -> Double {
        scaledRadius(pressureT: Self.clamp01(pressure)) * preset.spacingFactor * (1 + preset.velocityToSpacing * velocityT)
    }

    /// 流量随压力的缩放：(1-scale) + scale*p。轻压（scale 大时）显著降低流量。
    private func flowPressureFactor(_ pressureT: Double) -> Double {
        (1 - preset.flowPressureScale) + preset.flowPressureScale * pressureT
    }

    /// 由倾角决定 dab 形状；非 Pencil 一律正圆（手指垂直回退）。
    private func tiltShape(for sample: KCBrushInputSample) -> (aspectRatio: Double, rotation: Double) {
        guard sample.isPencil, sample.altitude.isFinite, sample.azimuth.isFinite else {
            return (1.0, 0.0)
        }
        let tiltT = Self.clamp01(1 - sample.altitude / (Double.pi / 2))
        switch preset.tiltResponse {
        case .none:
            return (1.0, 0.0)
        case .pencil:
            return (1.0 + 2.2 * tiltT, sample.azimuth)
        case .mild:
            return (1.0 + 0.35 * tiltT, sample.azimuth)
        }
    }

    /// 相邻采样间的速度：优先用位移/时间，时间差不可用时回退到采样自带速度。
    private func localVelocity(previous: KCBrushInputSample,
                               current: KCBrushInputSample,
                               segmentLength: Double) -> Double {
        let deltaTime = current.timestamp - previous.timestamp
        if deltaTime > 1e-6 {
            return segmentLength / deltaTime
        }
        return max(previous.velocity, current.velocity)
    }

    private func midpoint(_ a: Double, _ b: Double) -> Double {
        (a + b) * 0.5
    }

    /// 在引擎边界收敛异常触摸值，防止 NaN/Infinity 传播到绘制几何。
    private func stableSample(_ sample: KCBrushInputSample) -> KCBrushInputSample {
        let altitudeIsValid = sample.altitude.isFinite
        let azimuthIsValid = sample.azimuth.isFinite
        return KCBrushInputSample(
            point: CGPoint(
                x: Self.finite(sample.point.x, fallback: 0),
                y: Self.finite(sample.point.y, fallback: 0)
            ),
            timestamp: Self.finite(sample.timestamp, fallback: 0),
            pressure: Self.finite(sample.pressure, fallback: 0),
            velocity: max(0, Self.finite(sample.velocity, fallback: 0)),
            altitude: altitudeIsValid && azimuthIsValid ? sample.altitude : Double.pi / 2,
            azimuth: altitudeIsValid && azimuthIsValid ? sample.azimuth : 0,
            isPencil: sample.isPencil
        )
    }

    private static func clamp01(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1.0, max(0.0, value))
    }

    private static func finite<T: BinaryFloatingPoint>(_ value: T, fallback: T) -> T {
        value.isFinite ? value : fallback
    }
}
