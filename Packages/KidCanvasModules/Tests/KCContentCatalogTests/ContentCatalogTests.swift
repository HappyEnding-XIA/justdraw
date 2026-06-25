import XCTest
@testable import KCContentCatalog
import KCDomain
import KCCommon

final class ContentCatalogTests: XCTestCase {
    func testPalette24HasExpectedCount() {
        XCTAssertEqual(ContentCatalogDefaults.palette24.count, 24)
    }

    func testPalette36IsPalette24PlusTwelve() {
        XCTAssertEqual(ContentCatalogDefaults.palette36.count, 36)
        // The first 24 must be identical to palette24.
        XCTAssertEqual(
            Array(ContentCatalogDefaults.palette36.prefix(24)),
            ContentCatalogDefaults.palette24
        )
    }

    func testFirstPaletteColorMatchesPrototypeDefault() {
        // rgb(0.94, 0.43, 0.45) -> #F06E73, also the editor default color.
        XCTAssertEqual(ContentCatalogDefaults.palette24.first?.hex, "#F06E73")
    }

    func testNoDuplicateColorsWithinPalette24() {
        let hexes = ContentCatalogDefaults.palette24.map(\.hex)
        XCTAssertEqual(Set(hexes).count, hexes.count, "palette24 contains duplicate colors")
    }

    func testNoDuplicateColorsWithinPalette36() {
        let hexes = ContentCatalogDefaults.palette36.map(\.hex)
        XCTAssertEqual(Set(hexes).count, hexes.count, "palette36 contains duplicate colors")
    }

    func testStickerGroupsHaveExpectedTitlesAndCounts() {
        let groups = ContentCatalogDefaults.stickerGroups
        XCTAssertEqual(groups.map(\.title), ["Animals", "Nature", "Decor", "Faces"])
        XCTAssertEqual(groups[0].symbols.count, 4) // Animals
        XCTAssertEqual(groups[2].symbols.count, 5) // Decor (has 5 incl. rainbow)
    }

    func testStickerGroupsHaveUniqueIds() {
        let ids = ContentCatalogDefaults.stickerGroups.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testDefaultStickerSymbolIsPresent() {
        // The editor default sticker "star.fill" must exist in the catalog.
        let allSymbols = ContentCatalogDefaults.stickerGroups.flatMap(\.symbols)
        XCTAssertTrue(allSymbols.contains("star.fill"))
    }

    func testLineArtTemplatesCountAndOrder() {
        let titles = ContentCatalogDefaults.lineArtTemplates.map(\.title)
        XCTAssertEqual(titles, ["Bunny", "Car", "Fish", "Flower", "House", "Rocket", "Cupcake", "Dino"])
    }

    func testLineArtTemplatesHaveUniqueIds() {
        let ids = ContentCatalogDefaults.lineArtTemplates.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testCatalogPaletteSelectionBySize() {
        let catalog = ContentCatalog()
        XCTAssertEqual(catalog.palette(for: .standard).colors.count, 24)
        XCTAssertEqual(catalog.palette(for: .extended).colors.count, 36)
        XCTAssertEqual(catalog.palette(for: .standard).id, "palette.24")
    }

    func testCatalogIsSendableAndCodableShapesRoundTrip() throws {
        // Exercises the Codable shapes via the bundled catalog types.
        let palette = ContentPalette(id: "p", title: "P", colors: ContentCatalogDefaults.palette24)
        let data = try JSONEncoder().encode(palette)
        let decoded = try JSONDecoder().decode(ContentPalette.self, from: data)
        XCTAssertEqual(decoded.colors.count, 24)
        XCTAssertEqual(decoded.colors.first?.hex, palette.colors.first?.hex)
    }
}
