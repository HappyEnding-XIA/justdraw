import Foundation
import KCCommon

/// Point color sampling, the engine-layer analogue of the prototype's
/// `colorAtPoint:` eyedropper.
public enum ColorSampler {
    /// Returns the pixel color at `(x, y)`, or `nil` when the point is out of bounds.
    public static func sample(buffer: BitmapBuffer, x: Int, y: Int) -> RGBA8? {
        guard x >= 0, x < buffer.width, y >= 0, y < buffer.height else { return nil }
        return buffer.pixel(x: x, y: y)
    }

    /// Convenience: returns the sampled color as a `HexColor`.
    public static func sampleHex(buffer: BitmapBuffer, x: Int, y: Int) -> HexColor? {
        guard let rgba = sample(buffer: buffer, x: x, y: y) else { return nil }
        return HexColor(
            red: Double(rgba.red) / 255.0,
            green: Double(rgba.green) / 255.0,
            blue: Double(rgba.blue) / 255.0,
            alpha: Double(rgba.alpha) / 255.0
        )
    }
}
