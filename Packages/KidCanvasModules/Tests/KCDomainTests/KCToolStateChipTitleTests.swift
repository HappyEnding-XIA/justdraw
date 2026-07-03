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
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .eraser, brush: .pencil), "chip.title.eraser")
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .fill, brush: .pencil), "chip.title.fill")
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .picker, brush: .pencil), "chip.title.picker")
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .sticker, brush: .pencil), "chip.title.sticker")
    }

    func testBrushStyleDeterminesTitle() {
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .brush, brush: .pencil), "chip.title.pencil")
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .brush, brush: .pen), "chip.title.pen")
        XCTAssertEqual(KCToolStateChipTitle.title(tool: .brush, brush: .crayon), "chip.title.crayon")
    }
}
