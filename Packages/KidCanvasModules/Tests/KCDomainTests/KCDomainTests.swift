import XCTest
@testable import KCDomain
import KCCommon

final class KCDomainTests: XCTestCase {
    func testArtworkSessionUsesProvidedIdentifier() {
        let session = ArtworkSession(
            id: "session-1",
            title: "Test",
            artworkFileName: "a.png",
            thumbnailFileName: "a-thumb.jpg"
        )
        XCTAssertEqual(session.id, "session-1")
        XCTAssertEqual(session.title, "Test")
    }

    func testToolModeContainsExpectedCases() {
        XCTAssertEqual(ToolMode.allCases, [.brush, .eraser, .fill, .sticker, .picker])
    }
}

// MARK: - Stroke

final class StrokeTests: XCTestCase {
    func testAveragePressureFallsBackToOneWhenNoSamples() {
        let stroke = Stroke(toolMode: .brush, brushStyle: .pencil, eraserShape: .circle,
                             color: .black, lineWidth: 10)
        XCTAssertEqual(stroke.averagePressure, 1.0)
    }

    func testRecordPressureAveragesAccumulatedSamples() {
        var stroke = Stroke(toolMode: .brush, brushStyle: .pen, eraserShape: .circle,
                             color: .black, lineWidth: 10)
        stroke.recordPressure(0.8)
        stroke.recordPressure(1.2)
        XCTAssertEqual(stroke.pressureSampleCount, 2)
        XCTAssertEqual(stroke.averagePressure, 1.0, accuracy: 1e-9)
    }

    func testStrokeCodableRoundTrip() throws {
        let stroke = Stroke(toolMode: .eraser, brushStyle: .crayon, eraserShape: .star,
                             color: HexColor(hex: "#3366CC")!, lineWidth: 16,
                             points: [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)],
                             startPoint: CGPoint(x: 1, y: 2), dotStroke: true,
                             pressureTotal: 2.4, pressureSampleCount: 3)
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(Stroke.self, from: data)
        XCTAssertEqual(stroke, decoded)
    }
}

// MARK: - StickerItem / StickerTransform

final class StickerTransformTests: XCTestCase {
    func testIdentityScaleIsOne() {
        XCTAssertEqual(StickerTransform.identity.scale, 1.0)
    }

    func testScaleMatchesPrototypeFormula() {
        // Prototype reads scale as hypot(transform.a, transform.c).
        let transform = StickerTransform(a: 3, b: 0, c: 4, d: 1, tx: 0, ty: 0)
        XCTAssertEqual(transform.scale, 5.0, accuracy: 1e-9)
    }

    func testScaledByDoublesScale() {
        let transform = StickerTransform.identity.scaled(by: 1.5)
        XCTAssertEqual(transform.scale, 1.5, accuracy: 1e-9)
    }

    func testRoundTripsThroughCGAffineTransform() {
        let cg = CGAffineTransform(a: 1.1, b: 0.2, c: 0.3, d: 0.9, tx: 5, ty: -3)
        let wrapper = StickerTransform(cgAffineTransform: cg)
        XCTAssertEqual(wrapper.cgAffineTransform, cg)
    }

    func testStickerItemCodableRoundTrip() throws {
        let sticker = StickerItem(
            symbolName: "heart.fill",
            color: HexColor(hex: "#FF0000")!,
            center: CGPoint(x: 120, y: 80),
            transform: StickerTransform(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0)
        )
        let data = try JSONEncoder().encode(sticker)
        let decoded = try JSONDecoder().decode(StickerItem.self, from: data)
        XCTAssertEqual(sticker.symbolName, decoded.symbolName)
        XCTAssertEqual(sticker.transform.scale, decoded.transform.scale, accuracy: 1e-9)
        XCTAssertEqual(sticker.center, decoded.center)
    }
}

// MARK: - CanvasSnapshot

final class CanvasSnapshotTests: XCTestCase {
    func testEmptySnapshotHasNoVisibleContent() {
        XCTAssertFalse(CanvasSnapshot().hasVisibleContent)
    }

    func testSnapshotWithStrokesHasVisibleContent() {
        let snapshot = CanvasSnapshot(strokes: [
            Stroke(toolMode: .brush, brushStyle: .pen, eraserShape: .circle,
                   color: .black, lineWidth: 5)
        ])
        XCTAssertTrue(snapshot.hasVisibleContent)
    }

    func testSnapshotWithBackgroundHasVisibleContent() {
        let snapshot = CanvasSnapshot(backgroundImageData: Data([0x89, 0x50]))
        XCTAssertTrue(snapshot.hasVisibleContent)
    }
}

// MARK: - EditorState

final class EditorStateTests: XCTestCase {
    func testDefaultsMatchPrototype() {
        let state = EditorState()
        XCTAssertEqual(state.toolMode, .brush)
        XCTAssertEqual(state.brushStyle, .pencil)
        XCTAssertEqual(state.eraserShape, .circle)
        XCTAssertEqual(state.lineWidth, 12.0)
        XCTAssertEqual(state.stickerSymbol, "star.fill")
        XCTAssertEqual(state.fillTolerance, 28.0)
        XCTAssertEqual(state.paletteSize.colorCount, 24)
        // rgb(0.94, 0.43, 0.45) -> #F06E73
        XCTAssertEqual(state.color.hex, "#F06E73")
    }

    func testUseColorDeduplicatesAndCapsHistory() {
        var state = EditorState()
        let red = HexColor(hex: "#FF0000")!
        let blue = HexColor(hex: "#0000FF")!
        state.useColor(red)
        state.useColor(blue)
        state.useColor(red) // reusing red should move it to front, not duplicate
        XCTAssertEqual(state.recentColors.first, red)
        XCTAssertEqual(state.recentColors.count, 2)
    }

    func testRecentColorsCappedAtLimit() {
        var state = EditorState()
        for i in 0..<15 {
            state.useColor(HexColor(red: Double(i) / 255, green: 0, blue: 0))
        }
        XCTAssertLessThanOrEqual(state.recentColors.count, EditorState.recentColorLimit)
    }

    func testSelectBrushRestoresRememberedWidth() {
        var state = EditorState()
        state.lineWidth = 30
        state.rememberBrushWidth(30)
        state.selectBrush(.pen, fallbackWidth: 12)
        state.lineWidth = 8
        state.rememberBrushWidth(8)
        // Switching back to the original brush restores 30.
        state.selectBrush(.pencil, fallbackWidth: 12)
        XCTAssertEqual(state.lineWidth, 30)
    }
}
