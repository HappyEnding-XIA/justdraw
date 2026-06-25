//
//  KCRepositories.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCCommon

/// Read/write contract for persisted artwork sessions.
///
/// Image payloads are exchanged as `Data` (PNG for artwork, JPEG for thumbnails)
/// so the protocol stays `UIKit`-free. Implementations live in
/// `KCSessionPersistence` and keep the same on-disk layout as the Objective-C
/// `KDSessionStore` (`Documents/KidCanvasSessions/`, `<uuid>.png`,
/// `<uuid>-thumb.jpg`, `draft.png`).
public protocol KCSessionRepository: Sendable {
    /// Loads all sessions, newest first.
    func loadSessions() throws -> [KCArtworkSession]

    /// Persists an artwork plus its thumbnail, creating or updating a session.
    /// Returns the stored session, or `nil` if the image was invalid.
    func saveArtwork(
        pngData: Data,
        thumbnailJPEGData: Data,
        existing: KCArtworkSession?
    ) throws -> KCArtworkSession?

    /// Loads the full-resolution artwork image data for a session.
    func artworkData(for session: KCArtworkSession) -> Data?

    /// Loads the thumbnail image data for a session.
    func thumbnailData(for session: KCArtworkSession) -> Data?

    /// Removes a session and its associated files.
    func delete(_ session: KCArtworkSession) throws

    /// `true` when at least one session is persisted.
    func hasSavedSessions() throws -> Bool

    /// Overwrites the autosave draft with the given PNG data.
    func saveDraft(pngData: Data) throws -> Bool

    /// Loads the autosave draft PNG data, if present.
    func loadDraft() -> Data?

    /// Removes the autosave draft.
    func clearDraft()
}

/// A photo selected from the system picker.
public struct KCImportedPhoto: Sendable {
    public let imageData: Data
    public init(imageData: Data) { self.imageData = imageData }
}

/// Import/export contract for the system photo library.
///
/// Defined in the domain layer (UIKit-free) so features can depend on the
/// abstraction; the concrete adapter lives in the app/photo module.
public protocol KCPhotoLibraryServicing: Sendable {
    /// Exports image data (PNG/JPEG) to the saved-photos album.
    @discardableResult
    func export(imageData: Data) async -> Bool

    /// Presents the photo picker and yields the selected photo, if any.
    func importPhoto() async -> KCImportedPhoto?
}
