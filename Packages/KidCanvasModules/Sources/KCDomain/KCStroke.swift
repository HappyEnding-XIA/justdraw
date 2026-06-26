//
//  KCStroke.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import CoreGraphics
import KCCommon

/// 单笔画笔或橡皮擦笔画，以 Objective-C 的 `KDStroke` 为蓝本。
///
/// 一笔笔画携带采样到的触摸点、绘制过程中累积的平均压感，以及生效的工具/
/// 画笔/橡皮擦配置。压感以累加和与计数的形式存储，从而无需保留每个采样即可
/// 重新计算渲染宽度（`averagePressure`）。
public struct KCStroke: Codable, Equatable, Sendable {
    public var toolMode: KCToolMode
    public var brushStyle: KCBrushStyle
    public var eraserShape: KCEraserShape
    public var color: KCHexColor
    public var lineWidth: Double

    /// 绘制过程中捕获的触摸点，使用画布坐标系。
    public var points: [CGPoint]
    /// 第一个触摸位置；用于点（点击）笔画与抖动过滤。
    public var startPoint: CGPoint
    /// 当该笔画是一次从未移动的点击时为 `true`——渲染为一个实心圆点。
    public var dotStroke: Bool
    /// 归一化压感采样的累加和（见 `KCPressureModel`）。
    public var pressureTotal: Double
    /// 累加到 `pressureTotal` 中的压感采样数。
    public var pressureSampleCount: Int

    public init(
        toolMode: KCToolMode,
        brushStyle: KCBrushStyle,
        eraserShape: KCEraserShape,
        color: KCHexColor,
        lineWidth: Double,
        points: [CGPoint] = [],
        startPoint: CGPoint = .zero,
        dotStroke: Bool = false,
        pressureTotal: Double = 0,
        pressureSampleCount: Int = 0
    ) {
        self.toolMode = toolMode
        self.brushStyle = brushStyle
        self.eraserShape = eraserShape
        self.color = color
        self.lineWidth = lineWidth
        self.points = points
        self.startPoint = startPoint
        self.dotStroke = dotStroke
        self.pressureTotal = pressureTotal
        self.pressureSampleCount = pressureSampleCount
    }

    /// 平均归一化压感，无采样时回退到 1.0，对应原型中的
    /// `-[KDStroke averagePressure]`。
    public var averagePressure: Double {
        pressureSampleCount <= 0 ? 1.0 : pressureTotal / Double(pressureSampleCount)
    }

    /// 累加一个归一化压感采样。
    public mutating func recordPressure(_ normalizedPressure: Double) {
        pressureTotal += normalizedPressure
        pressureSampleCount += 1
    }
}
