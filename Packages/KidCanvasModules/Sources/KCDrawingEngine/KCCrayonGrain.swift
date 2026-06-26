//
//  KCCrayonGrain.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/06/26.
//

import Foundation
import CoreGraphics

/// One crayon-grain dash segment produced by `KCCrayonGrain.dashes(...)`.
///
/// A faithful Swift port of the Objective-C `drawCrayonGrainForPath:` math.
/// The UIKit/CoreGraphics drawing (clipping, color, stroking each dash) stays
/// on the Objective-C side; this struct only carries deterministic geometry.
public struct KCCrayonGrainDash {
    public let start: CGPoint
    public let end: CGPoint
    /// Constant across all dashes for a given line width:
    /// `max(0.7, lineWidth * 0.045)`.
    public let lineWidth: CGFloat

    public init(start: CGPoint, end: CGPoint, lineWidth: CGFloat) {
        self.start = start
        self.end = end
        self.lineWidth = lineWidth
    }
}

/// Deterministic crayon grain generation — a UIKit-free port of the prototype's
/// `-[KDDrawingCanvasView drawCrayonGrainForPath:color:lineWidth:]` algorithm.
///
/// The integer seed arithmetic and all constants are lifted verbatim from the
/// Objective-C implementation, so the produced dash points are bit-identical to
/// the original for any given (`pathBounds`, `lineWidth`). This guarantees a
/// pixel-level visual match: the Objective-C drawing code is unchanged and now
/// consumes identical geometry.
public enum KCCrayonGrain {

    /// Returns the jittered dash segments that form the crayon grain texture over
    /// a stroke whose path bounding box is `bounds` and rendered line width is
    /// `lineWidth`.
    public static func dashes(pathBounds bounds: CGRect, lineWidth: CGFloat) -> [KCCrayonGrainDash] {
        guard !bounds.isEmpty else { return [] }

        // grainBounds = bounds expanded by lineWidth/2 on every side.
        let grainBounds = bounds.insetBy(dx: -lineWidth * 0.5, dy: -lineWidth * 0.5)

        let spacing = max(4.0, lineWidth * 0.46)
        let columnCount = min(220, max(1, Int(ceil(grainBounds.width / spacing))))
        let rowCount = min(180, max(1, Int(ceil(grainBounds.height / spacing))))
        let dashWidth = max(0.7, lineWidth * 0.045)

        var dashes: [KCCrayonGrainDash] = []
        dashes.reserveCapacity((rowCount + 1) * (columnCount + 1))

        for row in 0...rowCount {
            for column in 0...columnCount {
                let seed = row * 37 + column * 17
                let jitterX = CGFloat((seed % 7) - 3) * 0.34
                let jitterY = CGFloat(((seed / 3) % 7) - 3) * 0.28
                let x = grainBounds.minX + CGFloat(column) * spacing + jitterX
                let y = grainBounds.minY + CGFloat(row) * spacing + jitterY
                let dashLength = max(1.5, lineWidth * (0.10 + CGFloat(seed % 5) * 0.018))
                let yOffset: CGFloat = (seed % 2 == 0) ? 0.7 : -0.7
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
