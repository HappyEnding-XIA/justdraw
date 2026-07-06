//
//  KCLineArtDrawingTests.swift
//  KCDrawingEngineTests
//
//  Created by 小大 on 2026/07/06.
//

import XCTest
import CoreGraphics
@testable import KCDrawingEngine

final class KCLineArtDrawingTests: XCTestCase {
    func testSupportedTemplateIdsMatchBundledCatalogOrder() {
        XCTAssertEqual(
            KCLineArtDrawing.supportedTemplateIds,
            ["bunny", "car", "fish", "flower", "house", "rocket", "cupcake", "dino"]
        )
    }

    func testKnownTemplatesProduceExpectedStrokeCounts() throws {
        let rect = CGRect(x: 0, y: 0, width: 520, height: 420)
        let expectedCounts = [
            "bunny": 10,
            "car": 7,
            "fish": 5,
            "flower": 9,
            "house": 5,
            "rocket": 5,
            "cupcake": 5,
            "dino": 6,
        ]

        for templateId in KCLineArtDrawing.supportedTemplateIds {
            let strokes = try XCTUnwrap(KCLineArtDrawing.strokes(forTemplateId: templateId, in: rect))
            XCTAssertEqual(strokes.count, expectedCounts[templateId], templateId)
            XCTAssertTrue(strokes.allSatisfy { $0.lineWidth > 0 }, templateId)
        }
    }

    func testGeneratedPathsAreNonEmptyAndStayNearDrawingRect() throws {
        let rect = CGRect(x: 10, y: 20, width: 520, height: 420)
        let allowedBounds = rect.insetBy(dx: -280, dy: -240)

        for templateId in KCLineArtDrawing.supportedTemplateIds {
            let strokes = try XCTUnwrap(KCLineArtDrawing.strokes(forTemplateId: templateId, in: rect))
            for stroke in strokes {
                XCTAssertFalse(stroke.path.boundingBoxOfPath.isEmpty, templateId)
                XCTAssertTrue(
                    allowedBounds.intersects(stroke.path.boundingBoxOfPath),
                    "\(templateId) path should stay near the drawing rect"
                )
            }
        }
    }

    func testUnknownTemplateReturnsNil() {
        XCTAssertNil(KCLineArtDrawing.strokes(forTemplateId: "unknown", in: .zero))
    }
}
