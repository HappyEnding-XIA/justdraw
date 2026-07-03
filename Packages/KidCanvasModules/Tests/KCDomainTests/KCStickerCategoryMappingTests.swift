//
//  KCStickerCategoryMappingTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/07/02.
//

import XCTest
@testable import KCDomain

final class KCStickerCategoryMappingTests: XCTestCase {

    let categories = ["Animals", "Nature", "Decor", "Faces"]

    func testCategorySymbolForKnownCategories() {
        XCTAssertEqual(KCStickerCategoryMapping.categorySymbol(forCategory: "Animals"), "pawprint.fill")
        XCTAssertEqual(KCStickerCategoryMapping.categorySymbol(forCategory: "Nature"), "leaf.fill")
        XCTAssertEqual(KCStickerCategoryMapping.categorySymbol(forCategory: "Decor"), "sparkles")
        XCTAssertEqual(KCStickerCategoryMapping.categorySymbol(forCategory: "Faces"), "face.smiling.fill")
    }

    func testCategorySymbolFallsBackToStar() {
        XCTAssertEqual(KCStickerCategoryMapping.categorySymbol(forCategory: "Unknown"), "star.fill")
    }

    func testAccessibilityLabelForKnownSymbols() {
        XCTAssertEqual(KCStickerCategoryMapping.accessibilityLabel(forSymbol: "star.fill"), "sticker.symbol.star")
        XCTAssertEqual(KCStickerCategoryMapping.accessibilityLabel(forSymbol: "rainbow"), "sticker.symbol.rainbow")
        XCTAssertEqual(KCStickerCategoryMapping.accessibilityLabel(forSymbol: "camera.macro"), "sticker.symbol.flower")
    }

    func testAccessibilityLabelFallsBackToSticker() {
        XCTAssertEqual(KCStickerCategoryMapping.accessibilityLabel(forSymbol: "something.unknown"), "sticker.symbol.default")
    }

    func testCategoryForIdentifierResolvesSlug() {
        XCTAssertEqual(
            KCStickerCategoryMapping.category(forIdentifier: "sticker.category.animals", inCategories: categories),
            "Animals"
        )
        XCTAssertEqual(
            KCStickerCategoryMapping.category(forIdentifier: "sticker.category.nature", inCategories: categories),
            "Nature"
        )
    }

    func testCategoryForIdentifierReturnsNilForMissingPrefix() {
        XCTAssertNil(KCStickerCategoryMapping.category(forIdentifier: "palette.color.1", inCategories: categories))
    }

    func testCategoryForIdentifierReturnsNilForUnknownSlug() {
        XCTAssertNil(KCStickerCategoryMapping.category(forIdentifier: "sticker.category.unknown", inCategories: categories))
    }
}
