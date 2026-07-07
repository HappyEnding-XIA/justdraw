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
}

/// 原 Objective-C `KDDrawingCanvasView` 的忠实 Swift 移植。行为保持 1:1 一致
///（触摸绘制、撤销/重做、贴纸手势、渲染）。纯绘制算法通过
/// `KCDrawingEngineProviding` 委托给 Swift 绘制引擎（与 OC 版本一致）。
@objc(KDDrawingCanvasView)
final class KCDrawingCanvasView: UIView, UIGestureRecognizerDelegate {

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
    private weak var selectedStickerView: KDStickerView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .white
        isMultipleTouchEnabled = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if nonStickerRasterCacheImage != nil && !nonStickerRasterCacheBounds.equalTo(bounds) {
            invalidateNonStickerRasterCache()
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        UIColor.white.setFill()
        UIRectFill(bounds)
        drawImage(backgroundImage, aspectFitIn: bounds)

        for stroke in strokes {
            if strokeRenderBounds(stroke).intersects(rect) {
                drawStroke(stroke)
            }
        }

        if let activeStroke {
            if strokeRenderBounds(activeStroke).intersects(rect) {
                drawStroke(activeStroke)
            }
        }
    }

    private func drawStroke(_ stroke: KDStroke) {
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
        UIColor.white.withAlphaComponent(0.42).setStroke()
        let paperToothPath = crayonGrainPath(
            from: dashPoints,
            lineWidth: max(0.9, dashWidth * 0.78),
            pointOffset: CGPoint(x: dashWidth * 0.92, y: -dashWidth * 0.62),
            stride: 4
        )
        paperToothPath.stroke()

        UIColor.white.withAlphaComponent(0.22).setStroke()
        let secondaryToothPath = crayonGrainPath(
            from: dashPoints,
            lineWidth: max(0.7, dashWidth * 0.52),
            pointOffset: CGPoint(x: -dashWidth * 0.70, y: dashWidth * 0.48),
            stride: 6
        )
        secondaryToothPath.stroke()

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

    private func strokeRenderBounds(_ stroke: KDStroke) -> CGRect {
        if let cachedRenderBounds = stroke.cachedRenderBounds {
            return cachedRenderBounds
        }

        let rawBounds = stroke.path.cgPath.boundingBoxOfPath
        let baseBounds: CGRect
        if rawBounds.isNull || rawBounds.isEmpty {
            baseBounds = CGRect(x: stroke.startPoint.x, y: stroke.startPoint.y, width: 1.0, height: 1.0)
        } else {
            baseBounds = rawBounds
        }

        let inset = max(24.0, stroke.lineWidth * 3.0)
        let renderBounds = baseBounds.insetBy(dx: -inset, dy: -inset)
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

        let clippedBounds = redrawBounds.intersection(bounds)
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
        let point = touch.location(in: self)

        if hitTestSticker(at: point) {
            return
        }

        if currentToolMode == .picker {
            let pickedColor = colorAtPoint(point)
            currentColor = pickedColor ?? currentColor
            delegate?.drawingCanvasView(self, didPickColor: currentColor)
            return
        }

        if currentToolMode == .fill {
            beginFloodFill(at: point, color: currentColor)
            return
        }

        if currentToolMode == .sticker {
            let normalized = CGPoint(x: point.x / max(bounds.width, 1.0),
                                     y: point.y / max(bounds.height, 1.0))
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
        stroke.startPoint = point
        addPressureSample(from: touch, to: stroke)
        stroke.path.move(to: point)
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
        for coalescedTouch in coalescedTouches {
            let point = coalescedTouch.location(in: self)
            let dx = point.x - activeStroke.startPoint.x
            let dy = point.y - activeStroke.startPoint.y
            if !activeStrokeDidMutate && hypot(dx, dy) < 2.0 {
                continue
            }

            activeStroke.path.addLine(to: point)
            addPressureSample(from: coalescedTouch, to: activeStroke)
            activeStrokeDidMutate = true
            didAppendPoint = true
        }
        if didAppendPoint {
            invalidateStrokeRenderBounds(activeStroke)
            let redrawBounds = previousStrokeBounds.union(strokeRenderBounds(activeStroke))
            setNeedsDisplayForStrokeBounds(redrawBounds)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeStroke else { return }

        guard let touch = touches.first else { return }
        let previousStrokeBounds = strokeRenderBounds(activeStroke)
        let point = touch.location(in: self)
        if activeStrokeDidMutate {
            activeStroke.path.addLine(to: point)
            addPressureSample(from: touch, to: activeStroke)
            invalidateStrokeRenderBounds(activeStroke)
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
            invalidateStrokeRenderBounds(activeStroke)
        }
        commitUndoStateSnapshot(pendingStrokeState)
        strokes.append(activeStroke)
        invalidateNonStickerRasterCache()
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
        invalidateNonStickerRasterCache()

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
        invalidateNonStickerRasterCache()

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
#endif

    @objc func snapshotImage() -> UIImage {
        let selectedSticker = self.selectedStickerView
        let selectedBorderWidth = selectedSticker?.layer.borderWidth ?? 0
        let selectedBorderColor = selectedSticker?.layer.borderColor
        selectedSticker?.layer.borderWidth = 0.0

        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = renderer.image { context in
            layer.render(in: context.cgContext)
        }

        selectedSticker?.layer.borderWidth = selectedBorderWidth
        selectedSticker?.layer.borderColor = selectedBorderColor
        return image
    }

    private func rasterImageExcludingStickers() -> UIImage {
        guard bounds.width > 0.0 && bounds.height > 0.0 else { return UIImage() }

        let scale = self.window?.screen.scale ?? UIScreen.main.scale
        if let cachedImage = nonStickerRasterCacheImage,
           nonStickerRasterCacheBounds.equalTo(bounds),
           abs(nonStickerRasterCacheScale - scale) < 0.001 {
            return cachedImage
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        let image = renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(bounds)
            drawImage(backgroundImage, aspectFitIn: bounds)

            for stroke in strokes {
                drawStroke(stroke)
            }
        }
        cacheNonStickerRasterImage(image, scale: scale)
        return image
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
        setNeedsDisplay()
        notifyContentChanged()
    }

    @objc func restoreCanvas(with image: UIImage) {
        resetCanvasContents()
        clearHistoryStacks()
        backgroundImage = image
        setNeedsDisplay()
        notifyContentChanged()
    }

    @objc func insertStickerSymbol(_ symbol: String, atNormalizedPoint normalizedPoint: CGPoint) {
        commitCurrentStateForUndo()
        let sticker = makeStickerView(withSymbol: symbol.count > 0 ? symbol : "star.fill", color: currentColor)
        sticker.center = CGPoint(x: normalizedPoint.x * bounds.width, y: normalizedPoint.y * bounds.height)
        constrainStickerView(sticker)
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
        return copy
    }

    private func stickerStateFromView(_ sticker: KDStickerView) -> KDStickerState {
        let state = KDStickerState()
        state.symbolName = sticker.symbolName
        state.symbolColor = sticker.symbolColor
        state.center = sticker.center
        state.transform = sticker.transform
        return state
    }

    private func stickerViewFromState(_ state: KDStickerState) -> KDStickerView {
        let sticker = makeStickerView(withSymbol: state.symbolName, color: state.symbolColor)
        sticker.center = state.center
        sticker.transform = state.transform
        constrainStickerView(sticker)
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

    private func pixelImage(at point: CGPoint) -> UIImage {
        if point.x < 0.0 || point.y < 0.0 || point.x >= bounds.width || point.y >= bounds.height {
            return UIImage()
        }

        if sticker(at: point) == nil {
            return pixelImageExcludingStickers(at: point)
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
            context.cgContext.translateBy(x: -point.x, y: -point.y)
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
        sticker.center = CGPoint(x: sticker.center.x + translation.x, y: sticker.center.y + translation.y)
        constrainStickerCenter(sticker)
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
        sticker.transform = sticker.transform.scaledBy(x: recognizer.scale, y: recognizer.scale)
        constrainStickerScale(sticker)
        constrainStickerCenter(sticker)
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
        sticker.transform = sticker.transform.rotated(by: recognizer.rotation)
        constrainStickerView(sticker)
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
        sticker.transform = self.drawingEngine.stickerTransformByClampingScale(sticker.transform)
    }

    private func constrainStickerCenter(_ sticker: KDStickerView) {
        sticker.center = self.drawingEngine.clampStickerCenter(
            sticker.center,
            frame: sticker.frame,
            canvasBounds: bounds
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

    private func notifyContentChanged() {
        delegate?.drawingCanvasViewContentDidChange?(self)
    }

    @objc(eraserShapePathForShape:center:size:)
    func eraserShapePath(forShape shape: KDEraserShape, center: CGPoint, size: CGFloat) -> UIBezierPath? {
        self.drawingEngine.eraserStampPath(shape: shape.rawValue, center: center, size: size)
    }
}
