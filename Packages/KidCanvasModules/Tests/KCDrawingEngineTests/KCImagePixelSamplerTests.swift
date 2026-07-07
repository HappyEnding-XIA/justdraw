//
//  KCImagePixelSamplerTests.swift
//  KCDrawingEngineTests
//
//  Created by 小大 on 2026/07/07.
//

import XCTest
@testable import KCDrawingEngine
import KCCommon

final class KCImagePixelSamplerTests: XCTestCase {
    func testSampleCGImageReturnsRequestedPixelOnly() throws {
        let buffer = KCBitmapBuffer(width: 3, height: 2, fill: .white)
        buffer.setPixel(KCRGBA8(red: 12, green: 34, blue: 56, alpha: 255), x: 2, y: 1)
        let image = try XCTUnwrap(buffer.makeCGImage())

        let pixel = KCImagePixelSampler.sample(cgImage: image, x: 2, y: 1)

        XCTAssertEqual(pixel, KCRGBA8(red: 12, green: 34, blue: 56, alpha: 255))
    }

    func testSampleCGImageReturnsNilWhenPointIsOutOfBounds() throws {
        let buffer = KCBitmapBuffer(width: 2, height: 2, fill: .white)
        let image = try XCTUnwrap(buffer.makeCGImage())

        XCTAssertNil(KCImagePixelSampler.sample(cgImage: image, x: -1, y: 0))
        XCTAssertNil(KCImagePixelSampler.sample(cgImage: image, x: 2, y: 0))
        XCTAssertNil(KCImagePixelSampler.sample(cgImage: image, x: 0, y: 2))
    }
}
