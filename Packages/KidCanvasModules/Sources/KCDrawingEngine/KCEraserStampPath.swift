//
//  KCEraserStampPath.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import CoreGraphics
import KCDomain

/// 生成单个橡皮擦印章的 `CGPath`，并计算沿笔画路径的插值印章位置，
/// 移植自 `-[KDDrawingCanvasView eraserShapePathForShape:center:size:]`
/// 和 `-[KDDrawingCanvasView drawStampedEraserStroke:]`。
public enum KCEraserStampPath {

    /// 返回以 `center` 为中心、按 `size` 缩放的 `shape` 的闭合路径。
    public static func path(for shape: KCEraserShape, center: CGPoint, size: CGFloat) -> CGPath {
        let radius = max(10.0, size * 0.55)
        switch shape {
        case .circle:
            return CGPath(
                ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                  width: radius * 2.0, height: radius * 2.0),
                transform: nil
            )
        case .cloud:
            let path = CGMutablePath()
            path.addPath(CGPath(ellipseIn: CGRect(x: center.x - radius * 1.1, y: center.y - radius * 0.45,
                                                  width: radius * 0.95, height: radius * 0.78), transform: nil))
            path.addPath(CGPath(ellipseIn: CGRect(x: center.x - radius * 0.42, y: center.y - radius * 0.8,
                                                  width: radius * 1.0, height: radius * 0.95), transform: nil))
            path.addPath(CGPath(ellipseIn: CGRect(x: center.x + radius * 0.16, y: center.y - radius * 0.38,
                                                  width: radius * 0.92, height: radius * 0.72), transform: nil))
            return path
        case .star:
            return star(center: center, outerRadius: radius, innerRadius: radius * 0.45, points: 5)
        }
    }

    /// 返回沿给定路径插值得到的印章中心位置，间距遵循原型规则：
    /// `max(6, lineWidth × 0.38)`。
    ///
    /// OC 代码通过 `CGPathApply` 收集路径点，然后按计算出的间距在相邻点之间
    /// 进行线性插值。本方法完全复刻该算法。
    public static func interpolatedStampPoints(
        along path: CGPath,
        lineWidth: CGFloat
    ) -> [CGPoint] {
        var pathPoints: [CGPoint] = []
        path.applyWithBlock { element in
            let pts = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                pathPoints.append(pts[0])
            case .addQuadCurveToPoint:
                pathPoints.append(pts[0])
                pathPoints.append(pts[1])
            case .addCurveToPoint:
                pathPoints.append(pts[0])
                pathPoints.append(pts[1])
                pathPoints.append(pts[2])
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }

        let spacing = max(6.0, lineWidth * 0.38)
        var result: [CGPoint] = []
        var previousPoint = CGPoint.zero
        var hasPrevious = false

        for point in pathPoints {
            if !hasPrevious {
                result.append(point)
                previousPoint = point
                hasPrevious = true
                continue
            }

            let dx = point.x - previousPoint.x
            let dy = point.y - previousPoint.y
            let distance = hypot(dx, dy)
            let steps = max(1, Int(ceil(distance / spacing)))
            for step in 1...steps {
                let progress = CGFloat(step) / CGFloat(steps)
                result.append(CGPoint(
                    x: previousPoint.x + dx * progress,
                    y: previousPoint.y + dy * progress
                ))
            }

            previousPoint = point
        }

        return result
    }

    // MARK: - 私有

    /// 五角星轮廓，与原型保持一致。
    static func star(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat, points: Int) -> CGPath {
        let path = CGMutablePath()
        let totalVertices = points * 2
        for index in 0..<totalVertices {
            let angle = (-CGFloat.pi / 2.0) + CGFloat(index) * (CGFloat.pi / CGFloat(points))
            let radius = index % 2 == 0 ? outerRadius : innerRadius
            let point = CGPoint(x: center.x + radius * cos(angle),
                                y: center.y + radius * sin(angle))
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
