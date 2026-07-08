//
//  KCDrawingCanvasModels.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/07.
//

import UIKit
import KCDrawingEngine

// MARK: - 工具枚举

@objc(KDToolMode)
enum KDToolMode: Int {
    case brush = 0
    case eraser
    case fill
    case sticker
    case picker
}

@objc(KDBrushStyle)
enum KDBrushStyle: Int {
    case pencil = 0
    case pen
    case crayon
}

@objc(KDEraserShape)
enum KDEraserShape: Int {
    case circle = 0
    case cloud
    case star
}

// MARK: - 画布状态模型类型

final class KDStroke: NSObject {
    var path: UIBezierPath = UIBezierPath()
    var color: UIColor = .black
    var lineWidth: CGFloat = 0
    var pressureTotal: CGFloat = 0
    var pressureSampleCount: Int = 0
    var startPoint: CGPoint = .zero
    var dotStroke: Bool = false
    var cachedRenderBounds: CGRect?
    var cachedCrayonGrainDashPoints: [NSValue]?
    var cachedCrayonGrainDashLineWidth: CGFloat = 0
    var toolMode: KDToolMode = .brush
    var brushStyle: KDBrushStyle = .pencil
    var eraserShape: KDEraserShape = .circle

    /// T094：高保真输入采样，铅笔/蜡笔 dab 渲染用。运行时字段，不持久化（保存仍为 raster）。
    var samples: [KCBrushInputSample] = []
    /// 由 samples 生成的 dab 缓存，重绘 / undo redo 复用；samples 变化时置 nil。
    var cachedDabs: [KCBrushDab]?

    var averagePressure: CGFloat {
        pressureSampleCount <= 0 ? 1.0 : pressureTotal / CGFloat(pressureSampleCount)
    }
}

final class KDStickerState: NSObject {
    var symbolName: String = ""
    var symbolColor: UIColor = .black
    var center: CGPoint = .zero
    var transform: CGAffineTransform = .identity
}

final class KDCanvasState: NSObject {
    var backgroundImage: UIImage?
    var strokes: [KDStroke] = []
    var stickers: [KDStickerState] = []
}

// MARK: - 贴纸视图

final class KDStickerView: UIImageView {
    var symbolName: String = ""
    var symbolColor: UIColor = .black
}
