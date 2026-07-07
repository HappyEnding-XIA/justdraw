//
//  KCStickerSymbolDisplayMetricsTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/07/07.
//

import XCTest
@testable import KCDomain

final class KCStickerSymbolDisplayMetricsTests: XCTestCase {

    func testDefaultSymbolUsesStandardStampContainer() {
        let metrics = KCStickerSymbolDisplayMetrics.metrics(forSymbol: "star.fill")

        XCTAssertEqual(metrics.canvasSide, 72.0, accuracy: 1e-9)
        XCTAssertEqual(metrics.symbolPointSize, 54.0, accuracy: 1e-9)
        XCTAssertEqual(metrics.outlinePointSize, 60.0, accuracy: 1e-9)
        XCTAssertEqual(metrics.contentInset, 6.0, accuracy: 1e-9)
    }

    func testLargeAnimalSymbolsUseMoreInnerPadding() {
        let rabbit = KCStickerSymbolDisplayMetrics.metrics(forSymbol: "hare.fill")
        let turtle = KCStickerSymbolDisplayMetrics.metrics(forSymbol: "tortoise.fill")
        let standard = KCStickerSymbolDisplayMetrics.metrics(forSymbol: "star.fill")

        XCTAssertLessThan(rabbit.symbolPointSize, standard.symbolPointSize)
        XCTAssertLessThan(turtle.symbolPointSize, standard.symbolPointSize)
        XCTAssertGreaterThan(rabbit.contentInset, standard.contentInset)
        XCTAssertGreaterThan(turtle.contentInset, standard.contentInset)
    }

    func testUnknownSymbolFallsBackToStandardMetrics() {
        let metrics = KCStickerSymbolDisplayMetrics.metrics(forSymbol: "unknown.symbol")

        XCTAssertEqual(metrics, KCStickerSymbolDisplayMetrics.metrics(forSymbol: "star.fill"))
    }
}
