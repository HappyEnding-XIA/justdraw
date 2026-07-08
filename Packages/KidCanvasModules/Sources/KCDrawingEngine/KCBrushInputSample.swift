//
//  KCBrushInputSample.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/07/08.
//

import Foundation
import CoreGraphics

/// 一次高保真画笔输入采样，作为 dab 引擎的输入。
///
/// 这是 UIKit-free 的纯数据模型：`point` 使用画布坐标系（`CGPoint` 来自 CoreGraphics），
/// `pressure` 已经由上层 `KCPressureModel.normalized(...)` 归一化（可能略大于 1.0）。
/// `altitude` / `azimuth` 以弧度表示，`altitude == π/2` 表示笔尖垂直于屏幕。
/// 引擎不在此处做任何 UIKit 触摸解析；上层（T094）负责把 coalesced touches、
/// `force`、`altitudeAngle`、`azimuthAngle` 转成 `KCBrushInputSample`。
public struct KCBrushInputSample: Sendable, Equatable {
    /// 采样点，画布坐标系。
    public var point: CGPoint
    /// 采样时间戳（秒），用于由相邻采样估算速度。
    public var timestamp: TimeInterval
    /// 归一化压力（0…~1.45）。引擎内部会再 clamp 到 [0,1] 参与半径/流量曲线。
    public var pressure: Double
    /// 采样瞬时速度（点/秒）；未知时传 0，引擎会在相邻采样间按位移/时间估算。
    public var velocity: Double
    /// 笔尖高度角（弧度）。π/2 = 垂直，0 = 平放。
    public var altitude: Double
    /// 笔尖方位角（弧度），决定侧锋椭圆 dab 的旋转方向。
    public var azimuth: Double
    /// 是否来自 Apple Pencil；手指输入为 false，引擎据此关闭倾角塑形。
    public var isPencil: Bool

    public init(
        point: CGPoint,
        timestamp: TimeInterval,
        pressure: Double,
        velocity: Double,
        altitude: Double,
        azimuth: Double,
        isPencil: Bool
    ) {
        self.point = point
        self.timestamp = timestamp
        self.pressure = pressure
        self.velocity = velocity
        self.altitude = altitude
        self.azimuth = azimuth
        self.isPencil = isPencil
    }
}
