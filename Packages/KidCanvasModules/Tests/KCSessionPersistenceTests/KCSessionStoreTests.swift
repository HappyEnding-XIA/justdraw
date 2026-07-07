//
//  KCSessionStoreTests.swift
//  KCSessionPersistenceTests
//
//  Created by 小大 on 2026/06/25.
//

import XCTest
@testable import KCSessionPersistence
import KCDomain

final class SessionStoreTests: XCTestCase {
    private func makeStore(
        directory: URL? = nil,
        legacyMigrator: KCLegacySessionMigrator? = nil,
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_700_000_000) },
        makeID: @escaping () -> String = { "fixed-id" },
        fileManager: FileManager = .default,
        replaceFileItem: (@Sendable (FileManager, URL, URL) throws -> Void)? = nil
    ) -> (KCSessionStore, URL) {
        let dir = directory ?? URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = KCSessionStore(
            directoryURL: dir,
            legacyMigrator: legacyMigrator,
            now: now,
            makeID: makeID,
            fileManager: fileManager,
            replaceFileItem: replaceFileItem
        )
        return (store, dir)
    }

    func testEmptyStoreHasNoSessions() throws {
        let (store, _) = makeStore()
        XCTAssertFalse(try store.hasSavedSessions())
        XCTAssertTrue(try store.loadSessions().isEmpty)
    }

    func testSaveCreatesFilesAndMetadata() throws {
        let (store, dir) = makeStore()
        let png = Data(repeating: 0x01, count: 8)
        let jpg = Data(repeating: 0x02, count: 8)

        let session = try store.saveArtwork(pngData: png, thumbnailJPEGData: jpg, existing: nil)
        XCTAssertEqual(session?.id, "fixed-id")
        XCTAssertEqual(session?.artworkFileName, "fixed-id.png")
        XCTAssertEqual(session?.thumbnailFileName, "fixed-id-thumb.jpg")
        XCTAssertTrue(session?.title.hasPrefix("Artwork ") == true)

        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("fixed-id.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("fixed-id-thumb.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("sessions.json").path))

        let loaded = try store.loadSessions()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, "fixed-id")
    }

    func testSaveWithExistingUpdatesInPlace() throws {
        let counter = IDCounter()
        let (store, _) = makeStore(makeID: { counter.next() })
        let png = Data(repeating: 0x01, count: 4)
        let jpg = Data(repeating: 0x02, count: 4)

        let first = try store.saveArtwork(pngData: png, thumbnailJPEGData: jpg, existing: nil)
        let second = try store.saveArtwork(pngData: png, thumbnailJPEGData: jpg, existing: first)

        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(try store.loadSessions().count, 1)
    }

    func testSuccessfulUpdateCleansRollbackBackupFiles() throws {
        let (store, dir) = makeStore()
        let first = try store.saveArtwork(
            pngData: Data(repeating: 0x01, count: 4),
            thumbnailJPEGData: Data(repeating: 0x02, count: 4),
            existing: nil
        )

        let second = try store.saveArtwork(
            pngData: Data(repeating: 0x03, count: 4),
            thumbnailJPEGData: Data(repeating: 0x04, count: 4),
            existing: first
        )

        XCTAssertNotNil(second)
        XCTAssertTrue(rollbackFiles(in: dir).isEmpty)
    }

    func testUpdateRestoresArtworkFilesWhenMetadataWriteFails() throws {
        let (store, dir) = makeStore()
        let oldPNG = Data(repeating: 0xA1, count: 16)
        let oldJPG = Data(repeating: 0xB2, count: 16)
        let newPNG = Data(repeating: 0xC3, count: 16)
        let newJPG = Data(repeating: 0xD4, count: 16)
        let session = try store.saveArtwork(pngData: oldPNG, thumbnailJPEGData: oldJPG, existing: nil)!

        let metadataURL = dir.appendingPathComponent(KCSessionStore.metadataFileName)
        try FileManager.default.removeItem(at: metadataURL)
        try FileManager.default.createDirectory(at: metadataURL, withIntermediateDirectories: false)

        let failedUpdate = try store.saveArtwork(pngData: newPNG, thumbnailJPEGData: newJPG, existing: session)

        XCTAssertNil(failedUpdate)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(session.artworkFileName)), oldPNG)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(session.thumbnailFileName)), oldJPG)
        XCTAssertTrue(rollbackFiles(in: dir).isEmpty)
    }

    func testBackupSetupFailureCleansAlreadyCreatedRollbackFile() throws {
        let fileManager = FailingSecondCopyFileManager()
        let (store, dir) = makeStore(fileManager: fileManager)
        let session = try store.saveArtwork(
            pngData: Data(repeating: 0x01, count: 4),
            thumbnailJPEGData: Data(repeating: 0x02, count: 4),
            existing: nil
        )

        let failedUpdate = try store.saveArtwork(
            pngData: Data(repeating: 0x03, count: 4),
            thumbnailJPEGData: Data(repeating: 0x04, count: 4),
            existing: session
        )

        XCTAssertNil(failedUpdate)
        XCTAssertEqual(fileManager.copyAttempts, 2)
        XCTAssertTrue(rollbackFiles(in: dir).isEmpty)
    }

    func testFailedRestoreKeepsCurrentFileAndRollbackBackup() throws {
        let (store, dir) = makeStore(replaceFileItem: { _, _, _ in
            throw CocoaError(.fileWriteUnknown)
        })
        let oldPNG = Data(repeating: 0xA1, count: 16)
        let oldJPG = Data(repeating: 0xB2, count: 16)
        let newPNG = Data(repeating: 0xC3, count: 16)
        let newJPG = Data(repeating: 0xD4, count: 16)
        let session = try store.saveArtwork(pngData: oldPNG, thumbnailJPEGData: oldJPG, existing: nil)!

        let metadataURL = dir.appendingPathComponent(KCSessionStore.metadataFileName)
        try FileManager.default.removeItem(at: metadataURL)
        try FileManager.default.createDirectory(at: metadataURL, withIntermediateDirectories: false)

        let failedUpdate = try store.saveArtwork(pngData: newPNG, thumbnailJPEGData: newJPG, existing: session)

        XCTAssertNil(failedUpdate)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(session.artworkFileName)), newPNG)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(session.thumbnailFileName)), newJPG)
        XCTAssertEqual(rollbackFiles(in: dir).count, 2)
    }

    func testLoadSessionsSortsNewestFirst() throws {
        var tick = 1_000.0
        let (store, _) = makeStore(now: {
            let d = Date(timeIntervalSince1970: tick); tick += 100; return d
        }, makeID: { UUID().uuidString })
        let png = Data([1])
        let jpg = Data([2])
        let a = try store.saveArtwork(pngData: png, thumbnailJPEGData: jpg, existing: nil)
        let b = try store.saveArtwork(pngData: png, thumbnailJPEGData: jpg, existing: nil)

        let loaded = try store.loadSessions()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded, [b, a].compactMap { $0 })
    }

    func testDeleteRemovesSessionAndFiles() throws {
        let (store, dir) = makeStore()
        let png = Data([1])
        let jpg = Data([2])
        let session = try store.saveArtwork(pngData: png, thumbnailJPEGData: jpg, existing: nil)!

        try store.delete(session)
        XCTAssertTrue(try store.loadSessions().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("fixed-id.png").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("fixed-id-thumb.jpg").path))
    }

    func testDeleteKeepsArtworkFilesWhenMetadataCannotBeRead() throws {
        let (store, dir) = makeStore()
        let png = Data(repeating: 0x11, count: 8)
        let jpg = Data(repeating: 0x22, count: 8)
        let session = try store.saveArtwork(pngData: png, thumbnailJPEGData: jpg, existing: nil)!

        let metadataURL = dir.appendingPathComponent(KCSessionStore.metadataFileName)
        try FileManager.default.removeItem(at: metadataURL)
        try FileManager.default.createDirectory(at: metadataURL, withIntermediateDirectories: false)

        XCTAssertNoThrow(try store.delete(session))
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(session.artworkFileName)), png)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(session.thumbnailFileName)), jpg)
    }

    func testEmptyDataReturnsNilWithoutMutating() throws {
        let (store, dir) = makeStore()
        let result = try store.saveArtwork(pngData: Data(), thumbnailJPEGData: Data([1]), existing: nil)
        XCTAssertNil(result)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("sessions.json").path))
    }

    func testArtworkAndThumbnailDataReadBack() throws {
        let (store, _) = makeStore()
        let png = Data(repeating: 0xAB, count: 16)
        let jpg = Data(repeating: 0xCD, count: 16)
        let session = try store.saveArtwork(pngData: png, thumbnailJPEGData: jpg, existing: nil)!

        XCTAssertEqual(store.artworkData(for: session), png)
        XCTAssertEqual(store.thumbnailData(for: session), jpg)
    }

    func testDraftSaveLoadClear() throws {
        let (store, _) = makeStore()
        let png = Data(repeating: 0x77, count: 32)
        XCTAssertTrue(try store.saveDraft(pngData: png))
        XCTAssertEqual(store.loadDraft(), png)
        store.clearDraft()
        XCTAssertNil(store.loadDraft())
    }

    func testHasDraftTracksDraftFileLifecycleWithoutLoadingImageData() throws {
        let (store, _) = makeStore()
        let png = Data(repeating: 0x77, count: 32)

        XCTAssertFalse(store.hasDraft())
        XCTAssertTrue(try store.saveDraft(pngData: png))
        XCTAssertTrue(store.hasDraft())

        store.clearDraft()
        XCTAssertFalse(store.hasDraft())
    }

    func testMetadataFileRoundTripsAcrossInstances() throws {
        let (_, dir) = makeStore()
        // 第一个实例写入。
        let writer = KCSessionStore(directoryURL: dir, now: { Date(timeIntervalSince1970: 5) }, makeID: { "abc" })
        _ = try writer.saveArtwork(pngData: Data([1]), thumbnailJPEGData: Data([2]), existing: nil)
        // 新实例读取同一份磁盘元数据。
        let reader = KCSessionStore(directoryURL: dir)
        XCTAssertEqual(try reader.loadSessions().first?.id, "abc")
    }
}

// MARK: - 旧版迁移

final class LegacyMigrationTests: XCTestCase {
    func testLegacyArchiveIsMigratedToJSONWhenMigratorSupplied() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // 在旧版归档应处的位置放一个哨兵文件。
        let archiveURL = dir.appendingPathComponent("sessions.archive")
        try Data(repeating: 0xFF, count: 4).write(to: archiveURL)

        let spy = MigratorSpy()
        spy.result = [
            KCArtworkSession(id: "legacy-1", title: "Old", artworkFileName: "legacy-1.png",
                           thumbnailFileName: "legacy-1-thumb.jpg", modifiedAt: Date(timeIntervalSince1970: 100))
        ]
        let store = KCSessionStore(directoryURL: dir, legacyMigrator: spy)

        let loaded = try store.loadSessions()
        XCTAssertTrue(spy.wasAsked)
        XCTAssertEqual(loaded.first?.id, "legacy-1")

        // 此时 JSON 元数据已持久化，因此不应再需要迁移器。
        spy.wasAsked = false
        spy.result = nil
        let reloaded = try store.loadSessions()
        XCTAssertFalse(spy.wasAsked)
        XCTAssertEqual(reloaded.first?.id, "legacy-1")
    }

    func testLegacyArchiveWithoutMigratorYieldsEmpty() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let archiveURL = dir.appendingPathComponent("sessions.archive")
        try Data([1]).write(to: archiveURL)

        let store = KCSessionStore(directoryURL: dir, legacyMigrator: nil)
        XCTAssertTrue(try store.loadSessions().isEmpty)
    }
}

private final class IDCounter {
    private var value = 0
    func next() -> String { value += 1; return "id-\(value)" }
}

private func rollbackFiles(in directory: URL) -> [URL] {
    let files = (try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    )) ?? []
    return files.filter { $0.lastPathComponent.hasSuffix(".rollback") }
}

private final class FailingSecondCopyFileManager: FileManager, @unchecked Sendable {
    private(set) var copyAttempts = 0

    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        copyAttempts += 1
        if copyAttempts == 2 {
            throw CocoaError(.fileWriteUnknown)
        }
        try super.copyItem(at: srcURL, to: dstURL)
    }
}

private final class MigratorSpy: KCLegacySessionMigrator, @unchecked Sendable {
    var wasAsked = false
    var result: [KCArtworkSession]?
    func decode(legacyArchiveAt url: URL) -> [KCArtworkSession]? {
        wasAsked = true
        return result
    }
}
