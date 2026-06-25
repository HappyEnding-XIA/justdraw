//
//  KCSessionStore.swift
//  KCSessionPersistence
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCDomain
import KCCommon

/// Decodes the Objective-C `sessions.archive` (NSKeyedArchiver) into domain
/// sessions. The archive stores custom `KDArtworkSession` objects, so decoding
/// requires the original class — which lives in the app target, not this package.
///
/// The app supplies a concrete migrator at startup; this package defines the seam
/// and keeps the on-disk layout compatible.
public protocol KCLegacySessionMigrator: Sendable {
    /// Returns sessions read from the legacy `sessions.archive`, or `nil` if the
    /// archive cannot be decoded by this migrator.
    func decode(legacyArchiveAt url: URL) -> [KCArtworkSession]?
}

/// File-backed session persistence implementing `KCSessionRepository`.
///
/// On-disk layout matches the Objective-C `KDSessionStore`:
/// - `<uuid>.png` full artwork
/// - `<uuid>-thumb.jpg` 240×180 JPEG thumbnail
/// - `draft.png` autosave draft
/// - `sessions.json` metadata (Codable; supersedes the legacy `sessions.archive`)
///
/// A save that fails partway rolls back image files to their previous state, so
/// the metadata index never references missing artwork.
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

    /// Creates a store rooted at `Documents/KidCanvasSessions/`.
    public convenience init(legacyMigrator: KCLegacySessionMigrator? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.init(
            directoryURL: documents.appendingPathComponent(Self.defaultDirectoryName, isDirectory: true),
            legacyMigrator: legacyMigrator
        )
    }

    /// Creates a store rooted at an explicit directory (used for tests).
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

        // No JSON yet — attempt a one-time migration from the legacy archive.
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

        // Resolve identity first so `KCArtworkSession.id` (a `let`) is never mutated.
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

    // MARK: - Internals

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

    /// Restores a file to its previous contents, or removes it if it did not
    /// exist before — the prototype's `restoreFileAtURL:previousData:existed:`.
    private func restore(url: URL, previousData: Data?, existed: Bool) {
        if existed, let previousData {
            try? previousData.write(to: url, options: .atomic)
        } else {
            try? fileManager.removeItem(at: url)
        }
    }
}

/// Codable envelope for the JSON metadata file, carrying a schema version.
struct KCSessionMetadataDocument: Codable {
    var schemaVersion: Int
    var sessions: [KCArtworkSession]
}
