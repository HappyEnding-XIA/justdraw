//
//  KCDrawingCanvasView.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/26.
//

import UIKit
import KCDomain

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

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        UIColor.white.setFill()
        UIRectFill(bounds)
        drawImage(backgroundImage, aspectFitIn: bounds)

        for stroke in strokes {
            drawStroke(stroke)
        }

        if let activeStroke {
            drawStroke(activeStroke)
        }
    }

    private func drawStroke(_ stroke: KDStroke) {
        let strokeColor: UIColor = stroke.toolMode == .eraser ? .white : stroke.color
        let pressure: CGFloat = stroke.toolMode == .eraser ? 1.0 : stroke.averagePressure
        let renderedLineWidth = self.drawingEngine.renderedStrokeLineWidth(
            brushStyle: stroke.brushStyle.rawValue,
            lineWidth: stroke.lineWidth,
            averagePressure: pressure
        )
        let alpha = self.drawingEngine.renderedStrokeAlpha(
            brushStyle: stroke.brushStyle.rawValue,
            lineWidth: stroke.lineWidth,
            averagePressure: pressure
        )

        if stroke.toolMode == .eraser && stroke.eraserShape != .circle {
            drawStampedEraserStroke(stroke, color: strokeColor)
            return
        }

        strokeColor.withAlphaComponent(alpha).setStroke()
        let renderPath = stroke.path.copy() as! UIBezierPath
        renderPath.lineCapStyle = .round
        renderPath.lineJoinStyle = .round
        renderPath.lineWidth = renderedLineWidth
        renderPath.stroke()

        if stroke.brushStyle == .pencil && stroke.toolMode != .eraser {
            strokeColor.withAlphaComponent(0.16).setStroke()
            let softPath = renderPath.copy() as! UIBezierPath
            softPath.lineWidth = max(1.0, renderedLineWidth * 1.45)
            softPath.stroke()
        }

        if stroke.brushStyle == .crayon && stroke.toolMode != .eraser {
            for index in 0..<3 {
                strokeColor.withAlphaComponent(0.16).setStroke()
                let texturePath = renderPath.copy() as! UIBezierPath
                texturePath.lineWidth = max(1.0, renderedLineWidth * 0.28)
                let transform = CGAffineTransform(translationX: CGFloat(index - 1) * 1.8,
                                                  y: index % 2 == 0 ? 1.2 : -1.2)
                texturePath.apply(transform)
                texturePath.stroke()
            }
            drawCrayonGrain(forPath: renderPath, color: strokeColor, lineWidth: renderedLineWidth)
        }
    }

    private func drawCrayonGrain(forPath path: UIBezierPath, color: UIColor, lineWidth: CGFloat) {
        let bounds = path.cgPath.boundingBoxOfPath
        if bounds.isEmpty {
            return
        }

        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        let clipPath = path.copy() as! UIBezierPath
        clipPath.lineWidth = max(2.0, lineWidth * 1.06)
        clipPath.lineCapStyle = .round
        clipPath.lineJoinStyle = .round
        clipPath.addClip()

        color.withAlphaComponent(0.18).setStroke()
        let dashWidth = self.drawingEngine.crayonGrainDashWidth(lineWidth: lineWidth)
        let dashPoints = self.drawingEngine.crayonGrainDashPoints(pathBounds: bounds, lineWidth: lineWidth)
        let pointCount = dashPoints.count
        var index = 0
        while index + 1 < pointCount {
            let start = dashPoints[index].cgPointValue
            let end = dashPoints[index + 1].cgPointValue
            let dash = UIBezierPath()
            dash.lineWidth = dashWidth
            dash.lineCapStyle = .round
            dash.move(to: start)
            dash.addLine(to: end)
            dash.stroke()
            index += 2
        }

        context?.restoreGState()
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
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if event?.allTouches?.count ?? 0 > 1 {
            activeStroke = nil
            pendingStrokeState = nil
            activeStrokeDidMutate = false
            setNeedsDisplay()
            return
        }

        guard let activeStroke else { return }

        guard let touch = touches.first else { return }
        let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
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
        }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeStroke else { return }

        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        if activeStrokeDidMutate {
            activeStroke.path.addLine(to: point)
            addPressureSample(from: touch, to: activeStroke)
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
        }
        commitUndoStateSnapshot(pendingStrokeState)
        strokes.append(activeStroke)
        self.activeStroke = nil
        pendingStrokeState = nil
        activeStrokeDidMutate = false
        setNeedsDisplay()
        notifyContentChanged()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeStroke = nil
        pendingStrokeState = nil
        activeStrokeDidMutate = false
        setNeedsDisplay()
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

        setNeedsDisplay()
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

        setNeedsDisplay()
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
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(bounds)
            drawImage(backgroundImage, aspectFitIn: bounds)

            for stroke in strokes {
                drawStroke(stroke)
            }
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
        state.strokes = strokes.map { copyOfStroke($0) }
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

        backgroundImage = UIImage(cgImage: filledImage, scale: baseImage.scale, orientation: .up)
        strokes.removeAll()
        setNeedsDisplay()
        notifyContentChanged()
        return true
    }

    private func beginFloodFill(at point: CGPoint, color fillColor: UIColor) {
        guard !floodFillInProgress else { return }

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
        backgroundImage = UIImage(cgImage: filledImage, scale: imageScale, orientation: .up)
        strokes.removeAll()
        setNeedsDisplay()
        notifyContentChanged()
    }

    private func colorAtPoint(_ point: CGPoint) -> UIColor? {
        let image = snapshotImage()
        guard let imageRef = image.cgImage else { return nil }

        let imageSize = image.size
        if imageSize.width <= 0.0 || imageSize.height <= 0.0 {
            return nil
        }

        if point.x < 0.0 || point.y < 0.0 || point.x >= imageSize.width || point.y >= imageSize.height {
            return nil
        }

        return self.drawingEngine.sampleColorFromImage(
            imageRef,
            x: Int(point.x * image.scale),
            y: Int(point.y * image.scale)
        )
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
        for sticker in stickers.reversed() {
            let localPoint = convert(point, to: sticker)
            if sticker.point(inside: localPoint, with: nil) {
                selectStickerView(sticker)
                return true
            }
        }
        deselectSticker()
        return false
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
