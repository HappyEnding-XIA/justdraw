//
//  KCCrayonGrain.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/06/26.
//

import Foundation
import CoreGraphics

/// 由 `KCCrayonGrain.dashes(...)` 生成的一段蜡笔颗粒短线。
///
/// UIKit/CoreGraphics 的绘制（裁剪、颜色、描边每段短线）保留在 App 层；
/// 此结构体仅承载确定性的产品化蜡笔颗粒几何数据。
public struct KCCrayonGrainDash {
    public let start: CGPoint
    public let end: CGPoint
    /// 对于给定线宽，所有短线的该值恒定：
    /// `max(1.0, lineWidth * 0.12)`。
    public let lineWidth: CGFloat

    public init(start: CGPoint, end: CGPoint, lineWidth: CGFloat) {
        self.start = start
        self.end = end
        self.lineWidth = lineWidth
    }
}

/// 确定性的蜡笔颗粒生成。
///
/// 整数种子运算保证对于任意给定的（`pathBounds`，`lineWidth`）生成稳定短线点；
/// 常量已按产品反馈调成更密、更粗的蜡笔颗粒，避免蜡笔退化成平滑粗线。
public enum KCCrayonGrain {

    /// 返回构成蜡笔颗粒纹理的抖动短线段集合，对应的笔画路径包围盒为 `bounds`，
    /// 渲染线宽为 `lineWidth`。
    public static func dashes(pathBounds bounds: CGRect, lineWidth: CGFloat) -> [KCCrayonGrainDash] {
        guard !bounds.isEmpty else { return [] }

        // grainBounds = bounds 在四周各向外扩展 lineWidth/2。
        let grainBounds = bounds.insetBy(dx: -lineWidth * 0.5, dy: -lineWidth * 0.5)

        let spacing = max(3.4, lineWidth * 0.30)
        let columnCount = min(220, max(1, Int(ceil(grainBounds.width / spacing))))
        let rowCount = min(180, max(1, Int(ceil(grainBounds.height / spacing))))
        let dashWidth = max(1.0, lineWidth * 0.12)

        var dashes: [KCCrayonGrainDash] = []
        dashes.reserveCapacity((rowCount + 1) * (columnCount + 1))

        for row in 0...rowCount {
            for column in 0...columnCount {
                let seed = row * 37 + column * 17
                let jitterX = CGFloat((seed % 7) - 3) * 0.46
                let jitterY = CGFloat(((seed / 3) % 7) - 3) * 0.38
                let x = grainBounds.minX + CGFloat(column) * spacing + jitterX
                let y = grainBounds.minY + CGFloat(row) * spacing + jitterY
                let dashLength = max(1.8, lineWidth * (0.18 + CGFloat(seed % 5) * 0.035))
                let yOffsetMagnitude = max(0.95, lineWidth * 0.070)
                let yOffset: CGFloat = (seed % 2 == 0) ? yOffsetMagnitude : -yOffsetMagnitude
                dashes.append(KCCrayonGrainDash(
                    start: CGPoint(x: x - dashLength * 0.5, y: y),
                    end: CGPoint(x: x + dashLength * 0.5, y: y + yOffset),
                    lineWidth: dashWidth
                ))
            }
        }
        return dashes
    }
}
