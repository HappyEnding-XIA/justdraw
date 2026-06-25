import Foundation
import UIKit
import KCCommon
import KCDomain
import KCSessionPersistence

/// ObjC bridge over the Swift `SessionStore`, covering all operations
/// that the OC `KDSessionStore` provides. OC code can use this bridge
/// as a drop-in replacement; session metadata is returned as NSDictionary
/// arrays (avoiding direct dependence on the Swift `ArtworkSession` type).
@objc(SessionStoreBridge)
final class SessionStoreBridge: NSObject {
    @objc static let shared = SessionStoreBridge()

    private let store = SessionStore()
    private static let thumbnailSize = CGSize(width: 240, height: 180)

    // MARK: - Session queries

    @objc func hasSavedSessions() -> Bool {
        (try? store.hasSavedSessions()) ?? false
    }

    @objc func sessionCount() -> Int {
        (try? store.loadSessions().count) ?? 0
    }

    /// Returns all sessions as an array of dictionaries (newest first).
    /// Each dictionary contains: `id`, `title`, `artworkFileName`,
    /// `thumbnailFileName`, `modifiedAt` (NSDate).
    @objc func loadSessionDictionaries() -> [[String: Any]] {
        guard let sessions = try? store.loadSessions() else { return [] }
        return sessions.map { sessionToDictionary($0) }
    }

    // MARK: - Artwork save (UIImage convenience)

    /// Saves artwork from a UIImage. Generates PNG data + 240×180 JPEG
    /// thumbnail internally. If `existingSessionId` is non-nil, updates that
    /// session; otherwise creates a new one.
    /// Returns the session dictionary, or nil on failure.
    @objc func saveImage(_ image: UIImage, existingSessionId: String?) -> [String: Any]? {
        guard let pngData = image.pngData() else { return nil }
        let thumbnail = Self.generateThumbnail(from: image)
        guard let thumbData = thumbnail.jpegData(compressionQuality: 0.85) else { return nil }
        return saveArtwork(pngData: pngData, thumbnailJPEGData: thumbData, existingSessionId: existingSessionId)
    }

    // MARK: - Artwork save / load (Data)

    /// Saves artwork PNG + JPEG thumbnail. If `existingSessionId` is non-nil,
    /// updates that session; otherwise creates a new one.
    /// Returns the session dictionary, or nil on failure.
    @objc func saveArtwork(
        pngData: Data,
        thumbnailJPEGData: Data,
        existingSessionId: String?
    ) -> [String: Any]? {
        let existing: ArtworkSession? = existingSessionId.flatMap { id in
            (try? store.loadSessions())?.first { $0.id == id }
        }
        guard let session = try? store.saveArtwork(
            pngData: pngData,
            thumbnailJPEGData: thumbnailJPEGData,
            existing: existing
        ) else { return nil }
        return sessionToDictionary(session)
    }

    /// Returns the full-resolution artwork as a UIImage.
    @objc func artworkImage(forSessionId sessionId: String) -> UIImage? {
        guard let data = artworkData(forSessionId: sessionId) else { return nil }
        return UIImage(data: data)
    }

    /// Returns the full-resolution artwork PNG data for the given session id.
    @objc func artworkData(forSessionId sessionId: String) -> Data? {
        guard let session = findSession(id: sessionId) else { return nil }
        return store.artworkData(for: session)
    }

    /// Returns the thumbnail as a UIImage.
    @objc func thumbnailImage(forSessionId sessionId: String) -> UIImage? {
        guard let data = thumbnailData(forSessionId: sessionId) else { return nil }
        return UIImage(data: data)
    }

    /// Returns the thumbnail JPEG data for the given session id.
    @objc func thumbnailData(forSessionId sessionId: String) -> Data? {
        guard let session = findSession(id: sessionId) else { return nil }
        return store.thumbnailData(for: session)
    }

    // MARK: - Session delete

    /// Deletes the session and its associated files.
    @objc func deleteSession(withId sessionId: String) {
        guard let session = findSession(id: sessionId) else { return }
        try? store.delete(session)
    }

    // MARK: - Draft autosave

    /// Saves draft from a UIImage (convenience).
    @objc func saveDraftImage(_ image: UIImage) -> Bool {
        guard let data = image.pngData() else { return false }
        return saveDraftData(pngData: data)
    }

    /// Loads the draft as a UIImage.
    @objc func loadDraftImage() -> UIImage? {
        guard let data = store.loadDraft() else { return nil }
        return UIImage(data: data)
    }

    @objc func saveDraftData(pngData: Data) -> Bool {
        (try? store.saveDraft(pngData: pngData)) ?? false
    }

    @objc func loadDraftData() -> Data? {
        store.loadDraft()
    }

    @objc func clearDraft() {
        store.clearDraft()
    }

    // MARK: - Private helpers

    private func findSession(id: String) -> ArtworkSession? {
        try? store.loadSessions().first { $0.id == id }
    }

    private func sessionToDictionary(_ session: ArtworkSession) -> [String: Any] {
        [
            "id": session.id,
            "title": session.title,
            "artworkFileName": session.artworkFileName,
            "thumbnailFileName": session.thumbnailFileName,
            "modifiedAt": session.modifiedAt,
        ]
    }

    /// Generates a 240×180 thumbnail with white background and aspect-fit,
    /// matching the prototype's `thumbnailImageFromImage:`.
    private static func generateThumbnail(from image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: thumbnailSize))
            let imageSize = image.size
            let scale = min(thumbnailSize.width / imageSize.width,
                            thumbnailSize.height / imageSize.height)
            let drawSize = CGSize(width: imageSize.width * scale,
                                  height: imageSize.height * scale)
            let drawRect = CGRect(
                x: (thumbnailSize.width - drawSize.width) / 2.0,
                y: (thumbnailSize.height - drawSize.height) / 2.0,
                width: drawSize.width,
                height: drawSize.height
            )
            image.draw(in: drawRect)
        }
    }
}
