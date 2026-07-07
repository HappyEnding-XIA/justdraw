//
//  KCImagePixelSampler.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/07/07.
//

import CoreGraphics
import Foundation
import KCCommon

/// 面向 `CGImage` 的单像素采样器，用于取色器这类只需要一个像素的高频路径。
public enum KCImagePixelSampler {
    /// 从 `cgImage` 的像素坐标 `(x, y)` 读取颜色；越界或图像无法裁剪时返回 `nil`。
    public static func sample(cgImage: CGImage, x: Int, y: Int) -> KCRGBA8? {
        guard x >= 0, x < cgImage.width, y >= 0, y < cgImage.height else { return nil }
        guard let cropped = cgImage.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else {
            return nil
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let didDraw = pixel.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                return false
            }
            context.interpolationQuality = .none
            context.clear(CGRect(x: 0, y: 0, width: 1, height: 1))
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard didDraw else { return nil }

        return KCRGBA8(red: pixel[0], green: pixel[1], blue: pixel[2], alpha: pixel[3])
    }
}
