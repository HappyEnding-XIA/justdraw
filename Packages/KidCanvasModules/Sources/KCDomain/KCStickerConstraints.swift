//
//  KCStickerConstraints.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/26.
//

import Foundation
import CoreGraphics

/// 不依赖 UIKit 的几何工具，将贴纸的仿射变换与中心点约束在画布范围内——
/// 忠实移植自 Objective-C 画布的 `constrainStickerScale:` 与
/// `constrainStickerCenter:`。
///
/// `KDDrawingCanvasView` 中的实时手势处理器继续将结果应用到 UIKit 视图上；
/// 仅纯粹的变换/中心点计算放在此处，以便在不依赖 UIKit 的情况下进行单元测试。
public enum KCStickerConstraints {

    /// 贴纸最小缩放（对应原型中的 `KDStickerMinimumScale`）。
    public static let minimumScale: CGFloat = 0.48

    /// 贴纸最大缩放（对应原型中的 `KDStickerMaximumScale`）。
    public static let maximumScale: CGFloat = 2.6

    /// 通过 `hypot(a, c)` 从实时仿射变换中读取的均匀缩放，与原型在钳制贴纸
    /// 尺寸时所用的提取方式相同。
    public static func scale(of transform: CGAffineTransform) -> CGFloat {
        hypot(transform.a, transform.c)
    }

    /// 返回钳制到 `[minimumScale, maximumScale]` 范围内的 `scale`。
    public static func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(maximumScale, max(minimumScale, scale))
    }

    /// 返回均匀缩放被钳制到 `[minimumScale, maximumScale]` 范围内的
    /// `transform`，对应原型中的 `constrainStickerScale:`：
    ///   - 退化（非正）的缩放重置为恒等变换；
    ///   - 当缩放已落在钳制值的 `0.001` 范围内时，原样返回变换
    ///     （无需可见的修正）。
    public static func transformWithClampedScale(_ transform: CGAffineTransform) -> CGAffineTransform {
        let currentScale = scale(of: transform)
        if currentScale <= 0.0 {
            return .identity
        }
        let clamped = clampedScale(currentScale)
        if abs(clamped - currentScale) < 0.001 {
            return transform
        }
        let correction = clamped / currentScale
        return transform.scaledBy(x: correction, y: correction)
    }

    /// 返回被钳制的 `center`，使具有给定 `frame` 的贴纸在 `canvasBounds` 内
    /// 始终可达，对应原型中的 `constrainStickerCenter:`。当画布边界为空时，
    /// 原样返回 `center`。
    public static func clampedCenter(
        _ center: CGPoint,
        frame: CGRect,
        canvasBounds: CGRect
    ) -> CGPoint {
        guard !canvasBounds.isEmpty else { return center }

        let halfWidth = min(canvasBounds.width * 0.5, max(24.0, frame.width * 0.5))
        let halfHeight = min(canvasBounds.height * 0.5, max(24.0, frame.height * 0.5))
        let minX = halfWidth
        let maxX = max(minX, canvasBounds.width - halfWidth)
        let minY = halfHeight
        let maxY = max(minY, canvasBounds.height - halfHeight)
        return CGPoint(
            x: min(maxX, max(minX, center.x)),
            y: min(maxY, max(minY, center.y))
        )
    }

    /// 当 `point` 位于 `rect`（同一坐标系）内时返回 `true`。
    /// 一个可测试的包含判定原语，支撑画布的贴纸命中测试；
    /// UIKit 画布仍负责进行考虑变换的点坐标转换。
    public static func contains(_ rect: CGRect, point: CGPoint) -> Bool {
        rect.contains(point)
    }
}
