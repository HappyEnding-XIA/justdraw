//
//  KCColorSampler.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCCommon

/// Point color sampling, the engine-layer analogue of the prototype's
/// `colorAtPoint:` eyedropper.
public enum KCColorSampler {
    /// Returns the pixel color at `(x, y)`, or `nil` when the point is out of bounds.
    public static func sample(buffer: KCBitmapBuffer, x: Int, y: Int) -> KCRGBA8? {
        guard x >= 0, x < buffer.width, y >= 0, y < buffer.height else { return nil }
        return buffer.pixel(x: x, y: y)
    }

    /// Convenience: returns the sampled color as a `KCHexColor`.
    public static func sampleHex(buffer: KCBitmapBuffer, x: Int, y: Int) -> KCHexColor? {
        guard let rgba = sample(buffer: buffer, x: x, y: y) else { return nil }
        return KCHexColor(
            red: Double(rgba.red) / 255.0,
            green: Double(rgba.green) / 255.0,
            blue: Double(rgba.blue) / 255.0,
            alpha: Double(rgba.alpha) / 255.0
        )
    }
}
