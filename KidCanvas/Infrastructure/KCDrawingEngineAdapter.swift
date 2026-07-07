//
//  KCDrawingEngineAdapter.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import UIKit
import KCCommon
import KCDomain
import KCDrawingEngine

/// App 层使用的绘制能力协议。调用方只依赖协议，默认实现由
/// `KCAppCompositionRoot` 注入，避免 Feature / View 继续直接依赖静态 adapter。
protocol KCDrawingEngineProviding: AnyObject {
    func floodFillImage(
        _ image: CGImage,
        startX: Int,
        startY: Int,
        fillColor: UIColor,
        tolerance: Double
    ) -> CGImage?
    func sampleColorFromImage(_ image: CGImage, x: Int, y: Int) -> UIColor?
    func normalizedPressure(force: Double, maximumPossibleForce: Double, isPencil: Bool) -> Double
    func renderedStrokeLineWidth(brushStyle: Int, lineWidth: Double, averagePressure: Double) -> Double
    func renderedStrokeAlpha(brushStyle: Int, lineWidth: Double, averagePressure: Double) -> Double
    func eraserStampPath(shape: Int, center: CGPoint, size: CGFloat) -> UIBezierPath?
    func eraserStampPointsAlongPath(_ path: CGPath, lineWidth: CGFloat) -> [NSValue]
    func crayonGrainDashPoints(pathBounds: CGRect, lineWidth: CGFloat) -> [NSValue]
    func crayonGrainDashWidth(lineWidth: CGFloat) -> CGFloat
    func stickerTransformByClampingScale(_ transform: CGAffineTransform) -> CGAffineTransform
    func clampStickerCenter(_ center: CGPoint, frame: CGRect, canvasBounds: CGRect) -> CGPoint
    func historyMaxPageIndex(sessionCount: Int, pageSize: Int) -> Int
    func historyClampedPageIndex(_ pageIndex: Int, sessionCount: Int, pageSize: Int) -> Int
    func historySessionIndex(thumbIndex: Int, pageIndex: Int, pageSize: Int) -> Int
    func toolStateChipTitle(toolMode: Int, brushStyle: Int) -> String
    func lineArtDrawingBlock(
        templateId: String,
        stroke: @escaping (_ path: UIBezierPath, _ lineWidth: CGFloat) -> Void
    ) -> ((CGRect) -> Void)?
}

/// 把无 UIKit 依赖的 `KCDrawingEngine` 算法桥接给画布侧。
///
/// 每个方法都是薄适配，负责在 UIKit/CoreGraphics 类型（UIColor、CGImage、
/// UITouch 的 force）与引擎的纯 Swift 类型（KCRGBA8、KCBitmapBuffer、
/// KCFloodFillEngine、KCColorSampler、KCPressureModel）之间转换。
///
/// 画布视图（`KCDrawingCanvasView`）调用这些方法，并自行管理画布状态
///（backgroundImage、strokes、setNeedsDisplay、undo）。
///
/// 注意：这是迁移期的桥接层。画布完全 Swift 化后，应直接调用引擎。
@objc(KCDrawingEngineAdapter)
final class KCDrawingEngineAdapter: NSObject, KCDrawingEngineProviding {

    /// 对 `image` 从像素坐标（`startX`、`startY`）开始做 flood fill，填充
    /// `fillColor`，使用原型 `tolerance * 4` 的曼哈顿色差规则。
    ///
    /// 返回填充后的图像；若无像素发生变化或图像无法解码，返回 `nil`。
    func floodFillImage(
        _ image: CGImage,
        startX: Int,
        startY: Int,
        fillColor: UIColor,
        tolerance: Double
    ) -> CGImage? {
        guard let buffer = KCBitmapBuffer(cgImage: image) else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        fillColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgba = KCRGBA8(
            red: UInt8(max(0, min(255, lrint(r * 255)))),
            green: UInt8(max(0, min(255, lrint(g * 255)))),
            blue: UInt8(max(0, min(255, lrint(b * 255)))),
            alpha: UInt8(max(0, min(255, lrint(a * 255))))
        )
        let changed = KCFloodFillEngine.fill(
            buffer: buffer, startX: startX, startY: startY,
            fillColor: rgba, tolerance: tolerance
        )
        guard changed > 0 else { return nil }
        return buffer.makeCGImage()
    }

    /// 从 `image` 的像素坐标（`x`、`y`）采样单个像素颜色，只裁剪并渲染目标
    /// 1×1 像素，避免为高频取色路径分配整张位图缓冲区。
    func sampleColorFromImage(
        _ image: CGImage,
        x: Int,
        y: Int
    ) -> UIColor? {
        guard let pixel = KCImagePixelSampler.sample(cgImage: image, x: x, y: y) else {
            return nil
        }
        return UIColor(
            red: CGFloat(pixel.red) / 255.0,
            green: CGFloat(pixel.green) / 255.0,
            blue: CGFloat(pixel.blue) / 255.0,
            alpha: CGFloat(pixel.alpha) / 255.0
        )
    }

    /// 将原始 force 归一化到原型的压力范围：Pencil 为 0.65–1.45，
    /// 手指为 0.92–1.18。
    ///
    /// 设备不报告 force 时（`maximumPossibleForce <= 0`）返回 `1.0`，
    /// 与原型的提前返回行为一致。
    func normalizedPressure(
        force: Double,
        maximumPossibleForce: Double,
        isPencil: Bool
    ) -> Double {
        KCPressureModel.normalized(
            force: force,
            maximumPossibleForce: maximumPossibleForce,
            isPencil: isPencil
        )
    }

    // MARK: - 笔画渲染参数

    /// 返回给定画笔配置下的渲染线宽。调用方（`drawStroke:`）在调用本方法前，
    /// 已处理橡皮擦的压力覆盖（橡皮擦强制 `averagePressure = 1.0`）。
    /// `brushStyle` 对应 `KDBrushStyle` 的 raw 值：0 = 铅笔、1 = 钢笔、2 = 蜡笔。
    func renderedStrokeLineWidth(
        brushStyle: Int,
        lineWidth: Double,
        averagePressure: Double
    ) -> Double {
        guard let style = Self.brushStyleFromOC(brushStyle) else { return lineWidth }
        return KCStrokeRenderMath.renderedMetrics(
            brushStyle: style, lineWidth: lineWidth, pressure: averagePressure
        ).renderedLineWidth
    }

    /// 返回给定画笔配置下的渲染 alpha。
    func renderedStrokeAlpha(
        brushStyle: Int,
        lineWidth: Double,
        averagePressure: Double
    ) -> Double {
        guard let style = Self.brushStyleFromOC(brushStyle) else { return 1.0 }
        return KCStrokeRenderMath.renderedMetrics(
            brushStyle: style, lineWidth: lineWidth, pressure: averagePressure
        ).alpha
    }

    // MARK: - 橡皮擦印章路径

    /// 返回给定橡皮擦形状在 `center`、`size` 处的 `UIBezierPath`，封装自
    /// CoreGraphics `KCEraserStampPath` 引擎。`shape` 对应 `KDEraserShape`
    /// 的 raw 值：0 = 圆形、1 = 云朵、2 = 星形。
    func eraserStampPath(
        shape: Int,
        center: CGPoint,
        size: CGFloat
    ) -> UIBezierPath? {
        guard let eraserShape = Self.eraserShapeFromOC(shape) else { return nil }
        let cgPath = KCEraserStampPath.path(for: eraserShape, center: center, size: size)
        return UIBezierPath(cgPath: cgPath)
    }

    // MARK: - 橡皮擦印章插值

    /// 返回沿 `path` 插值得到的印章中心点，间距为 `max(6, lineWidth × 0.38)`。
    /// 调用方遍历这些点，在每个位置填充橡皮擦印章形状。
    /// 返回 `NSValue` 包装的 `CGPoint` 数组，供跨语言调用使用。
    func eraserStampPointsAlongPath(
        _ path: CGPath,
        lineWidth: CGFloat
    ) -> [NSValue] {
        KCEraserStampPath.interpolatedStampPoints(along: path, lineWidth: lineWidth)
            .map { NSValue(cgPoint: $0) }
    }

    // MARK: - 蜡笔纹理

    /// 返回蜡笔纹理的 dash 端点：笔画路径包围盒为 `pathBounds`、渲染线宽为
    /// `lineWidth`，由 Swift `KCCrayonGrain` 引擎计算。调用方在 UIKit 中绘制
    /// 每个 dash（clip / 颜色 / 描边）。
    ///
    /// 每个 dash 编码为两个连续的 `NSValue` 包装 `CGPoint`（起点、终点），
    /// 返回数组长度恒为偶数。每条 dash 的常量描边宽度请用
    /// `crayonGrainDashWidth(lineWidth:)` 获取。
    func crayonGrainDashPoints(
        pathBounds: CGRect,
        lineWidth: CGFloat
    ) -> [NSValue] {
        let dashes = KCCrayonGrain.dashes(pathBounds: pathBounds, lineWidth: lineWidth)
        var values: [NSValue] = []
        values.reserveCapacity(dashes.count * 2)
        for dash in dashes {
            values.append(NSValue(cgPoint: dash.start))
            values.append(NSValue(cgPoint: dash.end))
        }
        return values
    }

    /// 蜡笔纹理每条 dash 的常量描边宽度（`max(0.7, lineWidth * 0.045)`）。
    /// 等于 `KCCrayonGrain.dashes(...)` 生成的每条 dash 的 `lineWidth`；
    /// 单独暴露，避免纹理绘制方内联重复推导该常量。
    func crayonGrainDashWidth(lineWidth: CGFloat) -> CGFloat {
        max(0.7, lineWidth * 0.045)
    }

    // MARK: - 贴纸变换约束

    /// 返回贴纸的仿射变换，其等比缩放被限制在原型的 `[0.48, 2.6]` 范围内
    ///（退化情况 → identity）。pinch 手势处理方将结果应用到视图；只有计算
    /// 逻辑在 Swift（`KCStickerConstraints`）中。
    func stickerTransformByClampingScale(
        _ transform: CGAffineTransform
    ) -> CGAffineTransform {
        KCStickerConstraints.transformWithClampedScale(transform)
    }

    /// 返回经限制的贴纸 `center`，使贴纸在 `canvasBounds` 内始终可触及。
    /// pan 手势处理方将结果应用到视图。
    func clampStickerCenter(
        _ center: CGPoint,
        frame: CGRect,
        canvasBounds: CGRect
    ) -> CGPoint {
        KCStickerConstraints.clampedCenter(center, frame: frame, canvasBounds: canvasBounds)
    }

    // MARK: - 历史分页（KCHistoryFeature 边界）

    /// `sessionCount` 个会话在 `pageSize` 下最高有效的历史页索引。
    /// 委托给 Swift `KCHistoryPaging` 历史 Feature 模型。
    func historyMaxPageIndex(sessionCount: Int, pageSize: Int) -> Int {
        KCHistoryPaging(sessionCount: sessionCount, pageSize: pageSize).maxPageIndex
    }

    /// 将 `pageIndex` 限制到 `sessionCount`/`pageSize` 的有效范围内。
    func historyClampedPageIndex(
        _ pageIndex: Int,
        sessionCount: Int,
        pageSize: Int
    ) -> Int {
        KCHistoryPaging(sessionCount: sessionCount, pageSize: pageSize, pageIndex: pageIndex).clampedPageIndex
    }

    /// 缩略图槽位 `thumbIndex` 在 `pageIndex` 页对应的绝对会话索引。
    func historySessionIndex(
        thumbIndex: Int,
        pageIndex: Int,
        pageSize: Int
    ) -> Int {
        KCHistoryPaging(sessionCount: 0, pageSize: pageSize, pageIndex: pageIndex)
            .sessionIndex(forThumb: thumbIndex)
    }

    // MARK: - 工具状态芯片标题（KCEditorPanelsFeature 边界）

    /// 返回当前工具/画笔在折叠态芯片上的标题文本，委托给 Swift `KCToolStateChipTitle`。
    /// `toolMode`/`brushStyle` 为 OC 枚举 rawValue（Int）：tool 0=画笔/1=橡皮/2=填充/3=贴纸/4=取色；
    /// brush 0=铅笔/1=钢笔/2=蜡笔。越界返回空串。
    func toolStateChipTitle(toolMode: Int, brushStyle: Int) -> String {
        guard let tool = Self.toolModeFromOC(toolMode), let brush = Self.brushStyleFromOC(brushStyle) else {
            return ""
        }
        return KCToolStateChipTitle.title(tool: tool, brush: brush)
    }

    // MARK: - 线稿绘制（KCDrawingEngine 边界）

    /// 返回线稿绘制闭包。几何路径由无 UIKit 依赖的 `KCLineArtDrawing` 生成，
    /// App 层只把 `CGPath` 包装成 `UIBezierPath` 并交给现有描边函数。
    func lineArtDrawingBlock(
        templateId: String,
        stroke: @escaping (_ path: UIBezierPath, _ lineWidth: CGFloat) -> Void
    ) -> ((CGRect) -> Void)? {
        guard KCLineArtDrawing.supportedTemplateIds.contains(templateId) else { return nil }
        return { rect in
            guard let lineArtStrokes = KCLineArtDrawing.strokes(forTemplateId: templateId, in: rect) else {
                return
            }
            for lineArtStroke in lineArtStrokes {
                stroke(UIBezierPath(cgPath: lineArtStroke.path), lineArtStroke.lineWidth)
            }
        }
    }

    // MARK: - 私有枚举映射（Int → Swift 枚举）

    /// 把 `KDToolMode` 的整数值（0=画笔、1=橡皮、2=填充、3=贴纸、4=取色）映射到 Swift
    /// `KCToolMode` 枚举。越界值返回 `nil`。
    private static func toolModeFromOC(_ value: Int) -> KCToolMode? {
        switch value {
        case 0: return .brush
        case 1: return .eraser
        case 2: return .fill
        case 3: return .sticker
        case 4: return .picker
        default: return nil
        }
    }

    /// 把 `KDBrushStyle` 的整数值（0=铅笔、1=钢笔、2=蜡笔）映射到 Swift
    /// `KCBrushStyle` 枚举。越界值返回 `nil`。
    private static func brushStyleFromOC(_ value: Int) -> KCBrushStyle? {
        switch value {
        case 0: return .pencil
        case 1: return .pen
        case 2: return .crayon
        default: return nil
        }
    }

    /// 把 `KDEraserShape` 的整数值（0=圆形、1=云朵、2=星形）映射到 Swift
    /// `KCEraserShape` 枚举。越界值返回 `nil`。
    private static func eraserShapeFromOC(_ value: Int) -> KCEraserShape? {
        switch value {
        case 0: return .circle
        case 1: return .cloud
        case 2: return .star
        default: return nil
        }
    }
}
