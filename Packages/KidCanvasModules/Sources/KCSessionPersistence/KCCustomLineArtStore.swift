//
//  KCCustomLineArtStore.swift
//  KCSessionPersistence
//
//  Created by 小大 on 2026/07/09.
//

import Foundation
import KCDomain
import KCCommon

/// “我的线稿”基于文件的本地持久化，实现 `KCCustomLineArtRepository`（T099）。
///
/// 磁盘布局独立于历史会话：
/// - `<id>.png` 位图线稿
/// - `<id>-thumb.jpg` 缩略图（与历史缩略图同源压缩策略，由 App 层生成）
/// - `custom-line-arts.json` 元数据（Codable，schema 版本化）
///
/// 自动命名：`sequenceNumber` 取现有最大编号 + 1（无则 1），保证删除后不重号、稳定可读。
/// 数量上限 `maxItemCount`（MVP 50）；达到上限时 `save` 返回 `nil`，由 App 层提示清理。
/// 保存中途失败会回滚图像文件，避免元数据指向缺失线稿。删除只删线稿库条目，不影响历史作品。
public final class KCCustomLineArtStore: KCCustomLineArtRepository, @unchecked Sendable {
    public static let defaultDirectoryName = "KidCanvasCustomLineArt"
    public static let metadataFileName = "custom-line-arts.json"

    /// 我的线稿数量上限（MVP）。
    public static let maxItemCount = 50

    private let directoryURL: URL
    private let metadataURL: URL
    private let now: () -> Date
    private let makeID: () -> String
    private let fileManager: FileManager
    private let replaceFileItem: @Sendable (FileManager, URL, URL) throws -> Void
    private let lock = NSLock()

    /// 创建以 `Documents/KidCanvasCustomLineArt/` 为根目录的 store。
    public convenience init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.init(
            directoryURL: documents.appendingPathComponent(Self.defaultDirectoryName, isDirectory: true)
        )
    }

    /// 创建以指定目录为根的 store（用于测试）。
    public init(
        directoryURL: URL,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> String = { UUID().uuidString },
        fileManager: FileManager = .default,
        replaceFileItem: (@Sendable (FileManager, URL, URL) throws -> Void)? = nil
    ) {
        self.directoryURL = directoryURL
        self.metadataURL = directoryURL.appendingPathComponent(Self.metadataFileName)
        self.now = now
        self.makeID = makeID
        self.fileManager = fileManager
        self.replaceFileItem = replaceFileItem ?? { fileManager, originalURL, backupURL in
            _ = try fileManager.replaceItemAt(
                originalURL,
                withItemAt: backupURL,
                backupItemName: nil,
                options: []
            )
        }
    }

    // MARK: - KCCustomLineArtRepository

    public func loadAll() throws -> [KCCustomLineArt] {
        lock.lock(); defer { lock.unlock() }
        try ensureDirectoryExists()
        let items = (readMetadataDocument()?.items) ?? []
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    public func save(
        lineArtPNG: Data,
        thumbnailJPEG: Data,
        sourceKind: KCCustomLineArtSourceKind,
        sourceSessionId: String?
    ) throws -> KCCustomLineArt? {
        guard !lineArtPNG.isEmpty, !thumbnailJPEG.isEmpty else { return nil }

        lock.lock(); defer { lock.unlock() }
        try ensureDirectoryExists()

        var items = (readMetadataDocument()?.items) ?? []
        // 数量上限：达到上限后拒绝新增（由 App 层提示清理）。
        guard items.count < Self.maxItemCount else { return nil }

        let id = makeID()
        let lineArtFileName = "\(id).png"
        let thumbnailFileName = "\(id)-thumb.jpg"
        let sequenceNumber = nextSequenceNumber(for: items)
        let item = KCCustomLineArt(
            id: id,
            sequenceNumber: sequenceNumber,
            lineArtFileName: lineArtFileName,
            thumbnailFileName: thumbnailFileName,
            createdAt: now(),
            sourceKind: sourceKind,
            sourceSessionId: sourceSessionId
        )

        let lineArtURL = directoryURL.appendingPathComponent(item.lineArtFileName)
        let thumbnailURL = directoryURL.appendingPathComponent(item.thumbnailFileName)
        let rollbackID = UUID().uuidString
        guard let lineArtBackup = try? rollbackBackup(for: lineArtURL, transactionID: rollbackID) else { return nil }
        guard let thumbnailBackup = try? rollbackBackup(for: thumbnailURL, transactionID: rollbackID) else {
            cleanupRollbackBackup(lineArtBackup)
            return nil
        }

        do {
            try lineArtPNG.write(to: lineArtURL, options: .atomic)
        } catch {
            cleanupRollbackBackup(lineArtBackup)
            cleanupRollbackBackup(thumbnailBackup)
            return nil
        }

        do {
            try thumbnailJPEG.write(to: thumbnailURL, options: .atomic)
        } catch {
            restore(lineArtBackup)
            cleanupRollbackBackup(thumbnailBackup)
            return nil
        }

        items.insert(item, at: 0)
        do {
            try writeMetadataDocument(KCCustomLineArtDocument(
                schemaVersion: Self.schemaVersion,
                items: items
            ))
        } catch {
            restore(lineArtBackup)
            restore(thumbnailBackup)
            return nil
        }

        cleanupRollbackBackup(lineArtBackup)
        cleanupRollbackBackup(thumbnailBackup)
        return item
    }

    public func lineArtData(for item: KCCustomLineArt) -> Data? {
        guard !item.lineArtFileName.isEmpty else { return nil }
        return try? Data(contentsOf: directoryURL.appendingPathComponent(item.lineArtFileName))
    }

    public func thumbnailData(for item: KCCustomLineArt) -> Data? {
        guard !item.thumbnailFileName.isEmpty else { return nil }
        return try? Data(contentsOf: directoryURL.appendingPathComponent(item.thumbnailFileName))
    }

    public func delete(_ item: KCCustomLineArt) throws {
        guard !item.id.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }

        guard var items = readMetadataDocument()?.items else { return }
        let indexes = items.enumerated().compactMap { $0.element.id == item.id ? $0.offset : nil }
        guard !indexes.isEmpty else { return }

        for index in indexes.sorted(by: >) {
            items.remove(at: index)
        }
        try writeMetadataDocument(KCCustomLineArtDocument(
            schemaVersion: Self.schemaVersion,
            items: items
        ))

        if !item.lineArtFileName.isEmpty {
            try? fileManager.removeItem(at: directoryURL.appendingPathComponent(item.lineArtFileName))
        }
        if !item.thumbnailFileName.isEmpty {
            try? fileManager.removeItem(at: directoryURL.appendingPathComponent(item.thumbnailFileName))
        }
    }

    public func count() throws -> Int {
        try loadAll().count
    }

    // MARK: - 内部实现

    public static let schemaVersion = 1

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func nextSequenceNumber(for items: [KCCustomLineArt]) -> Int {
        let maxNumber = items.map { $0.sequenceNumber }.max() ?? 0
        return maxNumber + 1
    }

    private func readMetadataDocument() -> KCCustomLineArtDocument? {
        guard fileManager.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL) else {
            return nil
        }
        return try? Self.makeDecoder().decode(KCCustomLineArtDocument.self, from: data)
    }

    private func writeMetadataDocument(_ document: KCCustomLineArtDocument) throws {
        let data = try Self.makeEncoder().encode(document)
        try data.write(to: metadataURL, options: .atomic)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func rollbackBackup(for url: URL, transactionID: String) throws -> KCFileRollbackBackup {
        guard fileManager.fileExists(atPath: url.path) else {
            return KCFileRollbackBackup(originalURL: url, backupURL: nil)
        }
        let backupFileName = ".\(url.lastPathComponent).\(transactionID).rollback"
        let backupURL = directoryURL.appendingPathComponent(backupFileName)
        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }
        try fileManager.copyItem(at: url, to: backupURL)
        return KCFileRollbackBackup(originalURL: url, backupURL: backupURL)
    }

    private func restore(_ backup: KCFileRollbackBackup) {
        if let backupURL = backup.backupURL {
            do {
                if fileManager.fileExists(atPath: backup.originalURL.path) {
                    try replaceFileItem(fileManager, backup.originalURL, backupURL)
                } else {
                    try fileManager.moveItem(at: backupURL, to: backup.originalURL)
                }
            } catch {
                // 恢复失败时保留 .rollback 文件，避免二次数据丢失。
            }
        } else {
            try? fileManager.removeItem(at: backup.originalURL)
        }
    }

    private func cleanupRollbackBackup(_ backup: KCFileRollbackBackup?) {
        if let backupURL = backup?.backupURL {
            try? fileManager.removeItem(at: backupURL)
        }
    }
}

private struct KCFileRollbackBackup {
    let originalURL: URL
    let backupURL: URL?
}

/// 我的线稿 JSON 元数据文件的 Codable 外层结构，携带 schema 版本号。
struct KCCustomLineArtDocument: Codable {
    var schemaVersion: Int
    var items: [KCCustomLineArt]
}
