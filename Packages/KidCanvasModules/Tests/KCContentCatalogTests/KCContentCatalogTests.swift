//
//  KCContentCatalogTests.swift
//  KCContentCatalogTests
//
//  Created by 小大 on 2026/06/25.
//

import XCTest
@testable import KCContentCatalog
import KCDomain
import KCCommon

final class ContentCatalogTests: XCTestCase {
    func testPalette24HasExpectedCount() {
        XCTAssertEqual(KCContentCatalogDefaults.palette24.count, 24)
    }

    func testPalette36IsPalette24PlusTwelve() {
        XCTAssertEqual(KCContentCatalogDefaults.palette36.count, 36)
        // 前 24 个必须与 palette24 完全一致。
        XCTAssertEqual(
            Array(KCContentCatalogDefaults.palette36.prefix(24)),
            KCContentCatalogDefaults.palette24
        )
    }

    func testFirstPaletteColorMatchesPrototypeDefault() {
        // rgb(0.94, 0.43, 0.45) -> #F06E73，也是编辑器的默认颜色。
        XCTAssertEqual(KCContentCatalogDefaults.palette24.first?.hex, "#F06E73")
    }

    func testNoDuplicateColorsWithinPalette24() {
        let hexes = KCContentCatalogDefaults.palette24.map(\.hex)
        XCTAssertEqual(Set(hexes).count, hexes.count, "palette24 contains duplicate colors")
    }

    func testNoDuplicateColorsWithinPalette36() {
        let hexes = KCContentCatalogDefaults.palette36.map(\.hex)
        XCTAssertEqual(Set(hexes).count, hexes.count, "palette36 contains duplicate colors")
    }

    func testStickerGroupsHaveExpectedTitlesAndCounts() {
        let groups = KCContentCatalogDefaults.stickerGroups
        XCTAssertEqual(groups.map(\.title), ["Animals", "Nature", "Decor", "Faces"])
        XCTAssertEqual(groups[0].symbols.count, 4) // Animals（动物）
        XCTAssertEqual(groups[2].symbols.count, 5) // Decor（装饰，含 rainbow 共 5 个）
    }

    func testStickerGroupsHaveUniqueIds() {
        let ids = KCContentCatalogDefaults.stickerGroups.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testDefaultStickerSymbolIsPresent() {
        // 编辑器默认贴纸 "star.fill" 必须存在于目录中。
        let allSymbols = KCContentCatalogDefaults.stickerGroups.flatMap(\.symbols)
        XCTAssertTrue(allSymbols.contains("star.fill"))
    }

    func testLineArtTemplatesCountAndOrder() {
        let titles = KCContentCatalogDefaults.lineArtTemplates.map(\.title)
        XCTAssertEqual(titles, ["Bunny", "Car", "Fish", "Flower", "House", "Rocket", "Cupcake", "Dino"])
    }

    func testLineArtTemplatesHaveUniqueIds() {
        let ids = KCContentCatalogDefaults.lineArtTemplates.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testCatalogPaletteSelectionBySize() {
        let catalog = KCBundledContentCatalog()
        XCTAssertEqual(catalog.palette(for: .standard).colors.count, 24)
        XCTAssertEqual(catalog.palette(for: .extended).colors.count, 36)
        XCTAssertEqual(catalog.palette(for: .standard).id, "palette.24")
    }

    func testCatalogIsSendableAndCodableShapesRoundTrip() throws {
        // 通过打包的目录类型验证 Codable 的编解码形状。
        let palette = KCContentPalette(id: "p", title: "P", colors: KCContentCatalogDefaults.palette24)
        let data = try JSONEncoder().encode(palette)
        let decoded = try JSONDecoder().decode(KCContentPalette.self, from: data)
        XCTAssertEqual(decoded.colors.count, 24)
        XCTAssertEqual(decoded.colors.first?.hex, palette.colors.first?.hex)
    }

    // MARK: - T020 JSON resource 加载

    func testDecodedContentReturnsNilForMalformedJSON() {
        // JSON 解析失败时返回 nil，loaded 会改用硬编码 fallback。
        XCTAssertNil(KCContentCatalogDefaults.decodedContent(from: Data("not json".utf8)))
    }

    func testDecodedContentReturnsNilForEmptyOrMissingData() {
        XCTAssertNil(KCContentCatalogDefaults.decodedContent(from: nil))
        // 缺少必填字段的空对象也应回退。
        XCTAssertNil(KCContentCatalogDefaults.decodedContent(from: Data("{}".utf8)))
    }

    func testDecodedContentParsesValidDocument() throws {
        // 合法 JSON（贴纸/线稿均非空）应成功解码。
        let json = Data(#"""
            {"stickerGroups":[{"id":"a","title":"A","symbols":["x"]}],
             "lineArtTemplates":[{"id":"b","title":"B","category":"C"}]}
            """#.utf8)
        let doc = try XCTUnwrap(KCContentCatalogDefaults.decodedContent(from: json))
        XCTAssertEqual(doc.stickerGroups.first?.id, "a")
        XCTAssertEqual(doc.lineArtTemplates.first?.id, "b")
    }

    func testBundledStickersAndLineArtMatchExpectedIds() {
        // 端到端：公开 API 返回的贴纸/线稿 id 顺序与预期一致（验证 JSON 实际被加载，内容未漂移）。
        XCTAssertEqual(KCContentCatalogDefaults.stickerGroups.map(\.id), ["animals", "nature", "decor", "faces"])
        XCTAssertEqual(
            KCContentCatalogDefaults.lineArtTemplates.map(\.id),
            ["bunny", "car", "fish", "flower", "house", "rocket", "cupcake", "dino"]
        )
    }
}
