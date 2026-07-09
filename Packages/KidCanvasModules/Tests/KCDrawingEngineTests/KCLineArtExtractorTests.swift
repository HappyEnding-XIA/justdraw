//
//  KCLineArtExtractorTests.swift
//  KCDrawingEngineTests
//
//  Created by 小大 on 2026/07/09.
//

import XCTest
import CoreGraphics
import ImageIO
@testable import KCDrawingEngine
import KCDomain

final class KCLineArtExtractorTests: XCTestCase {

    private let extractor = KCLineArtExtractor()

    func testReturnsNilForInvalidImageData() {
        XCTAssertNil(extractor.extract(from: Data(repeating: 0, count: 16)))
    }

    func testExtractsUsableLineArtFromCartoonLikeImage() {
        // 白底 + 黑色实心圆（典型卡通/白底图）。
        let png = Self.pngData(whiteBackgroundWithBlackShape: true)
        let result = extractor.extract(from: png)
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.lineArtPNG.isEmpty ?? true)
        XCTAssertFalse(result?.thumbnailJPEG.isEmpty ?? true)
        // 白底黑线图应能生成可用线稿（good 或 marginal），不应判 poor。
        XCTAssertTrue(result?.quality.isUsable ?? false, "卡通/白底图应生成可用线稿，实际: \(String(describing: result?.quality))")
    }

    func testPureWhiteImageIsNotUsable() {
        // 纯白图（无边缘）应判 poor（不适合生成线稿）。
        let png = Self.pngData(whiteBackgroundWithBlackShape: false)
        let result = extractor.extract(from: png)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.quality, .poor, "无边缘的纯白图应判 poor")
    }

    // MARK: - 合成图

    /// 生成 400×400 PNG：`shape` 为 true 时白底画多个黑色形状（模拟卡通/白底线稿），否则纯白。
    private static func pngData(whiteBackgroundWithBlackShape shape: Bool) -> Data {
        let size = 400
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return Data()
        }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        if shape {
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            // 多个分散的黑色形状，模拟卡通/白底图的丰富线条边缘。
            context.fillEllipse(in: CGRect(x: 60, y: 250, width: 110, height: 110))
            context.fillEllipse(in: CGRect(x: 240, y: 250, width: 110, height: 110))
            context.fill(CGRect(x: 150, y: 110, width: 100, height: 80))
            context.fill(CGRect(x: 60, y: 60, width: 90, height: 30))
            context.fill(CGRect(x: 250, y: 60, width: 90, height: 30))
        }
        guard let cgImage = context.makeImage() else { return Data() }
        let mutable = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutable, "public.png" as CFString, 1, nil) else {
            return Data()
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        _ = CGImageDestinationFinalize(destination)
        return mutable as Data
    }
}
