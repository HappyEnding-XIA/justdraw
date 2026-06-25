import Foundation
import CoreGraphics
import KCDomain

/// Generates the `CGPath` for a single eraser stamp, ported from
/// `-[KDDrawingCanvasView eraserShapePathForShape:center:size:]`.
///
/// The cloud and five-point star shapes are produced procedurally so the
/// stamped eraser can render identical outlines to the prototype.
public enum EraserStampPath {
    /// Returns the closed path for `shape` centered at `center`, sized from `size`.
    public static func path(for shape: EraserShape, center: CGPoint, size: CGFloat) -> CGPath {
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

    /// Five-point star outline (alternating outer/inner radii), matching the prototype.
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
