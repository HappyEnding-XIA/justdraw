//
//  KCLineArtExtractor.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/07/09.
//

import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import KCDomain

/// 离线图片生成线稿 pipeline（T101）。UIKit-free，基于 Core Image：
/// 灰度化 → 降噪 → 边缘检测 → 反相（边缘变深）→ 高对比近似阈值化 → 白底位图输出。
///
/// 能力边界：卡通图、绘本页、白底图、简单实物优先；复杂真实照片边缘过密/过少会被
/// 质量评估判为 `poor`（这张图片可能不适合），由 App 层提示并允许重试/取消。
/// 不做矢量化，不上传图片。滤镜选用长期稳定的内置滤镜，避免 iOS 16 不稳定滤镜。
public final class KCLineArtExtractor: KCLineArtExtracting, @unchecked Sendable {

    private static let maxDimension: CGFloat = 1600.0
    private static let thumbnailSize = CGSize(width: 240, height: 180)

    private let context: CIContext

    public init(context: CIContext = CIContext(options: [.useSoftwareRenderer: false])) {
        self.context = context
    }

    public func extract(from imageData: Data) -> KCLineArtExtractionResult? {
        guard let source = CIImage(data: imageData) else { return nil }
        let scaled = Self.scaledToFit(source, maxDimension: Self.maxDimension)
        // 灰度化：质量评估与边缘 pipeline 共用。
        guard let grayscale = CIFilter(name: "CIPhotoEffectMono", parameters: [kCIInputImageKey: scaled])?.outputImage else {
            return nil
        }
        let quality = Self.quality(forGrayscale: grayscale, context: context)
        guard let lineArtCG = renderLineArt(fromGrayscale: grayscale) else { return nil }
        guard let png = Self.encode(lineArtCG, type: "public.png") else { return nil }
        guard let thumb = Self.thumbnailJPEG(from: lineArtCG) else { return nil }
        return KCLineArtExtractionResult(lineArtPNG: png, thumbnailJPEG: thumb, quality: quality)
    }

    // MARK: - pipeline

    private func renderLineArt(fromGrayscale grayscale: CIImage) -> CGImage? {
        var current = grayscale
        // 降噪（轻度）
        if let f = CIFilter(name: "CINoiseReduction") {
            f.setValue(current, forKey: kCIInputImageKey)
            f.setValue(0.02, forKey: "inputNoiseLevel")
            f.setValue(0.4, forKey: kCIInputSharpnessKey)
            current = f.outputImage ?? current
        }
        // 边缘检测：边缘以亮色显示在暗底。
        if let f = CIFilter(name: "CIEdges") {
            f.setValue(current, forKey: kCIInputImageKey)
            f.setValue(5.0, forKey: "inputIntensity")
            current = f.outputImage ?? current
        }
        // 反相：边缘（亮）变深，非边缘（暗）变浅 → 深色线条在浅底。
        if let f = CIFilter(name: "CIColorInvert") { f.setValue(current, forKey: kCIInputImageKey); current = f.outputImage ?? current }
        // 高对比把灰度推向黑白（近似阈值化）。
        if let f = CIFilter(name: "CIColorControls") {
            f.setValue(current, forKey: kCIInputImageKey)
            f.setValue(0.02, forKey: kCIInputBrightnessKey)
            f.setValue(1.7, forKey: kCIInputContrastKey)
            f.setValue(1.0, forKey: kCIInputSaturationKey)
            current = f.outputImage ?? current
        }
        return context.createCGImage(current, from: current.extent)
    }

    // MARK: - 缩放

    private static func scaledToFit(_ image: CIImage, maxDimension: CGFloat) -> CIImage {
        let extent = image.extent
        let longest = max(extent.width, extent.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        return image.transformed(by: transform)
    }

    // MARK: - 编码

    private static func encode(_ cgImage: CGImage, type: String) -> Data? {
        let mutable = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutable, type as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutable as Data
    }

    private static func thumbnailJPEG(from cgImage: CGImage) -> Data? {
        guard let thumb = renderResized(cgImage, size: thumbnailSize, fillWhite: true) else { return nil }
        let mutable = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutable, "public.jpeg" as CFString, 1, nil) else { return nil }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.85]
        CGImageDestinationAddImage(destination, thumb, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutable as Data
    }

    /// 把 CGImage aspect-fit 绘制到给定尺寸的白底 bitmap。
    private static func renderResized(_ cgImage: CGImage, size: CGSize, fillWhite: Bool) -> CGImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        if fillWhite {
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(origin: .zero, size: size))
        }
        let imageW = CGFloat(cgImage.width)
        let imageH = CGFloat(cgImage.height)
        guard imageW > 0, imageH > 0 else { return nil }
        let scale = min(size.width / imageW, size.height / imageH)
        let drawW = imageW * scale
        let drawH = imageH * scale
        let drawRect = CGRect(
            x: (size.width - drawW) / 2.0,
            y: (size.height - drawH) / 2.0,
            width: drawW,
            height: drawH
        )
        context.interpolationQuality = .high
        context.draw(cgImage, in: drawRect)
        return context.makeImage()
    }

    // MARK: - 质量评估

    /// 基于输入灰度的亮度均值与标准差评估质量：
    /// 过暗/过亮（均值越界）或过均匀（标准差过低，无细节/模糊）判 poor；
    /// 细节偏少判 marginal；否则 good。比基于输出深色比例更稳健，不受边缘滤波阈值抖动影响。
    private static func quality(forGrayscale grayscale: CIImage, context: CIContext) -> KCLineArtQuality {
        let sampleSide = 80
        // 先把灰度图缩放到采样尺寸再渲染，避免对全分辨率图采样。
        let extent = grayscale.extent
        let transform: CGAffineTransform
        if extent.width > 0, extent.height > 0 {
            let s = CGFloat(sampleSide) / max(extent.width, extent.height)
            transform = CGAffineTransform(scaleX: s, y: s)
        } else {
            transform = .identity
        }
        let scaled = grayscale.transformed(by: transform)
        guard let sampleCG = context.createCGImage(scaled, from: scaled.extent),
              let data = sampleCG.dataProvider?.data,
              let pointer = CFDataGetBytePtr(data) else {
            return .good
        }
        let total = sampleSide * sampleSide
        var sum = 0.0
        var sumSq = 0.0
        for index in 0..<total {
            // 灰度图 RGB 通道近似相等，取 R 通道作亮度（归一到 0…1）。
            let value = Double(pointer[index * 4]) / 255.0
            sum += value
            sumSq += value * value
        }
        let mean = sum / Double(total)
        let variance = max(0.0, sumSq / Double(total) - mean * mean)
        let stddev = variance.squareRoot()
        if mean < 0.1 || mean > 0.95 {
            return .poor
        }
        if stddev < 0.05 {
            return .poor
        }
        if stddev < 0.1 {
            return .marginal
        }
        return .good
    }
}
