//
//  KCDrawingCanvasView.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/26.
//

import UIKit
import KCDomain
import KCDrawingEngine

// MARK: - 代理

@objc(KDDrawingCanvasViewDelegate)
protocol KDDrawingCanvasViewDelegate: AnyObject {
    func drawingCanvasView(_ canvasView: KCDrawingCanvasView, didPickColor color: UIColor)
    @objc optional func drawingCanvasViewDidInsertSticker(_ canvasView: KCDrawingCanvasView)
    @objc optional func drawingCanvasViewSelectionDidChange(_ canvasView: KCDrawingCanvasView)
    @objc optional func drawingCanvasViewContentDidChange(_ canvasView: KCDrawingCanvasView)
    /// 画布视口（缩放/平移）发生变化。主控制器据此显隐“恢复视图”按钮。
    @objc optional func drawingCanvasViewportDidChange(_ canvasView: KCDrawingCanvasView)
}

/// 原 Objective-C `KDDrawingCanvasView` 的忠实 Swift 移植。行为保持 1:1 一致
///（触摸绘制、撤销/重做、贴纸手势、渲染）。纯绘制算法通过
/// `KCDrawingEngineProviding` 委托给 Swift 绘制引擎（与 OC 版本一致）。
@objc(KDDrawingCanvasView)
final class KCDrawingCanvasView: UIView, UIGestureRecognizerDelegate {

    private struct KCWorkbenchSurfaceCacheKey: Equatable {
        let bounds: CGRect
        let scale: CGFloat
        let interfaceStyle: UIUserInterfaceStyle
    }

    @objc weak var delegate: KDDrawingCanvasViewDelegate?

    @objc var currentColor: UIColor = UIColor(red: 0.94, green: 0.43, blue: 0.45, alpha: 1.0)
    @objc var currentLineWidth: CGFloat = 12.0
    @objc var currentToolMode: KDToolMode = .brush
    @objc var currentBrushStyle: KDBrushStyle = .pencil
    @objc var currentEraserShape: KDEraserShape = .circle
    @objc var currentStickerSymbol: String = "star.fill"
    @objc var fillTolerance: Double = 28.0
    var drawingEngine: KCDrawingEngineProviding = KCDrawingEngineAdapter()

    private var strokes: [KDStroke] = []
    private var stickers: [KDStickerView] = []
    private let historyStore = KCCanvasHistoryStore()
    private let stickerPresenter = KCStickerViewPresenter()
    private let floodFillQueue = DispatchQueue(label: "com.kidcanvas.canvas.flood-fill", qos: .userInitiated)
    private var activeStroke: KDStroke?
    private var backgroundImage: UIImage?
    private var pendingStrokeState: KDCanvasState?
    private var pendingStickerTransformState: KDCanvasState?
    private var activeStrokeDidMutate = false
    private var stickerTransformDidMutate = false
    private var activeStickerGestureCount = 0
    private var floodFillGeneration: Int = 0
    private var floodFillInProgress = false
    private var nonStickerRasterCacheImage: UIImage?
    private var nonStickerRasterCacheBounds: CGRect = .null
    private var nonStickerRasterCacheScale: CGFloat = 0.0
    private var workbenchSurfaceCacheImage: UIImage?
    private var workbenchSurfaceCacheKey: KCWorkbenchSurfaceCacheKey?
    private weak var selectedStickerView: KDStickerView?

    #if DEBUG
    private var completedStrokeReplayCount = 0
    private var rasterRebuildCount = 0
    #endif

    /// 工作台背景色：只用于屏幕呈现层，让画布外区域和白色纸张形成低干扰区分。
    private static let workbenchBackgroundColor = UIColor(red: 0.935, green: 0.945, blue: 0.925, alpha: 1.0)
    /// 纸张边界描边色：保持轻量，但在 iPad 大屏空白画布下也能识别纸张边缘。
    private static let paperBorderColor = UIColor(red: 0.77, green: 0.80, blue: 0.75, alpha: 1.0)
    /// 纸张投影色：仅参与屏幕渲染，不进入保存图片、历史缩略图和草稿数据。
    private static let paperShadowColor = UIColor(red: 0.22, green: 0.25, blue: 0.20, alpha: 0.18)

    // MARK: - 画布视口（T097）

    /// 画布视口状态（缩放/平移/安全创作区）。内容坐标空间尺寸等于 `bounds.size`，
    /// 由 `layoutSubviews` 与 `applyViewportRect(_:)` 维护。
    private var viewportState = KCCanvasViewportState(contentSize: .zero, viewportRect: .zero)
    /// 双指捏合缩放手势。
    private lazy var canvasPinchGestureRecognizer: UIPinchGestureRecognizer = {
        UIPinchGestureRecognizer(target: self, action: #selector(handleCanvasPinch(_:)))
    }()
    /// 双指拖拽平移手势（与 pinch 同时识别，实现边缩放边平移）。
    private lazy var canvasTwoFingerPanGestureRecognizer: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleCanvasTwoFingerPan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        return pan
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Self.workbenchBackgroundColor
        isOpaque = true
        isMultipleTouchEnabled = true
        installCanvasViewportGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = Self.workbenchBackgroundColor
        isOpaque = true
        isMultipleTouchEnabled = true
        installCanvasViewportGestures()
    }

    /// 安装双指缩放/平移手势。单指与 Apple Pencil 仍走 `touchesBegan/Moved/Ended` 绘制；
    /// 两指落在印章子视图上时让位给印章自身的缩放/旋转/拖拽手势（见 `shouldBegin`）。
    private func installCanvasViewportGestures() {
        canvasPinchGestureRecognizer.delegate = self
        canvasTwoFingerPanGestureRecognizer.delegate = self
        addGestureRecognizer(canvasPinchGestureRecognizer)
        addGestureRecognizer(canvasTwoFingerPanGestureRecognizer)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if nonStickerRasterCacheImage != nil && !nonStickerRasterCacheBounds.equalTo(bounds) {
            invalidateNonStickerRasterCache()
        }
        syncViewportWithBoundsIfNeeded()
    }

    /// 画布尺寸变化时同步 viewport 内容尺寸。若当前处于默认视图则跟随新的安全创作区
    /// 重新居中；若用户已缩放/平移，则在新的边界内重新钳制并保留其视图。
    private func syncViewportWithBoundsIfNeeded() {
        guard bounds.width > 0.0, bounds.height > 0.0 else { return }
        let newContentSize = bounds.size
        guard newContentSize != viewportState.contentSize || viewportState.viewportRect.isEmpty else { return }

        let wasDefault = viewportState.isDefault || viewportState.viewportRect.isEmpty
        viewportState.contentSize = newContentSize
        if wasDefault {
            viewportState = viewportState.defaultState
        } else {
            viewportState = viewportState.clamped
        }
        applyViewportToStickerViews()
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        workbenchSurfaceImage().draw(in: bounds)

        ctx.saveGState()
        ctx.concatenate(viewportState.affineTransform)

        // 内容平面：在内容坐标空间（0,0 ~ contentSize）绘制白色纸张、底图、笔画。
        let contentPlane = CGRect(origin: .zero, size: viewportState.contentSize)
        drawPaperSurface(in: ctx, contentPlane: contentPlane)

        ctx.saveGState()
        ctx.clip(to: contentPlane)
        let completedContentImage = rasterImageExcludingStickers()
        completedContentImage.draw(in: contentPlane)

        // 活动画笔仍实时叠加；完成笔画已在 raster 中，不随 viewport 帧逐条重放。
        let contentDirtyRect = rect.applying(viewportState.affineTransform.inverted())
        if let activeStroke {
            if strokeRenderBounds(activeStroke).intersects(contentDirtyRect) {
                drawStroke(activeStroke)
            }
        }
        ctx.restoreGState()

        drawPaperBorder(in: ctx, contentPlane: contentPlane)
        ctx.restoreGState()
    }

    /// 绘制屏幕呈现层的白色纸张、轻投影和描边；保存/快照路径不调用这里。
    private func drawPaperSurface(in ctx: CGContext, contentPlane: CGRect) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.0, height: 8.0),
                      blur: 18.0,
                      color: Self.paperShadowColor.cgColor)
        UIColor.white.setFill()
        ctx.fill(contentPlane)
        ctx.restoreGState()
    }

    private func drawPaperBorder(in ctx: CGContext, contentPlane: CGRect) {
        let borderInset = 0.5 / max(viewportState.scale, 0.001)
        let borderRect = contentPlane.insetBy(dx: borderInset, dy: borderInset)
        ctx.saveGState()
        ctx.setLineWidth(1.0 / max(viewportState.scale, 0.001))
        Self.paperBorderColor.setStroke()
        ctx.stroke(borderRect)
        ctx.restoreGState()
    }

    private func workbenchSurfaceImage() -> UIImage {
        let scale = window?.screen.scale ?? UIScreen.main.scale
        let key = KCWorkbenchSurfaceCacheKey(
            bounds: bounds,
            scale: scale,
            interfaceStyle: traitCollection.userInterfaceStyle
        )
        if workbenchSurfaceCacheKey == key, let workbenchSurfaceCacheImage {
            return workbenchSurfaceCacheImage
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        let image = renderer.image { rendererContext in
            Self.workbenchBackgroundColor.setFill()
            rendererContext.cgContext.fill(bounds)
            drawWorkbenchGlow(in: rendererContext.cgContext)
        }
        workbenchSurfaceCacheKey = key
        workbenchSurfaceCacheImage = image
        return image
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        invalidateWorkbenchSurfaceCache()
        setNeedsDisplay()
    }

    @objc private func handleMemoryWarning() {
        brushTipCache.removeAllObjects()
        invalidateNonStickerRasterCache()
        invalidateWorkbenchSurfaceCache()
        setNeedsDisplay()
    }

    private func invalidateWorkbenchSurfaceCache() {
        workbenchSurfaceCacheImage = nil
        workbenchSurfaceCacheKey = nil
    }

    /// 极轻的工作台氛围光：只影响屏幕呈现层，让白纸周围有更柔和的暖感。
    private func drawWorkbenchGlow(in ctx: CGContext) {
        let colors = [
            UIColor(red: 1.0, green: 0.98, blue: 0.93, alpha: 0.10).cgColor,
            UIColor(red: 0.94, green: 0.96, blue: 0.92, alpha: 0.00).cgColor
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors,
                                        locations: [0.0, 1.0]) else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY * 0.92)
        let radius = max(bounds.width, bounds.height) * 0.72
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        ctx.drawRadialGradient(gradient,
                               startCenter: center,
                               startRadius: 0.0,
                               endCenter: center,
                               endRadius: radius,
                               options: [.drawsAfterEndLocation])
        ctx.restoreGState()
    }

    private func drawStroke(_ stroke: KDStroke) {
        if stroke.toolMode == .brush,
           stroke.brushStyle == .pencil || stroke.brushStyle == .crayon,
           !stroke.samples.isEmpty {
            drawDabStroke(stroke)
            return
        }
        let strokeColor: UIColor = stroke.toolMode == .eraser ? .white : stroke.color
        let pressure: CGFloat = stroke.toolMode == .eraser ? 1.0 : stroke.averagePressure
        let renderedLineWidth: CGFloat
        let alpha: CGFloat
        let brushProfile: KCStrokeRenderMath.RenderProfile?
        if stroke.toolMode == .eraser {
            renderedLineWidth = max(1.0, stroke.lineWidth)
            alpha = 1.0
            brushProfile = nil
        } else {
            brushProfile = self.drawingEngine.brushRenderProfile(
                brushStyle: stroke.brushStyle.rawValue,
                lineWidth: stroke.lineWidth,
                averagePressure: pressure
            )
            renderedLineWidth = brushProfile.map { CGFloat($0.metrics.renderedLineWidth) } ?? self.drawingEngine.renderedStrokeLineWidth(
                    brushStyle: stroke.brushStyle.rawValue,
                    lineWidth: stroke.lineWidth,
                    averagePressure: pressure
                )
            alpha = brushProfile.map { CGFloat($0.metrics.alpha) } ?? self.drawingEngine.renderedStrokeAlpha(
                    brushStyle: stroke.brushStyle.rawValue,
                    lineWidth: stroke.lineWidth,
                    averagePressure: pressure
                )
        }

        if stroke.toolMode == .eraser && stroke.eraserShape != .circle {
            drawStampedEraserStroke(stroke, color: strokeColor)
            return
        }

        let renderPath = stroke.path.copy() as! UIBezierPath
        renderPath.lineCapStyle = brushProfile?.usesButtLineCap == true ? .butt : .round
        renderPath.lineJoinStyle = .round
        renderPath.lineWidth = renderedLineWidth
        if let brushProfile {
            drawTextureLayers(
                brushProfile.textureLayers,
                kind: .softHalo,
                includeMatchingKind: true,
                forPath: renderPath,
                color: strokeColor,
                lineWidth: renderedLineWidth
            )
        }

        strokeColor.withAlphaComponent(alpha).setStroke()
        renderPath.stroke()

        if let brushProfile {
            drawTextureLayers(
                brushProfile.textureLayers,
                kind: .softHalo,
                includeMatchingKind: false,
                forPath: renderPath,
                color: strokeColor,
                lineWidth: renderedLineWidth
            )
            if brushProfile.grainAlpha > 0.0 {
                drawCrayonGrain(
                    forStroke: stroke,
                    forPath: renderPath,
                    color: strokeColor,
                    lineWidth: renderedLineWidth,
                    alpha: CGFloat(brushProfile.grainAlpha),
                    clipWidthMultiplier: CGFloat(brushProfile.grainClipWidthMultiplier)
                )
            }
        }
    }

    private func drawTextureLayers(
        _ layers: [KCStrokeRenderMath.TextureLayer],
        kind: KCStrokeRenderMath.TextureLayer.Kind,
        includeMatchingKind: Bool,
        forPath path: UIBezierPath,
        color: UIColor,
        lineWidth: CGFloat
    ) {
        for layer in layers {
            guard (layer.kind == kind) == includeMatchingKind else { continue }
            color.withAlphaComponent(CGFloat(layer.alpha)).setStroke()
            let texturePath = path.copy() as! UIBezierPath
            texturePath.lineCapStyle = layer.kind == .waxSmear ? .butt : path.lineCapStyle
            texturePath.lineWidth = max(0.7, lineWidth * CGFloat(layer.widthMultiplier))
            texturePath.apply(CGAffineTransform(translationX: CGFloat(layer.offsetX), y: CGFloat(layer.offsetY)))
            if !layer.dashPatternMultipliers.isEmpty {
                var dashPattern = layer.dashPatternMultipliers.map { max(1.0, lineWidth * CGFloat($0)) }
                let dashPhase = lineWidth * CGFloat(layer.dashPhaseMultiplier)
                dashPattern.withUnsafeMutableBufferPointer { buffer in
                    texturePath.setLineDash(buffer.baseAddress, count: buffer.count, phase: dashPhase)
                }
            }
            texturePath.stroke()
        }
    }

    private func drawCrayonGrain(
        forStroke stroke: KDStroke,
        forPath path: UIBezierPath,
        color: UIColor,
        lineWidth: CGFloat,
        alpha: CGFloat,
        clipWidthMultiplier: CGFloat
    ) {
        let bounds = path.cgPath.boundingBoxOfPath
        if bounds.isEmpty {
            return
        }

        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        let clipPath = path.copy() as! UIBezierPath
        clipPath.lineWidth = max(2.0, lineWidth * clipWidthMultiplier)
        clipPath.lineCapStyle = .round
        clipPath.lineJoinStyle = .round
        clipPath.addClip()

        let dashWidth = self.drawingEngine.crayonGrainDashWidth(lineWidth: lineWidth)
        let dashPoints = cachedCrayonGrainDashPoints(forStroke: stroke, pathBounds: bounds, lineWidth: lineWidth)
        let grainPath = crayonGrainPath(from: dashPoints, lineWidth: dashWidth)

        color.withAlphaComponent(alpha).setStroke()
        grainPath.stroke()

        // 叠加浅色纸纹间隙，让蜡笔读起来像蜡痕压在纸面上，而不是平滑粗马克笔。
        context?.setBlendMode(.normal)
        UIColor.white.withAlphaComponent(0.64).setStroke()
        let paperToothPath = crayonGrainPath(
            from: dashPoints,
            lineWidth: max(1.0, dashWidth * 0.90),
            pointOffset: CGPoint(x: dashWidth * 1.05, y: -dashWidth * 0.72),
            stride: 4
        )
        paperToothPath.stroke()

        UIColor.white.withAlphaComponent(0.34).setStroke()
        let secondaryToothPath = crayonGrainPath(
            from: dashPoints,
            lineWidth: max(0.8, dashWidth * 0.58),
            pointOffset: CGPoint(x: -dashWidth * 0.82, y: dashWidth * 0.56),
            stride: 6
        )
        secondaryToothPath.stroke()

        UIColor.white.withAlphaComponent(0.20).setStroke()
        let fineToothPath = crayonGrainPath(
            from: dashPoints,
            lineWidth: max(0.7, dashWidth * 0.42),
            pointOffset: CGPoint(x: dashWidth * 0.42, y: dashWidth * 1.08),
            stride: 8
        )
        fineToothPath.stroke()

        context?.restoreGState()
    }

    private func crayonGrainPath(
        from dashPoints: [NSValue],
        lineWidth: CGFloat,
        pointOffset: CGPoint = .zero,
        stride: Int = 2
    ) -> UIBezierPath {
        let grainPath = UIBezierPath()
        grainPath.lineWidth = lineWidth
        grainPath.lineCapStyle = .round
        grainPath.lineJoinStyle = .round

        let pointCount = dashPoints.count
        let requestedStep = max(2, stride)
        let step = requestedStep.isMultiple(of: 2) ? requestedStep : requestedStep + 1
        var index = 0
        while index + 1 < pointCount {
            let start = dashPoints[index].cgPointValue
            let end = dashPoints[index + 1].cgPointValue
            grainPath.move(to: CGPoint(x: start.x + pointOffset.x, y: start.y + pointOffset.y))
            grainPath.addLine(to: CGPoint(x: end.x + pointOffset.x, y: end.y + pointOffset.y))
            index += step
        }
        return grainPath
    }

    private func cachedCrayonGrainDashPoints(forStroke stroke: KDStroke,
        pathBounds: CGRect,
        lineWidth: CGFloat
    ) -> [NSValue] {
        if let cachedCrayonGrainDashPoints = stroke.cachedCrayonGrainDashPoints,
           abs(stroke.cachedCrayonGrainDashLineWidth - lineWidth) < 0.001 {
            return cachedCrayonGrainDashPoints
        }

        let dashPoints = self.drawingEngine.crayonGrainDashPoints(pathBounds: pathBounds, lineWidth: lineWidth)
        stroke.cachedCrayonGrainDashPoints = dashPoints
        stroke.cachedCrayonGrainDashLineWidth = lineWidth
        return dashPoints
    }

    // MARK: - Dab 渲染（T094：铅笔/蜡笔专业质感）

    private static let brushTipVariantCount = 8

    private lazy var brushTipCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 64
        return cache
    }()

    private func dabTextureSeed(for style: KDBrushStyle) -> UInt64 {
        switch style {
        case .pencil: return KCBrushPreset.preset(for: .pencil).textureSeed
        case .pen: return KCBrushPreset.preset(for: .pen).textureSeed
        case .crayon: return KCBrushPreset.preset(for: .crayon).textureSeed
        }
    }

    /// 样张/基线渲染用的默认画笔尺寸（= 各风格 `referenceLineWidth`），保证样张以 1.0 倍缩放呈现（T111）。
    private func dabReferenceLineWidth(for style: KDBrushStyle) -> Double {
        switch style {
        case .pencil: return KCBrushPreset.preset(for: .pencil).referenceLineWidth
        case .pen: return KCBrushPreset.preset(for: .pen).referenceLineWidth
        case .crayon: return KCBrushPreset.preset(for: .crayon).referenceLineWidth
        }
    }

    private func resolvedDabs(for stroke: KDStroke) -> [KCBrushDab] {
        if let cached = stroke.cachedDabs { return cached }
        let dabs = self.drawingEngine.brushDabs(
            for: stroke.samples,
            canvasScale: 1.0,
            brushStyle: stroke.brushStyle.rawValue,
            lineWidth: Double(stroke.lineWidth)
        )
        stroke.cachedDabs = dabs
        return dabs
    }

    private func drawDabStroke(_ stroke: KDStroke) {
        let dabs = resolvedDabs(for: stroke)
        guard !dabs.isEmpty else { return }
        drawDabs(dabs,
                 brushStyle: stroke.brushStyle,
                 textureSeed: dabTextureSeed(for: stroke.brushStyle),
                 color: stroke.color)
    }

    /// 生成（或从缓存取）着色软边纹理 stamp：径向衰减盘 + 确定性颗粒。
    /// 缓存键为 (brushStyle, textureSeed, 颜色 RGBA, 变体索引)，避免移动阶段分配图片。
    private func brushTipImage(
        brushStyle: KDBrushStyle,
        textureSeed: UInt64,
        color: UIColor,
        variantIndex: Int
    ) -> UIImage {
        var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
        color.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
        let cacheKey = "\(brushStyle.rawValue)|\(textureSeed)|\(cr)|\(cg)|\(cb)|\(ca)|\(variantIndex)" as NSString
        if let cached = brushTipCache.object(forKey: cacheKey) {
            return cached
        }

        let edge = 80
        let variantSeed = kcBrushDabMix(seed: textureSeed, index: UInt64(variantIndex))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: edge, height: edge))
        let image = renderer.image { rendererContext in
            self.renderBrushTip(into: rendererContext.cgContext,
                                edge: CGFloat(edge),
                                brushStyle: brushStyle,
                                textureSeed: variantSeed,
                                color: color)
        }
        brushTipCache.setObject(image, forKey: cacheKey)
        return image
    }

    private func brushTipImages(
        brushStyle: KDBrushStyle,
        textureSeed: UInt64,
        color: UIColor
    ) -> [UIImage] {
        (0..<Self.brushTipVariantCount).map { variantIndex in
            brushTipImage(
                brushStyle: brushStyle,
                textureSeed: textureSeed,
                color: color,
                variantIndex: variantIndex
            )
        }
    }

    /// 在第一次移动事件前准备全部纹理，避免 touchesMoved 间接创建 UIImage。
    private func prewarmBrushTipVariants(for stroke: KDStroke) {
        guard stroke.toolMode == .brush,
              stroke.brushStyle == .pencil || stroke.brushStyle == .crayon else { return }
        _ = brushTipImages(
            brushStyle: stroke.brushStyle,
            textureSeed: dabTextureSeed(for: stroke.brushStyle),
            color: stroke.color
        )
    }

    private func renderBrushTip(into ctx: CGContext,
                                edge: CGFloat,
                                brushStyle: KDBrushStyle,
                                textureSeed: UInt64,
                                color: UIColor) {
        let center = CGPoint(x: edge / 2.0, y: edge / 2.0)
        let radius = edge / 2.0
        var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
        color.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)

        // 软边径向渐变盘，硬度控制衰减起点（钢笔锐、铅笔中、蜡笔柔）。
        let hardness: CGFloat = brushStyle == .pen ? 0.95 : (brushStyle == .pencil ? 0.55 : 0.34)
        let fadeStart = max(0.0, min(0.98, 1.0 - hardness))
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let coreColor = UIColor(red: cr, green: cg, blue: cb, alpha: ca).cgColor
        let midColor = UIColor(red: cr, green: cg, blue: cb, alpha: ca * 0.7).cgColor
        let fadeColor = UIColor(red: cr, green: cg, blue: cb, alpha: 0.0).cgColor
        if let gradient = CGGradient(colorsSpace: colorspace,
                                     colors: [coreColor, midColor, fadeColor] as CFArray,
                                     locations: [0.0, fadeStart, 1.0]) {
            ctx.drawRadialGradient(gradient,
                                   startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: radius,
                                   options: [])
        }

        // 颗粒纹理（铅笔=石墨颗粒、蜡笔=蜡块颗粒），位置/大小/浓度由 textureSeed 确定，
        //    故相同 stroke 重绘结果一致，undo/redo 不闪烁。
        guard brushStyle != .pen else { return }
        let speckCount = brushStyle == .crayon ? 46 : 30
        let maxSpeckRadius = brushStyle == .crayon ? radius * 0.18 : radius * 0.10
        for index in 1...speckCount {
            let h = kcBrushDabMix(seed: textureSeed, index: UInt64(index))
            let angle = CGFloat(Double(h & 0xFFFF) / 65535.0) * .pi * 2.0
            let dist = CGFloat(Double((h >> 16) & 0xFFFF) / 65535.0) * radius * 0.92
            let speckAlpha = CGFloat(Double((h >> 32) & 0xFFFF) / 65535.0)
            let sx = center.x + cos(angle) * dist
            let sy = center.y + sin(angle) * dist
            let speck = max(0.8, maxSpeckRadius * (0.4 + 0.6 * speckAlpha))
            UIColor(red: cr, green: cg, blue: cb,
                    alpha: ca * (0.25 + 0.45 * speckAlpha)).setFill()
            ctx.fillEllipse(in: CGRect(x: sx - speck, y: sy - speck,
                                       width: speck * 2.0, height: speck * 2.0))
        }
    }

    private func drawDabs(_ dabs: [KCBrushDab],
                          brushStyle: KDBrushStyle,
                          textureSeed: UInt64,
                          color: UIColor) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let tips = brushTipImages(brushStyle: brushStyle, textureSeed: textureSeed, color: color)
        let clipBounds = ctx.boundingBoxOfClipPath
        for dab in dabs {
            guard clipBounds.intersects(dab.bounds(inset: 1.0)) else { continue }
            let alpha = CGFloat(max(0.0, min(1.0, dab.alpha * dab.flow)))
            guard alpha > 0.001, dab.radius > 0 else { continue }
            let variantIndex = Int(dab.seed % UInt64(Self.brushTipVariantCount))
            let tip = tips[variantIndex]
            let halfWidth = CGFloat(dab.radius * dab.aspectRatio)
            let halfHeight = CGFloat(dab.radius)
            ctx.saveGState()
            ctx.translateBy(x: dab.center.x, y: dab.center.y)
            ctx.rotate(by: CGFloat(dab.rotation))
            let localRect = CGRect(x: -halfWidth, y: -halfHeight,
                                   width: halfWidth * 2.0, height: halfHeight * 2.0)
            tip.draw(in: localRect, blendMode: .normal, alpha: alpha)
            ctx.restoreGState()
        }
    }

    #if DEBUG
    // MARK: - 画笔样张（T095，仅 Debug）

    /// Debug-only：把铅笔/钢笔/蜡笔的横线、曲线、快速线、压力渐变样张渲染成一张图，
    /// 供 runtime acceptance 落盘 PNG 做人工视觉对比。固定颜色/尺寸/seed，可复现。
    func renderBrushSampleSheet() -> UIImage? {
        let styles: [KDBrushStyle] = [.pencil, .pen, .crayon]
        let rowHeight: CGFloat = 280
        let sheetWidth: CGFloat = 1200
        let sheetHeight = rowHeight * CGFloat(styles.count) + 60
        let color = UIColor(red: 0.94, green: 0.43, blue: 0.45, alpha: 1.0)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: sheetWidth, height: sheetHeight))
        return renderer.image { rendererContext in
            let ctx = rendererContext.cgContext
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))

            for (index, style) in styles.enumerated() {
                let rowTop = 30 + CGFloat(index) * rowHeight
                let seed = dabTextureSeed(for: style)
                let strokes: [[KCBrushInputSample]] = [
                    Self.brushSampleLine(y: rowTop + 50, pressure: 1.0, dt: 0.016),
                    Self.brushSampleCurve(centerY: rowTop + 110, pressure: 1.0),
                    Self.brushSampleLine(y: rowTop + 170, pressure: 1.0, dt: 0.004),
                    Self.brushSamplePressureGradient(y: rowTop + 230)
                ]
                for samples in strokes {
                    let dabs = drawingEngine.brushDabs(
                        for: samples,
                        canvasScale: 1.0,
                        brushStyle: style.rawValue,
                        lineWidth: dabReferenceLineWidth(for: style)
                    )
                    drawDabs(dabs, brushStyle: style, textureSeed: seed, color: color)
                }
            }
        }
    }

    private static func brushSampleLine(y: CGFloat, pressure: Double, dt: TimeInterval,
                                        startX: CGFloat = 80, endX: CGFloat = 1120,
                                        step: CGFloat = 8) -> [KCBrushInputSample] {
        var samples: [KCBrushInputSample] = []
        var time: TimeInterval = 0
        var x = startX
        while x <= endX {
            samples.append(KCBrushInputSample(point: CGPoint(x: x, y: y), timestamp: time,
                                              pressure: pressure, velocity: 0,
                                              altitude: Double.pi / 2.0, azimuth: 0, isPencil: true))
            x += step
            time += dt
        }
        return samples
    }

    private static func brushSampleCurve(centerY: CGFloat, pressure: Double,
                                        startX: CGFloat = 80, endX: CGFloat = 1120,
                                        step: CGFloat = 8, amplitude: CGFloat = 18) -> [KCBrushInputSample] {
        var samples: [KCBrushInputSample] = []
        var time: TimeInterval = 0
        var x = startX
        let span = endX - startX
        while x <= endX {
            let phase = (x - startX) / max(span, 1) * .pi * 2.0
            samples.append(KCBrushInputSample(point: CGPoint(x: x, y: centerY + sin(phase) * amplitude),
                                              timestamp: time, pressure: pressure, velocity: 0,
                                              altitude: Double.pi / 2.0, azimuth: 0, isPencil: true))
            x += step
            time += 0.016
        }
        return samples
    }

    private static func brushSamplePressureGradient(y: CGFloat,
                                                    startX: CGFloat = 80, endX: CGFloat = 1120,
                                                    step: CGFloat = 8) -> [KCBrushInputSample] {
        var samples: [KCBrushInputSample] = []
        var time: TimeInterval = 0
        var x = startX
        let span = endX - startX
        while x <= endX {
            let pressure = 0.2 + 0.8 * min(1, max(0, (x - startX) / max(span, 1)))
            samples.append(KCBrushInputSample(point: CGPoint(x: x, y: y), timestamp: time,
                                              pressure: pressure, velocity: 0,
                                              altitude: Double.pi / 2.0, azimuth: 0, isPencil: true))
            x += step
            time += 0.016
        }
        return samples
    }

    /// T116：量化活动笔画增量处理、蜡笔几何和 300 条历史笔画的 viewport 缓存行为。
    func runtimeAcceptanceBrushInteractionMetrics() -> [String: Any] {
        let sampleCount = 600
        let samples = (0..<sampleCount).map { index in
            KCBrushInputSample(
                point: CGPoint(x: 24.0 + CGFloat(index) * 1.8, y: 120.0),
                timestamp: Double(index) * 0.004,
                pressure: 0.35 + Double(index % 17) / 26.0,
                velocity: 0,
                altitude: Double.pi / 2.0,
                azimuth: 0,
                isPencil: true
            )
        }
        let batchSizes = [1, 8, 4, 12, 6, 10]
        var batches: [[KCBrushInputSample]] = []
        var sampleIndex = 0
        var batchIndex = 0
        while sampleIndex < samples.count {
            let endIndex = min(sampleIndex + batchSizes[batchIndex % batchSizes.count], samples.count)
            batches.append(Array(samples[sampleIndex..<endIndex]))
            sampleIndex = endIndex
            batchIndex += 1
        }

        let lineWidth = KCBrushPreset.preset(for: .crayon).referenceLineWidth
        let fullStart = CFAbsoluteTimeGetCurrent()
        var fullPrefixCount = 0
        for batch in batches {
            fullPrefixCount += batch.count
            let dabs = drawingEngine.brushDabs(
                for: Array(samples.prefix(fullPrefixCount)),
                canvasScale: 1.0,
                brushStyle: KDBrushStyle.crayon.rawValue,
                lineWidth: lineWidth
            )
            if var bounds = dabs.first?.bounds(inset: 2.0) {
                for dab in dabs.dropFirst() {
                    bounds = bounds.union(dab.bounds(inset: 2.0))
                }
                _ = bounds
            }
        }
        let repeatedFullGenerationMs = (CFAbsoluteTimeGetCurrent() - fullStart) * 1_000.0

        let incrementalStroke = KDStroke()
        incrementalStroke.color = currentColor
        incrementalStroke.lineWidth = CGFloat(lineWidth)
        incrementalStroke.toolMode = .brush
        incrementalStroke.brushStyle = .crayon
        var appendBatchDurationsMs: [Double] = []
        appendBatchDurationsMs.reserveCapacity(batches.count)
        for batch in batches {
            let start = CFAbsoluteTimeGetCurrent()
            _ = appendIncrementalDabs(batch, to: incrementalStroke)
            appendBatchDurationsMs.append((CFAbsoluteTimeGetCurrent() - start) * 1_000.0)
        }
        let incrementalGenerationMs = appendBatchDurationsMs.reduce(0, +)
        let incrementalVsFullRatio = repeatedFullGenerationMs > 0
            ? incrementalGenerationMs / repeatedFullGenerationMs
            : 0
        let sortedBatchDurations = appendBatchDurationsMs.sorted()
        let p95Index = max(0, min(
            sortedBatchDurations.count - 1,
            Int(ceil(Double(sortedBatchDurations.count) * 0.95)) - 1
        ))
        let appendBatchP95Ms = sortedBatchDurations.isEmpty ? 0 : sortedBatchDurations[p95Index]
        let appendBatchMaxMs = sortedBatchDurations.last ?? 0

        let geometryCenter = CGPoint(x: 300.0, y: 220.0)
        let geometrySamples = (0..<128).map { index in
            KCBrushInputSample(
                point: geometryCenter,
                timestamp: Double(index) * 0.004,
                pressure: 0.5 + Double(index % 8) / 16.0,
                velocity: 0,
                altitude: index.isMultiple(of: 2) ? 0 : Double.pi / 2.0,
                azimuth: Double(index) * 0.07,
                isPencil: true
            )
        }
        let geometryDabs = drawingEngine.brushDabs(
            for: geometrySamples,
            canvasScale: 1.0,
            brushStyle: KDBrushStyle.crayon.rawValue,
            lineWidth: lineWidth
        )
        var crayonMaxOffsetRatio = 0.0
        var crayonMaxAspectRatio = 0.0
        var geometryFinite = true
        for dab in geometryDabs {
            let offset = Double(hypot(dab.center.x - geometryCenter.x, dab.center.y - geometryCenter.y))
            let offsetRatio = dab.radius > 0 ? offset / dab.radius : .infinity
            crayonMaxOffsetRatio = max(crayonMaxOffsetRatio, offsetRatio)
            crayonMaxAspectRatio = max(crayonMaxAspectRatio, dab.aspectRatio)
            geometryFinite = geometryFinite
                && dab.center.x.isFinite
                && dab.center.y.isFinite
                && dab.radius.isFinite
                && dab.rotation.isFinite
                && dab.aspectRatio.isFinite
        }

        activeStroke = nil
        backgroundImage = nil
        strokes.removeAll(keepingCapacity: true)
        let drawingBounds = bounds.isEmpty
            ? CGRect(x: 0, y: 0, width: 1_024, height: 720)
            : bounds
        for index in 0..<300 {
            let row = CGFloat(index % 60)
            let column = CGFloat(index / 60)
            let y = drawingBounds.minY + 20.0 + row * max(2.0, (drawingBounds.height - 40.0) / 60.0)
            let xInset = 16.0 + column * 5.0
            let path = UIBezierPath()
            path.move(to: CGPoint(x: drawingBounds.minX + xInset, y: y))
            path.addLine(to: CGPoint(x: drawingBounds.maxX - xInset, y: y + CGFloat(index % 3) - 1.0))

            let stroke = KDStroke()
            stroke.path = path
            stroke.color = UIColor(
                red: 0.25 + CGFloat(index % 5) * 0.08,
                green: 0.35,
                blue: 0.55,
                alpha: 1.0
            )
            stroke.lineWidth = 2.0 + CGFloat(index % 3)
            stroke.pressureTotal = 1.0
            stroke.pressureSampleCount = 1
            stroke.startPoint = path.currentPoint
            stroke.toolMode = .brush
            stroke.brushStyle = .pen
            strokes.append(stroke)
        }

        invalidateNonStickerRasterCache()
        completedStrokeReplayCount = 0
        rasterRebuildCount = 0
        _ = rasterImageExcludingStickers()
        let replayCountBeforeViewportFrames = completedStrokeReplayCount
        let rebuildCountBeforeViewportFrames = rasterRebuildCount

        let frameCount = 20
        let frameFormat = UIGraphicsImageRendererFormat()
        frameFormat.scale = 1.0
        frameFormat.opaque = true
        let frameRenderer = UIGraphicsImageRenderer(bounds: drawingBounds, format: frameFormat)
        let viewportFramesStart = CFAbsoluteTimeGetCurrent()
        for frameIndex in 0..<frameCount {
            viewportState.scale = frameIndex.isMultiple(of: 2) ? 1.35 : 0.8
            viewportState.translation = CGPoint(
                x: CGFloat((frameIndex % 5) - 2) * 8.0,
                y: CGFloat((frameIndex % 3) - 1) * 6.0
            )
            viewportState = viewportState.clamped
            _ = frameRenderer.image { _ in
                draw(drawingBounds)
            }
        }
        let viewportFramesDurationMs = (CFAbsoluteTimeGetCurrent() - viewportFramesStart) * 1_000.0
        let replayCountAfterViewportFrames = completedStrokeReplayCount
        let rebuildCountAfterViewportFrames = rasterRebuildCount
        let viewportTriggeredStrokeReplay = replayCountAfterViewportFrames != replayCountBeforeViewportFrames
            || rebuildCountAfterViewportFrames != rebuildCountBeforeViewportFrames
        viewportState = viewportState.defaultState

        let completedStrokeCount = strokes.count
        let passed = incrementalVsFullRatio <= 0.35
            && appendBatchP95Ms <= 8.0
            && appendBatchMaxMs < 50.0
            && completedStrokeCount == 300
            && !viewportTriggeredStrokeReplay
            && crayonMaxOffsetRatio <= 0.060001
            && crayonMaxAspectRatio <= 1.35
            && geometryFinite

        return [
            "passed": passed,
            "sampleCount": sampleCount,
            "batchCount": batches.count,
            "repeatedFullGenerationMs": repeatedFullGenerationMs,
            "incrementalGenerationMs": incrementalGenerationMs,
            "incrementalVsFullRatio": incrementalVsFullRatio,
            "appendBatchP95Ms": appendBatchP95Ms,
            "appendBatchMaxMs": appendBatchMaxMs,
            "incrementalDabCount": incrementalStroke.cachedDabs?.count ?? 0,
            "completedStrokeCount": completedStrokeCount,
            "viewportFrameCount": frameCount,
            "viewportFramesDurationMs": viewportFramesDurationMs,
            "viewportAverageFPS": viewportFramesDurationMs > 0
                ? Double(frameCount) * 1_000.0 / viewportFramesDurationMs
                : 0,
            "replayCountBeforeViewportFrames": replayCountBeforeViewportFrames,
            "replayCountAfterViewportFrames": replayCountAfterViewportFrames,
            "rebuildCountBeforeViewportFrames": rebuildCountBeforeViewportFrames,
            "rebuildCountAfterViewportFrames": rebuildCountAfterViewportFrames,
            "viewportTriggeredStrokeReplay": viewportTriggeredStrokeReplay,
            "crayonMaxOffsetRatio": crayonMaxOffsetRatio,
            "crayonMaxAspectRatio": crayonMaxAspectRatio,
            "geometryFinite": geometryFinite
        ]
    }
    #endif

    private func strokeRenderBounds(_ stroke: KDStroke) -> CGRect {
        if let cachedRenderBounds = stroke.cachedRenderBounds {
            return cachedRenderBounds
        }

        let renderBounds: CGRect
        if stroke.toolMode == .brush,
           stroke.brushStyle == .pencil || stroke.brushStyle == .crayon,
           !stroke.samples.isEmpty {
            // 铅笔/蜡笔：dirty rect 由 dab bounds 取并集（含少量 inset 覆盖抖动/纹理）。
            let dabs = resolvedDabs(for: stroke)
            if dabs.isEmpty {
                renderBounds = CGRect(x: stroke.startPoint.x, y: stroke.startPoint.y, width: 1.0, height: 1.0)
            } else {
                var union = dabs[0].bounds(inset: 2.0)
                for dab in dabs.dropFirst() {
                    union = union.union(dab.bounds(inset: 2.0))
                }
                renderBounds = union
            }
        } else {
            let rawBounds = stroke.path.cgPath.boundingBoxOfPath
            let baseBounds: CGRect
            if rawBounds.isNull || rawBounds.isEmpty {
                baseBounds = CGRect(x: stroke.startPoint.x, y: stroke.startPoint.y, width: 1.0, height: 1.0)
            } else {
                baseBounds = rawBounds
            }
            let inset = max(24.0, stroke.lineWidth * 3.0)
            renderBounds = baseBounds.insetBy(dx: -inset, dy: -inset)
        }

        stroke.cachedRenderBounds = renderBounds
        return renderBounds
    }

    private func invalidateStrokeRenderBounds(_ stroke: KDStroke) {
        stroke.cachedRenderBounds = nil
        stroke.cachedCrayonGrainDashPoints = nil
        stroke.cachedCrayonGrainDashLineWidth = 0
    }

    private func setNeedsDisplayForStroke(_ stroke: KDStroke) {
        setNeedsDisplayForStrokeBounds(strokeRenderBounds(stroke))
    }

    private func setNeedsDisplayForStrokeBounds(_ redrawBounds: CGRect) {
        if redrawBounds.isNull || redrawBounds.isEmpty {
            setNeedsDisplay()
            return
        }

        // 笔画脏区在内容坐标空间，经 viewport 变换到屏幕坐标后再裁剪到视图 bounds。
        let viewBounds = redrawBounds.applying(viewportState.affineTransform)
        let clippedBounds = viewBounds.intersection(bounds)
        if clippedBounds.isNull || clippedBounds.isEmpty {
            return
        }

        setNeedsDisplay(clippedBounds.integral)
    }

    // MARK: - 触摸处理

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if event?.allTouches?.count ?? 0 > 1 {
            return
        }

        guard let touch = touches.first else { return }
        // 屏幕点用于印章命中测试（印章子视图按屏幕坐标定位）；
        // 内容点用于绘制、填色、取色、印章插入，确保缩放/平移后不偏移。
        let screenPoint = touch.location(in: self)
        let contentPoint = canvasPoint(forViewPoint: screenPoint)

        if hitTestSticker(at: screenPoint) {
            return
        }

        if currentToolMode == .picker {
            let pickedColor = colorAtPoint(contentPoint)
            currentColor = pickedColor ?? currentColor
            delegate?.drawingCanvasView(self, didPickColor: currentColor)
            return
        }

        if currentToolMode == .fill {
            beginFloodFill(at: contentPoint, color: currentColor)
            return
        }

        if currentToolMode == .sticker {
            let normalized = CGPoint(x: contentPoint.x / max(viewportState.contentSize.width, 1.0),
                                     y: contentPoint.y / max(viewportState.contentSize.height, 1.0))
            insertStickerSymbol(currentStickerSymbol, atNormalizedPoint: normalized)
            delegate?.drawingCanvasViewDidInsertSticker?(self)
            return
        }

        pendingStrokeState = canvasStateSnapshot()
        activeStrokeDidMutate = false
        let stroke = KDStroke()
        stroke.color = currentColor
        stroke.lineWidth = currentToolMode == .eraser ? max(16.0, currentLineWidth * 1.35) : currentLineWidth
        stroke.toolMode = currentToolMode
        stroke.brushStyle = currentBrushStyle
        stroke.eraserShape = currentEraserShape
        stroke.path = UIBezierPath()
        stroke.path.lineWidth = stroke.lineWidth
        stroke.startPoint = contentPoint
        prewarmBrushTipVariants(for: stroke)
        addPressureSample(from: touch, to: stroke)
        if let sample = makeDabSample(
            contentPoint: contentPoint,
            isPencil: touch.type == .pencil,
            touch: touch,
            for: stroke
        ) {
            _ = appendIncrementalDabs([sample], to: stroke)
        }
        stroke.path.move(to: contentPoint)
        activeStroke = stroke

        deselectSticker()
        setNeedsDisplayForStroke(stroke)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if event?.allTouches?.count ?? 0 > 1 {
            let activeBounds = activeStroke.map { strokeRenderBounds($0) }
            activeStroke = nil
            pendingStrokeState = nil
            activeStrokeDidMutate = false
            if let activeBounds {
                setNeedsDisplayForStrokeBounds(activeBounds)
            } else {
                setNeedsDisplay()
            }
            return
        }

        guard let activeStroke else { return }

        guard let touch = touches.first else { return }
        let previousStrokeBounds = strokeRenderBounds(activeStroke)
        let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
        var didAppendPoint = false
        var pendingDabSamples: [KCBrushInputSample] = []
        pendingDabSamples.reserveCapacity(coalescedTouches.count)
        for coalescedTouch in coalescedTouches {
            let contentPoint = canvasPoint(forViewPoint: coalescedTouch.location(in: self))
            let dx = contentPoint.x - activeStroke.startPoint.x
            let dy = contentPoint.y - activeStroke.startPoint.y
            if !activeStrokeDidMutate && hypot(dx, dy) < 2.0 {
                continue
            }

            activeStroke.path.addLine(to: contentPoint)
            addPressureSample(from: coalescedTouch, to: activeStroke)
            if let sample = makeDabSample(
                contentPoint: contentPoint,
                isPencil: coalescedTouch.type == .pencil,
                touch: coalescedTouch,
                for: activeStroke
            ) {
                pendingDabSamples.append(sample)
            }
            activeStrokeDidMutate = true
            didAppendPoint = true
        }
        if didAppendPoint {
            if !pendingDabSamples.isEmpty {
                if let newDabBounds = appendIncrementalDabs(pendingDabSamples, to: activeStroke) {
                    setNeedsDisplayForStrokeBounds(newDabBounds)
                }
            } else {
                invalidateStrokeRenderBounds(activeStroke)
                let redrawBounds = previousStrokeBounds.union(strokeRenderBounds(activeStroke))
                setNeedsDisplayForStrokeBounds(redrawBounds)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeStroke else { return }

        guard let touch = touches.first else { return }
        let previousStrokeBounds = strokeRenderBounds(activeStroke)
        let contentPoint = canvasPoint(forViewPoint: touch.location(in: self))
        if activeStrokeDidMutate {
            activeStroke.path.addLine(to: contentPoint)
            addPressureSample(from: touch, to: activeStroke)
            if let sample = makeDabSample(
                contentPoint: contentPoint,
                isPencil: touch.type == .pencil,
                touch: touch,
                for: activeStroke
            ) {
                _ = appendIncrementalDabs([sample], to: activeStroke)
            } else {
                invalidateStrokeRenderBounds(activeStroke)
            }
        } else {
            let dotRadius = max(1.0, activeStroke.lineWidth * 0.5)
            activeStroke.path = UIBezierPath(ovalIn: CGRect(x: activeStroke.startPoint.x - dotRadius,
                                                             y: activeStroke.startPoint.y - dotRadius,
                                                             width: dotRadius * 2.0,
                                                             height: dotRadius * 2.0))
            activeStroke.path.lineWidth = activeStroke.lineWidth
            activeStroke.dotStroke = true
            activeStrokeDidMutate = true
            addPressureSample(from: touch, to: activeStroke)
            if let sample = makeDabSample(
                contentPoint: contentPoint,
                isPencil: touch.type == .pencil,
                touch: touch,
                for: activeStroke
            ) {
                _ = appendIncrementalDabs([sample], to: activeStroke)
            } else {
                invalidateStrokeRenderBounds(activeStroke)
            }
        }
        commitUndoStateSnapshot(pendingStrokeState)
        strokes.append(activeStroke)
        appendCommittedStrokeToRasterCache(activeStroke)
        self.activeStroke = nil
        pendingStrokeState = nil
        activeStrokeDidMutate = false
        setNeedsDisplayForStrokeBounds(previousStrokeBounds.union(strokeRenderBounds(activeStroke)))
        notifyContentChanged()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        let activeBounds = activeStroke.map { strokeRenderBounds($0) }
        activeStroke = nil
        pendingStrokeState = nil
        activeStrokeDidMutate = false
        if let activeBounds {
            setNeedsDisplayForStrokeBounds(activeBounds)
        } else {
            setNeedsDisplay()
        }
    }

    private func addPressureSample(from touch: UITouch, to stroke: KDStroke) {
        stroke.pressureTotal += normalizedPressure(for: touch)
        stroke.pressureSampleCount += 1
    }

    /// 为铅笔/蜡笔创建一个高保真 dab 输入采样（含倾角）。
    /// 其余工具（钢笔、橡皮等）返回 nil，drawStroke 会回落到 path 渲染。
    /// `contentPoint` 必须已经是内容坐标（经 viewport 反变换）。
    private func makeDabSample(
        contentPoint: CGPoint,
        isPencil: Bool,
        touch: UITouch,
        for stroke: KDStroke
    ) -> KCBrushInputSample? {
        guard stroke.toolMode == .brush,
              stroke.brushStyle == .pencil || stroke.brushStyle == .crayon else { return nil }
        return KCBrushInputSample(
            point: contentPoint,
            timestamp: touch.timestamp,
            pressure: normalizedPressure(for: touch),
            velocity: 0,
            altitude: isPencil ? Double(touch.altitudeAngle) : Double.pi / 2.0,
            azimuth: Double(touch.azimuthAngle(in: self)),
            isPencil: isPencil
        )
    }

    /// 把一个触摸批次追加到活动笔画，只生成新增 dab，并累计局部渲染范围。
    @discardableResult
    private func appendIncrementalDabs(
        _ samples: [KCBrushInputSample],
        to stroke: KDStroke
    ) -> CGRect? {
        guard !samples.isEmpty else { return nil }
        stroke.samples.append(contentsOf: samples)
        let newDabs = drawingEngine.appendBrushDabs(
            for: samples,
            state: &stroke.dabGenerationState,
            canvasScale: 1.0,
            brushStyle: stroke.brushStyle.rawValue,
            lineWidth: Double(stroke.lineWidth)
        )
        guard let firstDab = newDabs.first else { return nil }

        if stroke.cachedDabs == nil {
            stroke.cachedDabs = []
        }
        stroke.cachedDabs?.append(contentsOf: newDabs)

        var newBounds = firstDab.bounds(inset: 2.0)
        for dab in newDabs.dropFirst() {
            newBounds = newBounds.union(dab.bounds(inset: 2.0))
        }
        if let cachedRenderBounds = stroke.cachedRenderBounds {
            stroke.cachedRenderBounds = cachedRenderBounds.union(newBounds)
        } else {
            stroke.cachedRenderBounds = newBounds
        }
        return newBounds
    }

    private func normalizedPressure(for touch: UITouch) -> Double {
        self.drawingEngine.normalizedPressure(
            force: touch.force,
            maximumPossibleForce: touch.maximumPossibleForce,
            isPencil: touch.type == .pencil
        )
    }

    // MARK: - 撤销 / 重做

    @objc func undoLastAction() {
        guard historyStore.canUndo else { return }
        let currentState = canvasStateSnapshot()
        guard let state = historyStore.undoState(afterRecordingRedo: currentState) else { return }
        applyCanvasState(state)
        notifyContentChanged()
    }

    @objc func redoLastAction() {
        guard historyStore.canRedo else { return }
        let currentState = canvasStateSnapshot()
        guard let state = historyStore.redoState(afterRecordingUndo: currentState) else { return }
        applyCanvasState(state)
        notifyContentChanged()
    }

    @objc func clearCanvas() {
        if !canvasHasVisibleContent {
            return
        }
        commitCurrentStateForUndo()
        resetCanvasContents()
        setNeedsDisplay()
        notifyContentChanged()
    }

    @objc func startBlankCanvas() {
        resetCanvasContents()
        clearHistoryStacks()
        restoreDefaultViewport()
        setNeedsDisplay()
        notifyContentChanged()
    }

#if DEBUG
    @objc func insertRuntimeAcceptanceStroke() {
        commitCurrentStateForUndo()

        let drawingBounds = bounds.isEmpty ? CGRect(x: 0.0, y: 0.0, width: 1024.0, height: 720.0) : bounds
        let start = CGPoint(x: drawingBounds.minX + drawingBounds.width * 0.28,
                            y: drawingBounds.minY + drawingBounds.height * 0.58)
        let controlOne = CGPoint(x: drawingBounds.minX + drawingBounds.width * 0.42,
                                 y: drawingBounds.minY + drawingBounds.height * 0.34)
        let controlTwo = CGPoint(x: drawingBounds.minX + drawingBounds.width * 0.58,
                                 y: drawingBounds.minY + drawingBounds.height * 0.72)
        let end = CGPoint(x: drawingBounds.minX + drawingBounds.width * 0.74,
                          y: drawingBounds.minY + drawingBounds.height * 0.46)

        let path = UIBezierPath()
        path.move(to: start)
        path.addCurve(to: end, controlPoint1: controlOne, controlPoint2: controlTwo)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = max(currentLineWidth, 18.0)

        let stroke = KDStroke()
        stroke.path = path
        stroke.color = currentColor
        stroke.lineWidth = path.lineWidth
        stroke.pressureTotal = 1.0
        stroke.pressureSampleCount = 1
        stroke.startPoint = start
        stroke.toolMode = .brush
        stroke.brushStyle = currentBrushStyle
        stroke.eraserShape = currentEraserShape
        strokes.append(stroke)
        appendCommittedStrokeToRasterCache(stroke)

        setNeedsDisplayForStroke(stroke)
        notifyContentChanged()
    }

    @objc func insertRuntimeAcceptanceEraserStroke() {
        commitCurrentStateForUndo()

        let drawingBounds = bounds.isEmpty ? CGRect(x: 0.0, y: 0.0, width: 1024.0, height: 720.0) : bounds
        let start = CGPoint(x: drawingBounds.minX + drawingBounds.width * 0.22,
                            y: drawingBounds.minY + drawingBounds.height * 0.56)
        let end = CGPoint(x: drawingBounds.minX + drawingBounds.width * 0.78,
                          y: drawingBounds.minY + drawingBounds.height * 0.48)

        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = max(42.0, currentLineWidth * 1.35)

        let stroke = KDStroke()
        stroke.path = path
        stroke.color = .white
        stroke.lineWidth = path.lineWidth
        stroke.pressureTotal = 1.0
        stroke.pressureSampleCount = 1
        stroke.startPoint = start
        stroke.toolMode = .eraser
        stroke.brushStyle = currentBrushStyle
        stroke.eraserShape = currentEraserShape
        strokes.append(stroke)
        appendCommittedStrokeToRasterCache(stroke)

        setNeedsDisplayForStroke(stroke)
        notifyContentChanged()
    }

    @objc func performRuntimeAcceptanceFloodFill(atNormalizedPoint normalizedPoint: CGPoint) -> Bool {
        let drawingBounds = bounds.isEmpty ? CGRect(x: 0.0, y: 0.0, width: 1024.0, height: 720.0) : bounds
        let point = CGPoint(x: drawingBounds.minX + drawingBounds.width * normalizedPoint.x,
                            y: drawingBounds.minY + drawingBounds.height * normalizedPoint.y)
        let previousState = canvasStateSnapshot()
        if performFloodFill(at: point, color: currentColor) {
            commitUndoStateSnapshot(previousState)
            return true
        }
        return false
    }

    @objc func runtimeAcceptancePickedColor(atNormalizedPoint normalizedPoint: CGPoint) -> UIColor? {
        let drawingBounds = bounds.isEmpty ? CGRect(x: 0.0, y: 0.0, width: 1024.0, height: 720.0) : bounds
        let point = CGPoint(x: drawingBounds.minX + drawingBounds.width * normalizedPoint.x,
                            y: drawingBounds.minY + drawingBounds.height * normalizedPoint.y)
        return colorAtPoint(point)
    }

    /// T097 runtime acceptance：直接设置 viewport 缩放/平移（自动钳制），用于在非默认视口下验收。
    @objc func runtimeAcceptanceSetViewport(scale: CGFloat, translation: CGPoint) {
        viewportState.scale = KCCanvasViewportState.clampedScale(scale)
        viewportState.translation = translation
        viewportState = viewportState.clamped
        applyViewportToStickerViews()
        setNeedsDisplay()
        notifyViewportChanged()
    }

    /// T097 runtime acceptance：返回屏幕点经 viewport 反变换后的内容点，用于验证坐标转换非恒等。
    @objc func runtimeAcceptanceCanvasPoint(forScreenPoint screenPoint: CGPoint) -> CGPoint {
        canvasPoint(forViewPoint: screenPoint)
    }

    /// T107 runtime acceptance：返回给定缩放下“内容中心对齐安全创作区中心”的默认平移量，
    /// 用于在缩小态断言用户平移未被强制吸回默认居中（旧实现会把任何缩小态平移吸回该值）。
    @objc func runtimeAcceptanceDefaultTranslation(forScale scale: CGFloat) -> CGPoint {
        viewportState.defaultTranslation(forScale: KCCanvasViewportState.clampedScale(scale))
    }
#endif

    @objc func snapshotImage() -> UIImage {
        guard bounds.width > 0.0 && bounds.height > 0.0 else { return UIImage() }

        let selectedSticker = self.selectedStickerView
        let selectedBorderWidth = selectedSticker?.layer.borderWidth ?? 0
        let selectedBorderColor = selectedSticker?.layer.borderColor
        selectedSticker?.layer.borderWidth = 0.0

        let scale = self.window?.screen.scale ?? UIScreen.main.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        let image = renderer.image { context in
            let baseImage = rasterImageExcludingStickers(includeActiveStroke: activeStroke != nil)
            baseImage.draw(in: bounds)
            drawStickerViewsForSnapshot(in: context.cgContext)
        }

        selectedSticker?.layer.borderWidth = selectedBorderWidth
        selectedSticker?.layer.borderColor = selectedBorderColor
        return image
    }

    private func rasterImageExcludingStickers(includeActiveStroke: Bool = false) -> UIImage {
        guard bounds.width > 0.0 && bounds.height > 0.0 else { return UIImage() }

        let scale = self.window?.screen.scale ?? UIScreen.main.scale
        let completedImage: UIImage
        if let cachedImage = nonStickerRasterCacheImage,
           nonStickerRasterCacheBounds.equalTo(bounds),
           abs(nonStickerRasterCacheScale - scale) < 0.001 {
            completedImage = cachedImage
        } else {
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = true
            let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
            completedImage = renderer.image { rendererContext in
                UIColor.white.setFill()
                rendererContext.cgContext.fill(bounds)
                drawImage(backgroundImage, aspectFitIn: bounds)

                #if DEBUG
                rasterRebuildCount += 1
                completedStrokeReplayCount += strokes.count
                #endif
                for stroke in strokes {
                    drawStroke(stroke)
                }
            }
            cacheNonStickerRasterImage(completedImage, scale: scale)
        }

        guard includeActiveStroke, let activeStroke else {
            return completedImage
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        return renderer.image { _ in
            completedImage.draw(in: bounds)
            drawStroke(activeStroke)
        }
    }

    private func drawStickerViewsForSnapshot(in context: CGContext) {
        for sticker in stickers {
            guard !sticker.isHidden, sticker.alpha > 0.0 else { continue }

            // 快照在内容坐标空间渲染（不含 viewport）；用 canvasCenter/canvasTransform 定位，
            // 并临时把视图的屏幕变换置为恒等，避免 layer.render 叠加 viewport 派生的变换。
            let savedTransform = sticker.transform
            sticker.transform = .identity
            context.saveGState()
            context.translateBy(x: sticker.canvasCenter.x, y: sticker.canvasCenter.y)
            context.concatenate(sticker.canvasTransform)
            context.translateBy(x: -sticker.bounds.width / 2.0, y: -sticker.bounds.height / 2.0)
            sticker.layer.render(in: context)
            context.restoreGState()
            sticker.transform = savedTransform
        }
    }

    private func drawImage(_ image: UIImage?, aspectFitIn rect: CGRect) {
        guard let image else { return }

        let imageSize = image.size
        if imageSize.width <= 0.0 || imageSize.height <= 0.0 || rect.isEmpty {
            return
        }

        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(x: rect.midX - drawSize.width / 2.0,
                              y: rect.midY - drawSize.height / 2.0,
                              width: drawSize.width,
                              height: drawSize.height)
        image.draw(in: drawRect)
    }

    @objc func replaceCanvas(with image: UIImage) {
        resetCanvasContents()
        clearHistoryStacks()
        backgroundImage = image
        restoreDefaultViewport()
        setNeedsDisplay()
        notifyContentChanged()
    }

    @objc func restoreCanvas(with image: UIImage) {
        resetCanvasContents()
        clearHistoryStacks()
        backgroundImage = image
        restoreDefaultViewport()
        setNeedsDisplay()
        notifyContentChanged()
    }

    @objc func insertStickerSymbol(_ symbol: String, atNormalizedPoint normalizedPoint: CGPoint) {
        commitCurrentStateForUndo()
        let sticker = makeStickerView(withSymbol: symbol.count > 0 ? symbol : "star.fill", color: currentColor)
        let contentSize = viewportState.contentSize
        // 印章以内容坐标存储中心点；屏幕显示位置由 viewport 派生，保证缩放/平移后命中不偏移。
        sticker.canvasCenter = CGPoint(x: normalizedPoint.x * contentSize.width,
                                       y: normalizedPoint.y * contentSize.height)
        sticker.canvasTransform = .identity
        constrainStickerView(sticker)
        applyViewport(to: sticker)
        stickers.append(sticker)
        addSubview(sticker)
        bringSubviewToFront(sticker)
        selectStickerView(sticker)
        setNeedsDisplay()
        notifyContentChanged()
    }

    @objc func deleteSelectedSticker() {
        guard let selected = selectedStickerView else { return }

        commitCurrentStateForUndo()
        stickers.removeAll { $0 === selected }
        selected.removeFromSuperview()
        deselectSticker()
        setNeedsDisplay()
        notifyContentChanged()
    }

    @objc func bringSelectedStickerToFront() {
        guard let selected = selectedStickerView else { return }

        commitCurrentStateForUndo()
        bringSubviewToFront(selected)
        stickers.removeAll { $0 === selected }
        stickers.append(selected)
        notifySelectionChanged()
        notifyContentChanged()
    }

    @objc func hasSelectedSticker() -> Bool {
        selectedStickerView != nil
    }

    @objc func loadLineArtImage(_ image: UIImage) {
        resetCanvasContents()
        clearHistoryStacks()
        backgroundImage = image
        restoreDefaultViewport()
        setNeedsDisplay()
        notifyContentChanged()
    }

    // MARK: - 画布状态快照

    private func canvasStateSnapshot() -> KDCanvasState {
        let state = KDCanvasState()
        state.backgroundImage = backgroundImage
        // 已提交笔画在进入 `strokes` 后不再被修改；状态恢复时会再深拷贝。
        // 这里共享引用，避免每次落笔前把全部历史 UIBezierPath 都复制一遍。
        state.strokes = strokes
        state.stickers = stickers.map { stickerStateFromView($0) }
        return state
    }

    private func commitCurrentStateForUndo() {
        commitUndoStateSnapshot(canvasStateSnapshot())
    }

    private func commitUndoStateSnapshot(_ state: KDCanvasState?) {
        historyStore.recordUndoState(state)
    }

    private func clearHistoryStacks() {
        historyStore.clear()
    }

    private func applyCanvasState(_ state: KDCanvasState) {
        resetCanvasContents()
        backgroundImage = state.backgroundImage

        for stroke in state.strokes {
            strokes.append(copyOfStroke(stroke))
        }

        for stickerState in state.stickers {
            let sticker = stickerViewFromState(stickerState)
            stickers.append(sticker)
            addSubview(sticker)
        }

        deselectSticker()
        setNeedsDisplay()
    }

    private func resetCanvasContents() {
        cancelPendingFloodFillResult()
        invalidateNonStickerRasterCache()
        strokes.removeAll()
        for sticker in stickers {
            sticker.removeFromSuperview()
        }
        stickers.removeAll()
        backgroundImage = nil
        activeStroke = nil
        pendingStrokeState = nil
        pendingStickerTransformState = nil
        activeStrokeDidMutate = false
        stickerTransformDidMutate = false
        activeStickerGestureCount = 0
        deselectSticker()
    }

    private func cancelPendingFloodFillResult() {
        floodFillGeneration += 1
        floodFillInProgress = false
    }

    private func copyOfStroke(_ stroke: KDStroke) -> KDStroke {
        let copy = KDStroke()
        copy.path = stroke.path.copy() as! UIBezierPath
        copy.color = stroke.color
        copy.lineWidth = stroke.lineWidth
        copy.pressureTotal = stroke.pressureTotal
        copy.pressureSampleCount = stroke.pressureSampleCount
        copy.startPoint = stroke.startPoint
        copy.dotStroke = stroke.dotStroke
        copy.cachedRenderBounds = stroke.cachedRenderBounds
        copy.cachedCrayonGrainDashPoints = stroke.cachedCrayonGrainDashPoints
        copy.cachedCrayonGrainDashLineWidth = stroke.cachedCrayonGrainDashLineWidth
        copy.toolMode = stroke.toolMode
        copy.brushStyle = stroke.brushStyle
        copy.eraserShape = stroke.eraserShape
        copy.samples = stroke.samples
        copy.cachedDabs = stroke.cachedDabs
        return copy
    }

    private func stickerStateFromView(_ sticker: KDStickerView) -> KDStickerState {
        let state = KDStickerState()
        state.symbolName = sticker.symbolName
        state.symbolColor = sticker.symbolColor
        state.center = sticker.canvasCenter
        state.transform = sticker.canvasTransform
        return state
    }

    private func stickerViewFromState(_ state: KDStickerState) -> KDStickerView {
        let sticker = makeStickerView(withSymbol: state.symbolName, color: state.symbolColor)
        sticker.canvasCenter = state.center
        sticker.canvasTransform = state.transform
        constrainStickerView(sticker)
        applyViewport(to: sticker)
        return sticker
    }

    private var canvasHasVisibleContent: Bool {
        backgroundImage != nil || !strokes.isEmpty || !stickers.isEmpty
    }

    private func canvasStateHasVisibleContent(_ state: KDCanvasState) -> Bool {
        state.backgroundImage != nil || !state.strokes.isEmpty || !state.stickers.isEmpty
    }

    // MARK: - 填充 / 取色

    private func performFloodFill(at point: CGPoint, color fillColor: UIColor) -> Bool {
        let baseImage = rasterImageExcludingStickers()
        guard let sourceImageRef = baseImage.cgImage else { return false }

        let width = sourceImageRef.width
        let height = sourceImageRef.height
        if width == 0 || height == 0 {
            return false
        }

        let startX = Int(min(max(point.x * baseImage.scale, 0), CGFloat(width - 1)))
        let startY = Int(min(max(point.y * baseImage.scale, 0), CGFloat(height - 1)))

        guard let filledImage = self.drawingEngine.floodFillImage(
            sourceImageRef,
            startX: startX,
            startY: startY,
            fillColor: fillColor,
            tolerance: fillTolerance
        ) else {
            return false
        }

        let resultImage = UIImage(cgImage: filledImage, scale: baseImage.scale, orientation: .up)
        backgroundImage = resultImage
        strokes.removeAll()
        cacheNonStickerRasterImage(resultImage, scale: baseImage.scale)
        setNeedsDisplay()
        notifyContentChanged()
        return true
    }

    private func beginFloodFill(at point: CGPoint, color fillColor: UIColor) {
        guard !floodFillInProgress else { return }

        if fillColorAlreadyMatchesCanvas(at: point, fillColor: fillColor) {
            return
        }

        let previousState = canvasStateSnapshot()
        let baseImage = rasterImageExcludingStickers()
        guard let sourceImageRef = baseImage.cgImage else { return }

        let width = sourceImageRef.width
        let height = sourceImageRef.height
        if width == 0 || height == 0 {
            return
        }

        let startX = Int(min(max(point.x * baseImage.scale, 0), CGFloat(width - 1)))
        let startY = Int(min(max(point.y * baseImage.scale, 0), CGFloat(height - 1)))
        let tolerance = fillTolerance
        let generation = floodFillGeneration + 1
        floodFillGeneration = generation
        floodFillInProgress = true

        floodFillQueue.async { [weak self] in
            guard let self else { return }
            let filledImage = self.drawingEngine.floodFillImage(
                sourceImageRef,
                startX: startX,
                startY: startY,
                fillColor: fillColor,
                tolerance: tolerance
            )

            DispatchQueue.main.async { [weak self] in
                self?.applyFloodFillResult(
                    filledImage,
                    imageScale: baseImage.scale,
                    previousState: previousState,
                    generation: generation
                )
            }
        }
    }

    private func applyFloodFillResult(
        _ filledImage: CGImage?,
        imageScale: CGFloat,
        previousState: KDCanvasState,
        generation: Int
    ) {
        floodFillInProgress = false
        guard generation == floodFillGeneration else { return }
        guard let filledImage else { return }

        commitUndoStateSnapshot(previousState)
        let resultImage = UIImage(cgImage: filledImage, scale: imageScale, orientation: .up)
        backgroundImage = resultImage
        strokes.removeAll()
        cacheNonStickerRasterImage(resultImage, scale: imageScale)
        setNeedsDisplay()
        notifyContentChanged()
    }

    /// 缓存有效时只合成刚完成的一笔；缓存缺失时保留惰性全量重建策略。
    private func appendCommittedStrokeToRasterCache(_ stroke: KDStroke) {
        let scale = window?.screen.scale ?? UIScreen.main.scale
        guard let cachedImage = nonStickerRasterCacheImage,
              nonStickerRasterCacheBounds.equalTo(bounds),
              abs(nonStickerRasterCacheScale - scale) < 0.001 else {
            invalidateNonStickerRasterCache()
            return
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        let image = renderer.image { _ in
            cachedImage.draw(in: bounds)
            drawStroke(stroke)
        }
        cacheNonStickerRasterImage(image, scale: scale)
    }

    private func cacheNonStickerRasterImage(_ image: UIImage, scale: CGFloat) {
        nonStickerRasterCacheImage = image
        nonStickerRasterCacheBounds = bounds
        nonStickerRasterCacheScale = scale
    }

    private func invalidateNonStickerRasterCache() {
        nonStickerRasterCacheImage = nil
        nonStickerRasterCacheBounds = .null
        nonStickerRasterCacheScale = 0.0
    }

    private func fillColorAlreadyMatchesCanvas(at point: CGPoint, fillColor: UIColor) -> Bool {
        let image = pixelImageExcludingStickers(at: point)
        guard let imageRef = image.cgImage,
              let sampledColor = self.drawingEngine.sampleColorFromImage(imageRef, x: 0, y: 0) else {
            return false
        }

        return colorsAreVisuallyEqual(sampledColor, fillColor, tolerance: 2.0 / 255.0)
    }

    private func colorsAreVisuallyEqual(_ leftColor: UIColor, _ rightColor: UIColor, tolerance: CGFloat) -> Bool {
        let left = leftColor.resolvedColor(with: traitCollection)
        let right = rightColor.resolvedColor(with: traitCollection)
        var leftRed: CGFloat = 0.0
        var leftGreen: CGFloat = 0.0
        var leftBlue: CGFloat = 0.0
        var leftAlpha: CGFloat = 0.0
        var rightRed: CGFloat = 0.0
        var rightGreen: CGFloat = 0.0
        var rightBlue: CGFloat = 0.0
        var rightAlpha: CGFloat = 0.0

        guard left.getRed(&leftRed, green: &leftGreen, blue: &leftBlue, alpha: &leftAlpha),
              right.getRed(&rightRed, green: &rightGreen, blue: &rightBlue, alpha: &rightAlpha) else {
            return false
        }

        return abs(leftRed - rightRed) <= tolerance
            && abs(leftGreen - rightGreen) <= tolerance
            && abs(leftBlue - rightBlue) <= tolerance
            && abs(leftAlpha - rightAlpha) <= tolerance
    }

    private func colorAtPoint(_ point: CGPoint) -> UIColor? {
        let image = pixelImage(at: point)
        guard let imageRef = image.cgImage else { return nil }

        return self.drawingEngine.sampleColorFromImage(
            imageRef,
            x: 0,
            y: 0
        )
    }

    private func pixelImageExcludingStickers(at point: CGPoint) -> UIImage {
        if point.x < 0.0 || point.y < 0.0 || point.x >= bounds.width || point.y >= bounds.height {
            return UIImage()
        }

        let scale = self.window?.screen.scale ?? UIScreen.main.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let pixelSize = CGSize(width: 1.0 / scale, height: 1.0 / scale)
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        return renderer.image { context in
            context.cgContext.translateBy(x: -point.x, y: -point.y)
            UIColor.white.setFill()
            UIRectFill(bounds)
            drawImage(backgroundImage, aspectFitIn: bounds)

            for stroke in strokes {
                if strokeRenderBounds(stroke).contains(point) {
                    drawStroke(stroke)
                }
            }
        }
    }

    private func pixelImage(at contentPoint: CGPoint) -> UIImage {
        let contentSize = viewportState.contentSize
        if contentPoint.x < 0.0 || contentPoint.y < 0.0
            || contentPoint.x >= contentSize.width || contentPoint.y >= contentSize.height {
            return UIImage()
        }

        // 印章按屏幕坐标命中测试；命中时连带印章采样，需在屏幕点处渲染整层。
        let screenPoint = viewportState.viewPoint(forCanvasPoint: contentPoint)
        if sticker(at: screenPoint) == nil {
            return pixelImageExcludingStickers(at: contentPoint)
        }

        let selectedSticker = self.selectedStickerView
        let selectedBorderWidth = selectedSticker?.layer.borderWidth ?? 0
        let selectedBorderColor = selectedSticker?.layer.borderColor
        selectedSticker?.layer.borderWidth = 0.0

        let scale = self.window?.screen.scale ?? UIScreen.main.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let pixelSize = CGSize(width: 1.0 / scale, height: 1.0 / scale)
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        let image = renderer.image { context in
            context.cgContext.translateBy(x: -screenPoint.x, y: -screenPoint.y)
            self.layer.render(in: context.cgContext)
        }

        selectedSticker?.layer.borderWidth = selectedBorderWidth
        selectedSticker?.layer.borderColor = selectedBorderColor
        return image
    }

    // MARK: - 贴纸视图

    private func makeStickerView(withSymbol symbol: String, color: UIColor) -> KDStickerView {
        let sticker = stickerPresenter.makeStickerView(withSymbol: symbol, color: color)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleStickerPan(_:)))
        pan.delegate = self
        sticker.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleStickerPinch(_:)))
        pinch.delegate = self
        sticker.addGestureRecognizer(pinch)

        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleStickerRotation(_:)))
        rotation.delegate = self
        sticker.addGestureRecognizer(rotation)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleStickerTap(_:)))
        sticker.addGestureRecognizer(tap)

        return sticker
    }

    private func drawStampedEraserStroke(_ stroke: KDStroke, color strokeColor: UIColor) {
        strokeColor.withAlphaComponent(1.0).setFill()
        if stroke.dotStroke {
            let stamp = self.drawingEngine.eraserStampPath(
                shape: stroke.eraserShape.rawValue,
                center: stroke.startPoint,
                size: stroke.lineWidth
            )
            stamp?.fill()
            return
        }

        let stampPoints = self.drawingEngine.eraserStampPointsAlongPath(stroke.path.cgPath, lineWidth: stroke.lineWidth)
        for value in stampPoints {
            let stamp = self.drawingEngine.eraserStampPath(
                shape: stroke.eraserShape.rawValue,
                center: value.cgPointValue,
                size: stroke.lineWidth
            )
            stamp?.fill()
        }
    }

    @objc func handleStickerTap(_ recognizer: UITapGestureRecognizer) {
        guard let sticker = recognizer.view as? KDStickerView else { return }
        selectStickerView(sticker)
    }

    @objc func handleStickerPan(_ recognizer: UIPanGestureRecognizer) {
        guard let sticker = recognizer.view as? KDStickerView else { return }
        if recognizer.state == .began {
            beginStickerTransformIfNeeded(for: sticker)
        }
        let translation = recognizer.translation(in: self)
        let scale = viewportState.scale
        // 屏幕位移除以 viewport 缩放得到内容坐标位移，保证缩放下拖拽跟手且命中正确。
        sticker.canvasCenter = CGPoint(
            x: sticker.canvasCenter.x + translation.x / scale,
            y: sticker.canvasCenter.y + translation.y / scale
        )
        constrainStickerCenter(sticker)
        applyViewport(to: sticker)
        recognizer.setTranslation(.zero, in: self)
        stickerTransformDidMutate = true
        if recognizer.state == .ended {
            endStickerTransformIfNeeded()
            notifySelectionChanged()
        }
        if recognizer.state == .cancelled || recognizer.state == .failed {
            endStickerTransformIfNeeded()
        }
    }

    @objc func handleStickerPinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let sticker = recognizer.view as? KDStickerView else { return }
        if recognizer.state == .began {
            beginStickerTransformIfNeeded(for: sticker)
        }
        sticker.canvasTransform = sticker.canvasTransform.scaledBy(x: recognizer.scale, y: recognizer.scale)
        constrainStickerScale(sticker)
        constrainStickerCenter(sticker)
        applyViewport(to: sticker)
        recognizer.scale = 1.0
        stickerTransformDidMutate = true
        if recognizer.state == .ended {
            endStickerTransformIfNeeded()
            notifySelectionChanged()
        }
        if recognizer.state == .cancelled || recognizer.state == .failed {
            endStickerTransformIfNeeded()
        }
    }

    @objc func handleStickerRotation(_ recognizer: UIRotationGestureRecognizer) {
        guard let sticker = recognizer.view as? KDStickerView else { return }
        if recognizer.state == .began {
            beginStickerTransformIfNeeded(for: sticker)
        }
        sticker.canvasTransform = sticker.canvasTransform.rotated(by: recognizer.rotation)
        constrainStickerView(sticker)
        applyViewport(to: sticker)
        recognizer.rotation = 0.0
        stickerTransformDidMutate = true
        if recognizer.state == .ended {
            endStickerTransformIfNeeded()
            notifySelectionChanged()
        }
        if recognizer.state == .cancelled || recognizer.state == .failed {
            endStickerTransformIfNeeded()
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    private func constrainStickerView(_ sticker: KDStickerView) {
        constrainStickerScale(sticker)
        constrainStickerCenter(sticker)
    }

    private func constrainStickerScale(_ sticker: KDStickerView) {
        sticker.canvasTransform = self.drawingEngine.stickerTransformByClampingScale(sticker.canvasTransform)
    }

    private func constrainStickerCenter(_ sticker: KDStickerView) {
        let canvasBounds = CGRect(origin: .zero, size: viewportState.contentSize)
        guard !canvasBounds.isEmpty else { return }
        // 印章自身变换后的内容坐标外接矩形，用于把中心点约束在画布内容范围内。
        let contentFrame = CGRect(origin: .zero, size: sticker.bounds.size).applying(sticker.canvasTransform)
        sticker.canvasCenter = self.drawingEngine.clampStickerCenter(
            sticker.canvasCenter,
            frame: contentFrame,
            canvasBounds: canvasBounds
        )
    }

    private func hitTestSticker(at point: CGPoint) -> Bool {
        if let sticker = sticker(at: point) {
            selectStickerView(sticker)
            return true
        }
        deselectSticker()
        return false
    }

    private func sticker(at point: CGPoint) -> KDStickerView? {
        for sticker in stickers.reversed() {
            let localPoint = convert(point, to: sticker)
            if sticker.point(inside: localPoint, with: nil) {
                return sticker
            }
        }
        return nil
    }

    private func selectStickerView(_ sticker: KDStickerView) {
        deselectSticker()
        selectedStickerView = sticker
        stickerPresenter.applySelectedAppearance(to: sticker)
        notifySelectionChanged()
    }

    private func deselectSticker() {
        if let selectedStickerView {
            stickerPresenter.applyIdleAppearance(to: selectedStickerView)
        }
        selectedStickerView = nil
        notifySelectionChanged()
    }

    private func notifySelectionChanged() {
        delegate?.drawingCanvasViewSelectionDidChange?(self)
    }

    private func beginStickerTransformIfNeeded(for sticker: KDStickerView) {
        if activeStickerGestureCount == 0 {
            pendingStickerTransformState = canvasStateSnapshot()
            stickerTransformDidMutate = false
            selectStickerView(sticker)
        }
        activeStickerGestureCount += 1
    }

    private func endStickerTransformIfNeeded() {
        if activeStickerGestureCount > 0 {
            activeStickerGestureCount -= 1
        }

        if activeStickerGestureCount == 0 {
            if stickerTransformDidMutate {
                commitUndoStateSnapshot(pendingStickerTransformState)
                notifyContentChanged()
            }
            pendingStickerTransformState = nil
            stickerTransformDidMutate = false
        }
    }

    @objc func canUndo() -> Bool {
        historyStore.canUndo
    }

    @objc func canRedo() -> Bool {
        historyStore.canRedo
    }

    @objc func hasVisibleContent() -> Bool {
        canvasHasVisibleContent
    }

    /// 已提交的用户笔画数量（不含底图、填色、印章）。供“保存为线稿”最小笔画校验。
    @objc var strokeCount: Int {
        strokes.count
    }

    /// T099：把用户笔画以黑色重绘在白底，生成位图线稿。排除底图、flood fill 填色与印章，
    /// 使结果适合作为可再次填色的线稿。笔画过少时应由调用方先做 `strokeCount` 校验。
    @objc func lineArtImage() -> UIImage {
        guard bounds.width > 0.0, bounds.height > 0.0 else { return UIImage() }
        let scale = self.window?.screen.scale ?? UIScreen.main.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(bounds)
            UIColor.black.setStroke()
            for stroke in self.strokes {
                let path = stroke.path.copy() as! UIBezierPath
                path.lineWidth = max(stroke.lineWidth, 2.0)
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
        }
    }

    private func notifyContentChanged() {
        delegate?.drawingCanvasViewContentDidChange?(self)
    }

    // MARK: - 画布视口（T097：缩放 / 平移 / 恢复视图）

    /// 屏幕坐标 → 内容坐标。所有绘制、填色、取色、印章命中统一经此转换，
    /// 确保缩放/平移后落点不偏移。viewport 未配置（contentSize 为 0）时近似恒等。
    private func canvasPoint(forViewPoint point: CGPoint) -> CGPoint {
        viewportState.canvasPoint(forViewPoint: point)
    }

    /// 把单个印章按当前 viewport 派生到屏幕显示位置/变换。
    private func applyViewport(to sticker: KDStickerView) {
        let scale = viewportState.scale
        sticker.center = CGPoint(
            x: sticker.canvasCenter.x * scale + viewportState.translation.x,
            y: sticker.canvasCenter.y * scale + viewportState.translation.y
        )
        sticker.transform = sticker.canvasTransform.scaledBy(x: scale, y: scale)
    }

    /// 全量刷新所有印章的屏幕显示位置（viewport 变化或 layout 后调用）。
    private func applyViewportToStickerViews() {
        for sticker in stickers {
            applyViewport(to: sticker)
        }
    }

    private func notifyViewportChanged() {
        delegate?.drawingCanvasViewportDidChange?(self)
    }

    /// 当前是否处于默认视图（缩放 1、按安全创作区居中）。控制器据此显隐“恢复视图”按钮。
    @objc var viewportIsAtDefault: Bool {
        viewportState.isDefault
    }

    /// 当前 viewport 缩放系数，供印章手势增量换算与运行时验收读取。
    @objc var currentViewportScale: CGFloat {
        viewportState.scale
    }

    /// 当前 viewport 平移量，供运行时验收确认双指平移确实改变视图。
    @objc var currentViewportTranslation: CGPoint {
        viewportState.translation
    }

    /// 控制器注入屏幕坐标下的“安全创作区”矩形，并同步内容尺寸。仅初始或创作区变化时调用。
    @objc func applyViewportRect(_ rect: CGRect) {
        guard bounds.width > 0.0, bounds.height > 0.0 else { return }
        let wasDefault = viewportState.isDefault || viewportState.viewportRect.isEmpty
        viewportState.contentSize = bounds.size
        viewportState.viewportRect = rect
        if wasDefault {
            viewportState = viewportState.defaultState
        } else {
            viewportState = viewportState.clamped
        }
        applyViewportToStickerViews()
        setNeedsDisplay()
        notifyViewportChanged()
    }

    /// 一键恢复默认视图（缩放 1、内容中心对齐安全创作区中心）。
    @objc func restoreDefaultViewport() {
        guard viewportState.contentSize.width > 0.0 else { return }
        if viewportState.viewportRect.isEmpty {
            viewportState.scale = 1.0
            viewportState.translation = .zero
        } else {
            viewportState = viewportState.defaultState
        }
        applyViewportToStickerViews()
        setNeedsDisplay()
        notifyViewportChanged()
    }

    /// 双指捏合缩放：围绕双指中点缩放，焦点下的内容点保持不动。
    @objc private func handleCanvasPinch(_ recognizer: UIPinchGestureRecognizer) {
        let focus = recognizer.location(in: self)
        viewportState = viewportState.applyingScale(recognizer.scale, aroundViewPoint: focus)
        recognizer.scale = 1.0
        applyViewportToStickerViews()
        setNeedsDisplay()
        notifyViewportChanged()
    }

    /// 双指拖拽平移：屏幕位移直接施加到 viewport 平移，再按创作区边界钳制。
    @objc private func handleCanvasTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self)
        applyCanvasViewportTranslation(translation)
        recognizer.setTranslation(.zero, in: self)
    }

    /// 应用画布视口平移。手势和运行时验收共用同一入口，避免验收绕过真实逻辑。
    private func applyCanvasViewportTranslation(_ translation: CGPoint) {
        guard translation.x != 0.0 || translation.y != 0.0 else { return }
        viewportState = viewportState.translating(by: translation)
        applyViewportToStickerViews()
        setNeedsDisplay()
        notifyViewportChanged()
    }

#if DEBUG
    /// T106 运行时验收：模拟一次双指拖拽增量，验证放大状态下平移跟手。
    @objc func runtimeAcceptanceApplyViewportTranslation(_ translation: CGPoint) {
        applyCanvasViewportTranslation(translation)
    }
#endif

    /// 双指缩放/平移手势开始前判断：任一触点落在印章子视图上则让位给印章自身手势，
    /// 避免“在印章上双指”同时触发画布缩放与印章缩放。
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === canvasPinchGestureRecognizer
            || gestureRecognizer === canvasTwoFingerPanGestureRecognizer {
            for index in 0..<gestureRecognizer.numberOfTouches {
                let touchPoint = gestureRecognizer.location(ofTouch: index, in: self)
                if sticker(at: touchPoint) != nil {
                    return false
                }
            }
        }
        return true
    }

    @objc(eraserShapePathForShape:center:size:)
    func eraserShapePath(forShape shape: KDEraserShape, center: CGPoint, size: CGFloat) -> UIBezierPath? {
        self.drawingEngine.eraserStampPath(shape: shape.rawValue, center: center, size: size)
    }
}
