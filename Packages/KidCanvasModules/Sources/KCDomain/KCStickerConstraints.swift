//
//  KCStickerConstraints.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/26.
//

import Foundation
import CoreGraphics

/// UIKit-free geometry helpers that constrain a sticker's affine transform and
/// center to the canvas — a faithful port of the Objective-C canvas's
/// `constrainStickerScale:` and `constrainStickerCenter:`.
///
/// The live gesture handlers in `KDDrawingCanvasView` keep applying the result
/// to the UIKit view; only the pure transform/center math lives here so it is
/// unit-testable independent of UIKit.
public enum KCStickerConstraints {

    /// Minimum sticker scale (matches the prototype's `KDStickerMinimumScale`).
    public static let minimumScale: CGFloat = 0.48

    /// Maximum sticker scale (matches the prototype's `KDStickerMaximumScale`).
    public static let maximumScale: CGFloat = 2.6

    /// Uniform scale read from a live affine transform via `hypot(a, c)`, the
    /// same extraction the prototype uses when clamping sticker size.
    public static func scale(of transform: CGAffineTransform) -> CGFloat {
        hypot(transform.a, transform.c)
    }

    /// Returns `scale` clamped to `[minimumScale, maximumScale]`.
    public static func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(maximumScale, max(minimumScale, scale))
    }

    /// Returns `transform` with its uniform scale clamped to
    /// `[minimumScale, maximumScale]`, matching the prototype's
    /// `constrainStickerScale:`:
    ///   - a degenerate (non-positive) scale resets to identity;
    ///   - when the scale is already within `0.001` of the clamp, the transform
    ///     is returned unchanged (no perceptible correction needed).
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

    /// Returns `center` clamped so a sticker with the given `frame` stays
    /// reachable inside `canvasBounds`, matching the prototype's
    /// `constrainStickerCenter:`. Returns `center` unchanged when the canvas
    /// bounds are empty.
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

    /// Returns `true` when `point` lies inside `rect` (same coordinate space).
    /// A testable containment primitive backing the canvas's sticker hit testing;
    /// the UIKit canvas still performs the transform-aware point conversion.
    public static func contains(_ rect: CGRect, point: CGPoint) -> Bool {
        rect.contains(point)
    }
}
