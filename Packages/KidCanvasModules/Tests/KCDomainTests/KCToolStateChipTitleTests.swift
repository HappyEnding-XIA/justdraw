//
//  KCToolStateChipTitleTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/06/26.
//

import XCTest
@testable import KCDomain

final class KCToolStateChipTitleTests: XCTestCase {
    func testNonBrushToolsMapToTheirTitles() {
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .eraser, brush: .pencil), "Eraser")
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .fill, brush: .pencil), "Fill")
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .picker, brush: .pencil), "Eyedropper")
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .sticker, brush: .pencil), "Sticker")
    }

    func testBrushStyleDeterminesTitle() {
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .brush, brush: .pencil), "Pencil")
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .brush, brush: .pen), "Pen")
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .brush, brush: .crayon), "Crayon")
    }
}
