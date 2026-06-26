//
//  KCDrawingEngineBridge.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import UIKit
import KCCommon
import KCDomain
import KCDrawingEngine

/// Bridges the UIKit-free `KCDrawingEngine` algorithms to the Objective-C canvas.
///
/// Each method is a thin adapter that converts between UIKit/CoreGraphics types
/// (UIColor, CGImage, UITouch forces) and the engine's pure-Swift types
/// (KCRGBA8, KCBitmapBuffer, KCFloodFillEngine, KCColorSampler, KCPressureModel).
///
/// The Objective-C `KDDrawingCanvasView` calls these methods and handles all
/// canvas state management (backgroundImage, strokes, setNeedsDisplay, undo).
///
/// NOTE: This is a temporary migration bridge. Once the canvas is fully in Swift,
/// call the engine directly.
@objc(KCDrawingEngineBridge)
final class KCDrawingEngineBridge: NSObject {

    /// Performs a flood fill on `image` starting at pixel coordinates
    /// (`startX`, `startY`) with `fillColor`, using the prototype's
    /// `tolerance * 4` Manhattan-delta rule.
    ///
    /// Returns the filled image, or `nil` if no pixels changed or the image
    /// could not be decoded.
    @objc static func floodFillImage(
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

    /// Samples a single pixel color from `image` at pixel coordinates
    /// (`x`, `y`) using the same 1×1 bitmap-context trick as the prototype's
    /// `colorAtPoint:` — no full KCBitmapBuffer allocation needed.
    @objc static func sampleColorFromImage(
        _ image: CGImage,
        x: Int,
        y: Int
    ) -> UIColor? {
        guard let buffer = KCBitmapBuffer(cgImage: image),
              let pixel = KCColorSampler.sample(buffer: buffer, x: x, y: y) else {
            return nil
        }
        return UIColor(
            red: CGFloat(pixel.red) / 255.0,
            green: CGFloat(pixel.green) / 255.0,
            blue: CGFloat(pixel.blue) / 255.0,
            alpha: CGFloat(pixel.alpha) / 255.0
        )
    }

    /// Normalizes raw force values into the prototype's 0.65–1.45 (Pencil) or
    /// 0.92–1.18 (finger) pressure range.
    ///
    /// Returns `1.0` when the device does not report force
    /// (`maximumPossibleForce <= 0`), matching the prototype's early-out.
    @objc static func normalizedPressure(
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

    // MARK: - KCStroke rendering metrics

    /// Returns the rendered line width for the given brush configuration.
    /// The caller (OC `drawStroke:`) handles the eraser pressure override
    /// (forces `averagePressure = 1.0` for eraser) before calling this method.
    /// `brushStyle` matches the OC `KDBrushStyle` raw value:
    /// 0 = pencil, 1 = pen, 2 = crayon.
    @objc static func renderedStrokeLineWidth(
        brushStyle: Int,
        lineWidth: Double,
        averagePressure: Double
    ) -> Double {
        guard let style = brushStyleFromOC(brushStyle) else { return lineWidth }
        return KCStrokeRenderMath.renderedMetrics(
            brushStyle: style, lineWidth: lineWidth, pressure: averagePressure
        ).renderedLineWidth
    }

    /// Returns the rendered alpha for the given brush configuration.
    @objc static func renderedStrokeAlpha(
        brushStyle: Int,
        lineWidth: Double,
        averagePressure: Double
    ) -> Double {
        guard let style = brushStyleFromOC(brushStyle) else { return 1.0 }
        return KCStrokeRenderMath.renderedMetrics(
            brushStyle: style, lineWidth: lineWidth, pressure: averagePressure
        ).alpha
    }

    // MARK: - Eraser stamp path

    /// Returns a `UIBezierPath` for the given eraser shape at `center` and
    /// `size`, wrapped from the CoreGraphics `KCEraserStampPath` engine.
    /// `shape` matches the OC `KDEraserShape` raw value:
    /// 0 = circle, 1 = cloud, 2 = star.
    @objc static func eraserStampPath(
        shape: Int,
        center: CGPoint,
        size: CGFloat
    ) -> UIBezierPath? {
        guard let eraserShape = eraserShapeFromOC(shape) else { return nil }
        let cgPath = KCEraserStampPath.path(for: eraserShape, center: center, size: size)
        return UIBezierPath(cgPath: cgPath)
    }

    // MARK: - Eraser stamp interpolation

    /// Returns interpolated stamp center positions along `path`, spaced by
    /// `max(6, lineWidth × 0.38)`. OC code iterates these points and fills
    /// the eraser stamp shape at each position.
    /// Returns `NSValue`-wrapped `CGPoint` arrays for ObjC consumption.
    @objc static func eraserStampPointsAlongPath(
        _ path: CGPath,
        lineWidth: CGFloat
    ) -> [NSValue] {
        KCEraserStampPath.interpolatedStampPoints(along: path, lineWidth: lineWidth)
            .map { NSValue(cgPoint: $0) }
    }

    // MARK: - Crayon grain

    /// Returns the crayon grain dash endpoints for a stroke whose path bounding
    /// box is `pathBounds` and rendered line width is `lineWidth`, computed by
    /// the Swift `KCCrayonGrain` engine. The Objective-C caller draws each dash
    /// (clip / color / stroke) in UIKit.
    ///
    /// Each dash is encoded as two consecutive `NSValue`-wrapped `CGPoint`s
    /// (start, then end); the returned array length is always even. Use
    /// `crayonGrainDashWidth(lineWidth:)` for the constant per-dash stroke width.
    @objc static func crayonGrainDashPoints(
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

    /// The constant per-dash stroke width for the crayon grain texture
    /// (`max(0.7, lineWidth * 0.045)`). Equal to each dash's `lineWidth` produced
    /// by `KCCrayonGrain.dashes(...)`; exposed separately so the Objective-C grain
    /// drawer does not re-derive the constant inline.
    @objc static func crayonGrainDashWidth(lineWidth: CGFloat) -> CGFloat {
        max(0.7, lineWidth * 0.045)
    }

    // MARK: - Sticker transform constraints

    /// Returns the sticker's affine transform with its uniform scale clamped to
    /// the prototype's `[0.48, 2.6]` range (degenerate → identity). The ObjC
    /// pinch handler applies the result to the view; only the math lives in
    /// Swift (`KCStickerConstraints`).
    @objc static func stickerTransformByClampingScale(
        _ transform: CGAffineTransform
    ) -> CGAffineTransform {
        KCStickerConstraints.transformWithClampedScale(transform)
    }

    /// Returns the sticker `center` clamped so the sticker stays reachable inside
    /// `canvasBounds`. The ObjC pan handler applies the result to the view.
    @objc static func clampStickerCenter(
        _ center: CGPoint,
        frame: CGRect,
        canvasBounds: CGRect
    ) -> CGPoint {
        KCStickerConstraints.clampedCenter(center, frame: frame, canvasBounds: canvasBounds)
    }

    // MARK: - History paging (KCHistoryFeature boundary)

    /// Highest valid history page index for `sessionCount` sessions at `pageSize`.
    /// Delegates to the Swift `KCHistoryPaging` history-Feature model.
    @objc static func historyMaxPageIndex(sessionCount: Int, pageSize: Int) -> Int {
        KCHistoryPaging(sessionCount: sessionCount, pageSize: pageSize).maxPageIndex
    }

    /// `pageIndex` clamped to the valid range for `sessionCount`/`pageSize`.
    @objc static func historyClampedPageIndex(
        _ pageIndex: Int,
        sessionCount: Int,
        pageSize: Int
    ) -> Int {
        KCHistoryPaging(sessionCount: sessionCount, pageSize: pageSize, pageIndex: pageIndex).clampedPageIndex
    }

    /// Absolute session index for a thumbnail slot `thumbIndex` on `pageIndex`.
    @objc static func historySessionIndex(
        thumbIndex: Int,
        pageIndex: Int,
        pageSize: Int
    ) -> Int {
        KCHistoryPaging(sessionCount: 0, pageSize: pageSize, pageIndex: pageIndex)
            .sessionIndex(forThumb: thumbIndex)
    }

    // MARK: - Private enum mapping (OC Int → Swift String enum)

    /// Maps OC `KDBrushStyle` integer (0=pencil, 1=pen, 2=crayon) to the Swift
    /// `KCBrushStyle` enum. Returns `nil` for out-of-range values.
    private static func brushStyleFromOC(_ value: Int) -> KCBrushStyle? {
        switch value {
        case 0: return .pencil
        case 1: return .pen
        case 2: return .crayon
        default: return nil
        }
    }

    /// Maps OC `KDEraserShape` integer (0=circle, 1=cloud, 2=star) to the Swift
    /// `KCEraserShape` enum. Returns `nil` for out-of-range values.
    private static func eraserShapeFromOC(_ value: Int) -> KCEraserShape? {
        switch value {
        case 0: return .circle
        case 1: return .cloud
        case 2: return .star
        default: return nil
        }
    }
}
