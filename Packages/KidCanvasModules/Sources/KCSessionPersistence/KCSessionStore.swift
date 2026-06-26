//
//  KCSessionStore.swift
//  KCSessionPersistence
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCDomain
import KCCommon

/// 将 Objective-C 的 `sessions.archive`（NSKeyedArchiver）解码为领域 session。
/// 该归档存储的是自定义的 `KDArtworkSession` 对象，因此解码需要原始类——
/// 该类位于 app target 中，而不在本 package 内。
///
/// app 在启动时提供具体的迁移器；本 package 定义接口边界，
/// 并保持磁盘布局兼容。
public protocol KCLegacySessionMigrator: Sendable {
    /// 返回从旧版 `sessions.archive` 读取到的 session；若该迁移器无法解码此归档，则返回 `nil`。
    func decode(legacyArchiveAt url: URL) -> [KCArtworkSession]?
}

/// 基于文件的 session 持久化，实现 `KCSessionRepository`。
///
/// 磁盘布局与 Objective-C 的 `KDSessionStore` 一致：
/// - `<uuid>.png` 完整画作
/// - `<uuid>-thumb.jpg` 240×180 JPEG 缩略图
/// - `draft.png` 自动保存草稿
/// - `sessions.json` 元数据（Codable；取代旧版 `sessions.archive`）
///
/// 保存过程中途失败时会将图像文件回滚到之前的状态，
/// 因此元数据索引不会指向缺失的画作。
public final class KCSessionStore: KCSessionRepository, @unchecked Sendable {
    public static let defaultDirectoryName = "KidCanvasSessions"
    public static let metadataFileName = "sessions.json"
    public static let legacyMetadataFileName = "sessions.archive"
    public static let draftFileName = "draft.png"

    private let directoryURL: URL
    private let metadataURL: URL
    private let legacyMetadataURL: URL
    private let draftURL: URL
    private let legacyMigrator: KCLegacySessionMigrator?
    private let now: () -> Date
    private let makeID: () -> String
    private let fileManager: FileManager
    private let lock = NSLock()

    /// 创建以 `Documents/KidCanvasSessions/` 为根目录的 store。
    public convenience init(legacyMigrator: KCLegacySessionMigrator? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.init(
            directoryURL: documents.appendingPathComponent(Self.defaultDirectoryName, isDirectory: true),
            legacyMigrator: legacyMigrator
        )
    }

    /// 创建以指定目录为根的 store（用于测试）。
    public init(
        directoryURL: URL,
        legacyMigrator: KCLegacySessionMigrator? = nil,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> String = { UUID().uuidString },
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL
        self.metadataURL = directoryURL.appendingPathComponent(Self.metadataFileName)
        self.legacyMetadataURL = directoryURL.appendingPathComponent(Self.legacyMetadataFileName)
        self.draftURL = directoryURL.appendingPathComponent(Self.draftFileName)
        self.legacyMigrator = legacyMigrator
        self.now = now
        self.makeID = makeID
        self.fileManager = fileManager
    }

    // MARK: - KCSessionRepository

    public func loadSessions() throws -> [KCArtworkSession] {
        lock.lock(); defer { lock.unlock() }
        try ensureDirectoryExists()

        if let document = readMetadataDocument() {
            return document.sessions.sorted { $0.modifiedAt > $1.modifiedAt }
        }

        // 尚无 JSON —— 尝试从旧版归档进行一次性迁移。
        if let migrator = legacyMigrator,
           fileManager.fileExists(atPath: legacyMetadataURL.path),
           let migrated = migrator.decode(legacyArchiveAt: legacyMetadataURL) {
            let document = KCSessionMetadataDocument(schemaVersion: Self.schemaVersion, sessions: migrated)
            try? writeMetadataDocument(document)
            return migrated.sorted { $0.modifiedAt > $1.modifiedAt }
        }

        return []
    }

    public func saveArtwork(
        pngData: Data,
        thumbnailJPEGData: Data,
        existing: KCArtworkSession?
    ) throws -> KCArtworkSession? {
        guard !pngData.isEmpty, !thumbnailJPEGData.isEmpty else { return nil }

        lock.lock(); defer { lock.unlock() }
        try ensureDirectoryExists()

        var sessions = (readMetadataDocument()?.sessions) ?? []

        // 先解析身份，确保 `KCArtworkSession.id`（`let`）绝不会被修改。
        let id: String
        let artworkFileName: String
        let thumbnailFileName: String
        let inheritedTitle: String
        if let existing, !existing.id.isEmpty {
            id = existing.id
            artworkFileName = existing.artworkFileName
            thumbnailFileName = existing.thumbnailFileName
            inheritedTitle = existing.title
        } else {
            id = makeID()
            artworkFileName = "\(id).png"
            thumbnailFileName = "\(id)-thumb.jpg"
            inheritedTitle = ""
        }

        let modifiedAt = now()
        let title = inheritedTitle.isEmpty
            ? "Artwork \(Self.titleFormatter.string(from: modifiedAt))"
            : inheritedTitle
        let session = KCArtworkSession(
            id: id,
            title: title,
            artworkFileName: artworkFileName,
            thumbnailFileName: thumbnailFileName,
            modifiedAt: modifiedAt
        )

        let artworkURL = directoryURL.appendingPathComponent(session.artworkFileName)
        let thumbnailURL = directoryURL.appendingPathComponent(session.thumbnailFileName)
        let hadArtwork = fileManager.fileExists(atPath: artworkURL.path)
        let hadThumbnail = fileManager.fileExists(atPath: thumbnailURL.path)
        let previousArtwork = hadArtwork ? try? Data(contentsOf: artworkURL) : nil
        let previousThumbnail = hadThumbnail ? try? Data(contentsOf: thumbnailURL) : nil

        do {
            try pngData.write(to: artworkURL, options: .atomic)
        } catch {
            return nil
        }

        do {
            try thumbnailJPEGData.write(to: thumbnailURL, options: .atomic)
        } catch {
            restore(url: artworkURL, previousData: previousArtwork, existed: hadArtwork)
            return nil
        }

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }

        do {
            try writeMetadataDocument(KCSessionMetadataDocument(
                schemaVersion: Self.schemaVersion,
                sessions: sessions
            ))
        } catch {
            restore(url: artworkURL, previousData: previousArtwork, existed: hadArtwork)
            restore(url: thumbnailURL, previousData: previousThumbnail, existed: hadThumbnail)
            return nil
        }

        return session
    }

    public func artworkData(for session: KCArtworkSession) -> Data? {
        guard !session.artworkFileName.isEmpty else { return nil }
        return try? Data(contentsOf: directoryURL.appendingPathComponent(session.artworkFileName))
    }

    public func thumbnailData(for session: KCArtworkSession) -> Data? {
        guard !session.thumbnailFileName.isEmpty else { return nil }
        return try? Data(contentsOf: directoryURL.appendingPathComponent(session.thumbnailFileName))
    }

    public func delete(_ session: KCArtworkSession) throws {
        guard !session.id.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }

        guard var sessions = readMetadataDocument()?.sessions else { return }
        let indexes = sessions.enumerated().compactMap { $0.element.id == session.id ? $0.offset : nil }
        guard !indexes.isEmpty else { return }

        if !session.artworkFileName.isEmpty {
            try? fileManager.removeItem(at: directoryURL.appendingPathComponent(session.artworkFileName))
        }
        if !session.thumbnailFileName.isEmpty {
            try? fileManager.removeItem(at: directoryURL.appendingPathComponent(session.thumbnailFileName))
        }
        for index in indexes.sorted(by: >) {
            sessions.remove(at: index)
        }
        try writeMetadataDocument(KCSessionMetadataDocument(
            schemaVersion: Self.schemaVersion,
            sessions: sessions
        ))
    }

    public func hasSavedSessions() throws -> Bool {
        try !loadSessions().isEmpty
    }

    public func saveDraft(pngData: Data) throws -> Bool {
        guard !pngData.isEmpty else { return false }
        lock.lock(); defer { lock.unlock() }
        try ensureDirectoryExists()
        do {
            try pngData.write(to: draftURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public func loadDraft() -> Data? {
        try? Data(contentsOf: draftURL)
    }

    public func clearDraft() {
        try? fileManager.removeItem(at: draftURL)
    }

    // MARK: - 内部实现

    public static let schemaVersion = 1
    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter
    }()

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func readMetadataDocument() -> KCSessionMetadataDocument? {
        guard fileManager.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL) else {
            return nil
        }
        return try? Self.makeDecoder().decode(KCSessionMetadataDocument.self, from: data)
    }

    private func writeMetadataDocument(_ document: KCSessionMetadataDocument) throws {
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

    /// 将文件恢复到之前的内容；若之前不存在则移除该文件——
    /// 对应原型的 `restoreFileAtURL:previousData:existed:`。
    private func restore(url: URL, previousData: Data?, existed: Bool) {
        if existed, let previousData {
            try? previousData.write(to: url, options: .atomic)
        } else {
            try? fileManager.removeItem(at: url)
        }
    }
}

/// JSON 元数据文件的 Codable 外层结构，携带 schema 版本号。
struct KCSessionMetadataDocument: Codable {
    var schemaVersion: Int
    var sessions: [KCArtworkSession]
}
