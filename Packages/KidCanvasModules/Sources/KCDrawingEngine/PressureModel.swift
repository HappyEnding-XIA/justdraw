import Foundation
import KCDomain

/// Pure pressure normalization, ported from
/// `-[KDDrawingCanvasView normalizedPressureForTouch:]`.
///
/// Splitting the math out of the touch handler makes it unit-testable and lets
/// the eventual UIKit canvas view stay a thin adapter over this model.
public enum PressureModel {
    /// Finger (non-Pencil) normalization:
    /// `min(1.18, max(0.92, 0.96 + normalizedForce * 0.28))`.
    public static func finger(normalizedForce: Double) -> Double {
        min(1.18, max(0.92, 0.96 + normalizedForce * 0.28))
    }

    /// Apple Pencil normalization:
    /// `min(1.45, max(0.65, 0.72 + normalizedForce * 0.95))`.
    public static func pencil(normalizedForce: Double) -> Double {
        min(1.45, max(0.65, 0.72 + normalizedForce * 0.95))
    }

    /// Full normalization from raw force values.
    ///
    /// `normalizedForce` is `force / maximumPossibleForce`. When the device does
    /// not report force (`maximumPossibleForce <= 0`), returns `1.0`, matching the
    /// prototype's early-out.
    public static func normalized(
        force: Double,
        maximumPossibleForce: Double,
        isPencil: Bool
    ) -> Double {
        guard maximumPossibleForce > 0 else { return 1.0 }
        let normalizedForce = force / maximumPossibleForce
        return isPencil
            ? pencil(normalizedForce: normalizedForce)
            : finger(normalizedForce: normalizedForce)
    }
}
