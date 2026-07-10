//
//  KCBrushPreset.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/07/08.
//

import Foundation
import KCDomain

/// 画笔对倾角的响应程度。
public enum KCBrushTiltResponse: String, Sendable, Equatable {
    /// 不响应倾角，dab 始终正圆（钢笔）。
    case none
    /// 强响应：低 altitude 显著压扁成椭圆侧锋（铅笔）。
    case pencil
    /// 轻微响应：只有一点点扁度（蜡笔）。
    case mild
}

/// 一支画笔的完整 dab 行为配置。
///
/// 描述间距、半径曲线、不透明度、流量、硬度、抖动、纸纹强度、纹理种子、
/// 倾角行为以及速度对间距/流量的影响。三种一期画笔（铅笔/钢笔/蜡笔）通过
/// `preset(for:)` 获得产品化默认值；测试与上层也可用 `init` 自定义。
public struct KCBrushPreset: Sendable, Equatable {
    /// 最小半径（点，轻压）。
    public var radiusMin: Double
    /// 最大半径（点，满压）。
    public var radiusMax: Double
    /// 半径随压力的曲线指数（gamma）。>1 轻压更细，<1 轻压更粗。
    public var radiusCurve: Double
    /// 相邻 dab 间距 = 半径 × spacingFactor。
    public var spacingFactor: Double
    /// 单 dab 不透明度上限。
    public var opacity: Double
    /// 单 dab 基础流量。
    public var flow: Double
    /// 压力对流量的影响强度（0=不随压力变，1=轻压几乎无流量）。
    public var flowPressureScale: Double
    /// 边缘硬度（0…1）。
    public var hardness: Double
    /// 位置抖动幅度（相对半径）。
    public var jitter: Double
    /// 纸纹/蜡纹强度（0…1）。
    public var textureStrength: Double
    /// 纹理种子，决定可重放的颗粒与抖动。
    public var textureSeed: UInt64
    /// 倾角塑形行为。
    public var tiltResponse: KCBrushTiltResponse
    /// 速度对间距的放大系数（velT 0…1）。
    public var velocityToSpacing: Double
    /// 速度对流量的削弱系数（velT 0…1）。
    public var velocityToFlow: Double
    /// 用户画笔尺寸（lineWidth，点）的参考值：当 lineWidth == referenceLineWidth 时，
    /// `scaledForLineWidth(_:)` 的缩放为 1.0（即 preset 原始半径）。各风格取产品默认 slider 值。
    public var referenceLineWidth: Double

    public init(
        radiusMin: Double,
        radiusMax: Double,
        radiusCurve: Double,
        spacingFactor: Double,
        opacity: Double,
        flow: Double,
        flowPressureScale: Double,
        hardness: Double,
        jitter: Double,
        textureStrength: Double,
        textureSeed: UInt64,
        tiltResponse: KCBrushTiltResponse,
        velocityToSpacing: Double,
        velocityToFlow: Double,
        referenceLineWidth: Double = 12.0
    ) {
        self.radiusMin = radiusMin
        self.radiusMax = radiusMax
        self.radiusCurve = radiusCurve
        self.spacingFactor = spacingFactor
        self.opacity = opacity
        self.flow = flow
        self.flowPressureScale = flowPressureScale
        self.hardness = hardness
        self.jitter = jitter
        self.textureStrength = textureStrength
        self.textureSeed = textureSeed
        self.tiltResponse = tiltResponse
        self.velocityToSpacing = velocityToSpacing
        self.velocityToFlow = velocityToFlow
        self.referenceLineWidth = referenceLineWidth
    }

    /// 按「用户画笔尺寸（lineWidth）」缩放本预设的半径（`radiusMin`/`radiusMax`），
    /// 让铅笔/蜡笔的尺寸 slider 真正生效（T111）。缩放比例 = `lineWidth / referenceLineWidth`，
    /// 钳制到 `[0.2, 3.0]`；半径下限 `0.15`，避免退化。其余属性（间距/流量/纹理/曲线…）保持不变。
    public func scaledForLineWidth(_ lineWidth: Double) -> KCBrushPreset {
        let safeReference = max(1.0, referenceLineWidth)
        let scale = min(3.0, max(0.2, lineWidth / safeReference))
        var scaled = self
        scaled.radiusMin = max(0.15, radiusMin * scale)
        scaled.radiusMax = max(0.15, radiusMax * scale)
        return scaled
    }

    /// 按画笔风格返回产品化预设。
    ///
    /// - 铅笔：小半径、低流量、gamma>1（轻压更细更淡）、强倾角侧锋、中低抖动。
    /// - 钢笔：近恒定半径、高不透明/流量、无纹理无抖动、不响应倾角。
    /// - 蜡笔：大半径、高纸纹强度、高抖动、大间距（蜡块断续）、轻微倾角。
    public static func preset(for style: KCBrushStyle) -> KCBrushPreset {
        switch style {
        case .pencil:
            return KCBrushPreset(
                radiusMin: 0.9,
                radiusMax: 4.2,
                radiusCurve: 1.7,
                spacingFactor: 0.14,
                opacity: 0.55,
                flow: 0.45,
                flowPressureScale: 0.65,
                hardness: 0.5,
                jitter: 0.05,
                textureStrength: 0.45,
                textureSeed: 0x4F3C_2D11_8A77_B5E0,
                tiltResponse: .pencil,
                velocityToSpacing: 0.6,
                velocityToFlow: 0.25,
                referenceLineWidth: 12.0
            )
        case .pen:
            return KCBrushPreset(
                radiusMin: 2.6,
                radiusMax: 3.4,
                radiusCurve: 0.6,
                spacingFactor: 0.06,
                opacity: 0.98,
                flow: 0.95,
                flowPressureScale: 0.05,
                hardness: 0.95,
                jitter: 0.0,
                textureStrength: 0.0,
                textureSeed: 0x91B2_4E07_D330_A6F5,
                tiltResponse: .none,
                velocityToSpacing: 0.15,
                velocityToFlow: 0.05,
                referenceLineWidth: 9.0
            )
        case .crayon:
            return KCBrushPreset(
                radiusMin: 4.5,
                radiusMax: 11.0,
                radiusCurve: 1.25,
                spacingFactor: 0.22,
                opacity: 0.5,
                flow: 0.6,
                flowPressureScale: 0.55,
                hardness: 0.32,
                jitter: 0.18,
                textureStrength: 0.9,
                textureSeed: 0x1C7A_55E0_BB19_4023,
                tiltResponse: .mild,
                velocityToSpacing: 0.4,
                velocityToFlow: 0.15,
                referenceLineWidth: 18.0
            )
        }
    }
}
