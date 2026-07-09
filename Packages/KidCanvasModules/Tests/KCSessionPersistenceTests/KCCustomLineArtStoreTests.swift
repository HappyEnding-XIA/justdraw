//
//  KCCustomLineArtStoreTests.swift
//  KCSessionPersistenceTests
//
//  Created by 小大 on 2026/07/09.
//

import XCTest
@testable import KCSessionPersistence
import KCDomain

final class CustomLineArtStoreTests: XCTestCase {
    private func makeStore(
        directory: URL? = nil,
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_700_000_000) },
        makeID: @escaping () -> String = { "fixed-id" }
    ) -> (KCCustomLineArtStore, URL) {
        let dir = directory ?? URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = KCCustomLineArtStore(
            directoryURL: dir,
            now: now,
            makeID: makeID
        )
        return (store, dir)
    }

    private let png = Data(repeating: 0x01, count: 8)
    private let thumb = Data(repeating: 0x02, count: 8)

    func testEmptyStoreHasNoItems() throws {
        let (store, _) = makeStore()
        XCTAssertTrue(try store.loadAll().isEmpty)
        XCTAssertEqual(try store.count(), 0)
    }

    func testSaveCreatesItemWithFilesAndMetadata() throws {
        let (store, dir) = makeStore()
        let item = try store.save(lineArtPNG: png, thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: "sess-1")
        XCTAssertEqual(item?.sequenceNumber, 1)
        XCTAssertEqual(item?.sourceKind, .canvasSave)
        XCTAssertEqual(item?.sourceSessionId, "sess-1")

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, "fixed-id")

        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("fixed-id.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("fixed-id-thumb.jpg").path))
        XCTAssertEqual(try store.lineArtData(for: items[0]), png)
        XCTAssertEqual(try store.thumbnailData(for: items[0]), thumb)
    }

    func testSequenceNumberIsMonotonicAndStableAfterDelete() throws {
        // 用递增 id 与递增时间，保证编号 1/2/3。
        var counter = 0
        let (store, _) = makeStore(
            now: { Date(timeIntervalSince1970: 1_700_000_000 + Double(counter)) },
            makeID: { counter += 1; return "id-\(counter)" }
        )
        _ = try store.save(lineArtPNG: png, thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: nil)
        _ = try store.save(lineArtPNG: png, thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: nil)
        _ = try store.save(lineArtPNG: png, thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: nil)
        var items = try store.loadAll()
        XCTAssertEqual(items.map { $0.sequenceNumber }.sorted(), [1, 2, 3])

        // 删除中间一条后，新增编号仍取历史最大值 + 1（不重号）。
        try store.delete(items.first { $0.sequenceNumber == 2 }!)
        _ = try store.save(lineArtPNG: png, thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: nil)
        items = try store.loadAll()
        XCTAssertEqual(Set(items.map { $0.sequenceNumber }), [1, 3, 4])
    }

    func testDeleteRemovesItemAndFilesWithoutAffectingOthers() throws {
        var counter = 0
        let (store, dir) = makeStore(
            now: { Date(timeIntervalSince1970: 1_700_000_000 + Double(counter)) },
            makeID: { counter += 1; return "id-\(counter)" }
        )
        _ = try store.save(lineArtPNG: png, thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: nil)
        _ = try store.save(lineArtPNG: png, thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: nil)

        let toDelete = try store.loadAll().first { $0.id == "id-1" }!
        try store.delete(toDelete)

        let remaining = try store.loadAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, "id-2")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("id-1.png").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("id-1-thumb.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("id-2.png").path))
    }

    func testSaveRejectsEmptyData() throws {
        let (store, _) = makeStore()
        XCTAssertNil(try store.save(lineArtPNG: Data(), thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: nil))
        XCTAssertNil(try store.save(lineArtPNG: png, thumbnailJPEG: Data(), sourceKind: .canvasSave, sourceSessionId: nil))
        XCTAssertEqual(try store.count(), 0)
    }

    func testSaveEnforcesSoftCap() throws {
        let cap = KCCustomLineArtStore.maxItemCount
        var counter = 0
        let (store, _) = makeStore(
            now: { Date(timeIntervalSince1970: 1_700_000_000 + Double(counter)) },
            makeID: { counter += 1; return "id-\(counter)" }
        )
        for _ in 0..<cap {
            XCTAssertNotNil(try store.save(lineArtPNG: png, thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: nil))
        }
        XCTAssertEqual(try store.count(), cap)
        // 达到上限后再保存返回 nil。
        XCTAssertNil(try store.save(lineArtPNG: png, thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: nil))
        XCTAssertEqual(try store.count(), cap)
    }

    func testLoadAllSortsNewestFirst() throws {
        var seq = 0
        let (store, _) = makeStore(
            now: { seq += 1; return Date(timeIntervalSince1970: 1_700_000_000 + Double(seq)) },
            makeID: { seq += 1; return "id-\(seq)" }
        )
        // now 与 makeID 各自递增 seq，保证创建时间单调递增、id 唯一。
        _ = try store.save(lineArtPNG: png, thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: nil)
        _ = try store.save(lineArtPNG: png, thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: nil)
        _ = try store.save(lineArtPNG: png, thumbnailJPEG: thumb, sourceKind: .canvasSave, sourceSessionId: nil)
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 3)
        // 最新创建的排最前（createdAt 倒序）。
        XCTAssertTrue(items[0].createdAt >= items[1].createdAt)
        XCTAssertTrue(items[1].createdAt >= items[2].createdAt)
    }
}
