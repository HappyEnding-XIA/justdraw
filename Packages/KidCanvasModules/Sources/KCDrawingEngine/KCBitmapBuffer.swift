//
//  KCBitmapBuffer.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import CoreGraphics

/// 可变的 KCRGBA8 位图，是 `CGImage` 光栅数据与纯逻辑引擎（泛洪填充、采样）之间的桥梁。
///
/// 存储为 RGBA 顺序的 `[UInt8]`，每像素 4 字节，共 `width * height` 个像素，按行优先排列。
/// 与 `CGImage` 互操作时使用与 Objective-C 原型相同的位图信息
/// （`premultipliedLast | byteOrder32Big`），以保证像素值往返完全一致。
public final class KCBitmapBuffer {
    public let width: Int
    public let height: Int
    public private(set) var pixels: [UInt8]

    /// 创建一个用单一颜色填充的缓冲区。
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

    /// 通过光栅化 `CGImage` 创建缓冲区。对于空图像或无法解码的图像返回 `nil`。
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

    /// 读取 `(x, y)` 处的像素。假设坐标在边界内。
    public func pixel(x: Int, y: Int) -> KCRGBA8 {
        let index = pixelIndex(x: x, y: y)
        return KCRGBA8(
            red: pixels[index],
            green: pixels[index + 1],
            blue: pixels[index + 2],
            alpha: pixels[index + 3]
        )
    }

    /// 将 `rgba` 写入 `(x, y)`。假设坐标在边界内。
    public func setPixel(_ rgba: KCRGBA8, x: Int, y: Int) {
        let index = pixelIndex(x: x, y: y)
        pixels[index] = rgba.red
        pixels[index + 1] = rgba.green
        pixels[index + 2] = rgba.blue
        pixels[index + 3] = rgba.alpha
    }

    /// 将缓冲区渲染回 `CGImage`。
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
