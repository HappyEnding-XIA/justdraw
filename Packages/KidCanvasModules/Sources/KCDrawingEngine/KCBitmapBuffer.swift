//
//  KCBitmapBuffer.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import CoreGraphics

/// A mutable KCRGBA8 bitmap, the bridge between `CGImage` raster data and the
/// pure-logic engines (flood fill, sampling).
///
/// Storage is `[UInt8]` in RGBA order, four bytes per pixel, `width * height`
/// pixels row-major. Interop with `CGImage` uses the same bitmap info as the
/// Objective-C prototype (`premultipliedLast | byteOrder32Big`) so that pixel
/// values round-trip identically.
public final class KCBitmapBuffer {
    public let width: Int
    public let height: Int
    public private(set) var pixels: [UInt8]

    /// Creates a buffer filled with a single color.
    public init(width: Int, height: Int, fill: KCRGBA8 = .white) {
        precondition(width >= 0 && height >= 0, "KCBitmapBuffer dimensions must be non-negative")
        self.width = width
        self.height = height
        let count = width * height * 4
        var pixels = [UInt8](repeating: 0, count: count)
        if count > 0 {
            var index = 0
            while index < count {
                pixels[index] = fill.red
                pixels[index + 1] = fill.green
                pixels[index + 2] = fill.blue
                pixels[index + 3] = fill.alpha
                index += 4
            }
        }
        self.pixels = pixels
    }

    /// Creates a buffer by rasterizing a `CGImage`. Returns `nil` for empty or
    /// un-decodable images.
    public init?(cgImage: CGImage) {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }
        self.width = width
        self.height = height

        let bytesPerRow = width * 4
        let byteCount = bytesPerRow * height
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 16)
        defer { buffer.deallocate() }
        memset(buffer, 0, byteCount)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels = [UInt8](repeating: 0, count: byteCount)
        pixels.withUnsafeMutableBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            memcpy(base, buffer, byteCount)
        }
        self.pixels = pixels
    }

    private func pixelIndex(x: Int, y: Int) -> Int {
        (y * width + x) * 4
    }

    /// Reads the pixel at `(x, y)`. Assumes the coordinate is in bounds.
    public func pixel(x: Int, y: Int) -> KCRGBA8 {
        let index = pixelIndex(x: x, y: y)
        return KCRGBA8(
            red: pixels[index],
            green: pixels[index + 1],
            blue: pixels[index + 2],
            alpha: pixels[index + 3]
        )
    }

    /// Writes `rgba` at `(x, y)`. Assumes the coordinate is in bounds.
    public func setPixel(_ rgba: KCRGBA8, x: Int, y: Int) {
        let index = pixelIndex(x: x, y: y)
        pixels[index] = rgba.red
        pixels[index + 1] = rgba.green
        pixels[index + 2] = rgba.blue
        pixels[index + 3] = rgba.alpha
    }

    /// Renders the buffer back to a `CGImage`.
    public func makeCGImage() -> CGImage? {
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: NSData(bytes: pixels, length: pixels.count)) else {
            return nil
        }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
