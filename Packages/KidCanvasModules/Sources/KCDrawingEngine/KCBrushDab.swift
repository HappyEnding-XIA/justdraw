//
//  KCBrushDab.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/07/08.
//

import Foundation
import CoreGraphics

/// 画笔 dab 引擎输出的单个绘制单元。
///
/// 描述一个 stamp 的几何与绘制参数，足够 UIKit/CoreGraphics 光栅化侧（T094）
/// 把它画成一个柔边椭圆、石墨颗粒或蜡块，而不需要引擎本身接触 UIKit。
/// 所有字段都是确定性可重放的：相同的输入采样与 preset 必须产出相同的 dab。
public struct KCBrushDab: Sendable, Equatable {
    /// dab 中心，画布坐标系（已含确定性抖动偏移）。
    public var center: CGPoint
    /// dab 半径（点，已乘 canvasScale）。
    public var radius: Double
    /// 该 dab 的不透明度（0…1）。
    public var alpha: Double
    /// 该 dab 的流量（0…1）：决定单次叠加的墨量，轻压/高速会降低。
    public var flow: Double
    /// dab 旋转角（弧度），侧锋椭圆时由方位角决定。
    public var rotation: Double
    /// 纵横比（≥1，1 = 正圆）。铅笔低 altitude 时被压扁。
    public var aspectRatio: Double
    /// 边缘硬度（0…1）。钢笔高、蜡笔低。
    public var hardness: Double
    /// 纸纹/蜡纹强度（0…1）。蜡笔高、钢笔为 0。
    public var textureStrength: Double
    /// 确定性纹理种子，供 UIKit 侧复现颗粒，避免 undo/redo 重绘闪烁。
    public var seed: UInt64

    public init(
        center: CGPoint,
        radius: Double,
        alpha: Double,
        flow: Double,
        rotation: Double,
        aspectRatio: Double,
        hardness: Double,
        textureStrength: Double,
        seed: UInt64
    ) {
        self.center = center
        self.radius = radius
        self.alpha = alpha
        self.flow = flow
        self.rotation = rotation
        self.aspectRatio = aspectRatio
        self.hardness = hardness
        self.textureStrength = textureStrength
        self.seed = seed
    }
}
