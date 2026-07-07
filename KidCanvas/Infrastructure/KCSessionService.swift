//
//  KCSessionService.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import UIKit
import KCCommon
import KCDomain
import KCSessionPersistence

/// 类型安全的会话元数据 DTO，可供跨语言边界使用。
///
/// 取代了过去在 Swift↔ObjC 边界传递的松散 `[String: Any]` / NSDictionary：
/// 调用方读取类型化属性（`session.identifier`、`session.title`、…），
/// 而非字符串 key 的字典访问（`session[@"id"]`）。
///
/// 这是 `KCArtworkSession` 的只读视图模型，不改变磁盘 JSON schema
///（`KCSessionStore` 仍持久化底层的 `KCArtworkSession`）。
@objc(KCSessionMetadata)
final class KCSessionMetadata: NSObject {
    @objc let identifier: String
    @objc let title: String
    @objc let artworkFileName: String
    @objc let thumbnailFileName: String
    @objc let modifiedAt: Date

    init(identifier: String, title: String, artworkFileName: String, thumbnailFileName: String, modifiedAt: Date) {
        self.identifier = identifier
        self.title = title
        self.artworkFileName = artworkFileName
        self.thumbnailFileName = thumbnailFileName
        self.modifiedAt = modifiedAt
    }

    init(_ session: KCArtworkSession) {
        self.identifier = session.id
        self.title = session.title
        self.artworkFileName = session.artworkFileName
        self.thumbnailFileName = session.thumbnailFileName
        self.modifiedAt = session.modifiedAt
    }
}

/// 基于 Swift `KCSessionStore` 的适配层，覆盖原 OC `KDSessionStore` 的全部
/// 操作。会话元数据以类型化的 `KCSessionMetadata` DTO 返回（不再是
/// NSDictionary）。
///
/// **错误处理**：存储错误通过 `try?` 静默降级（返回 nil/空/false）而不上抛，
/// 与原型 `KDSessionStore` 吞掉错误的行为一致。后续可替换为正式的
/// `throws` 抛出（§6.5 允许桥接/适配层用 `try?` 降级）。
@objc(KCSessionService)
final class KCSessionService: NSObject {
    private let store = KCSessionStore(legacyMigrator: LegacyArchiveMigrator())
    private let thumbnailImageCache = NSCache<NSString, UIImage>()
    private static let thumbnailSize = CGSize(width: 240, height: 180)

    // MARK: - 会话查询

    @objc func hasSavedSessions() -> Bool {
        (try? store.hasSavedSessions()) ?? false
    }

    @objc func sessionCount() -> Int {
        (try? store.loadSessions().count) ?? 0
    }

    /// 返回所有会话（类型化的 `KCSessionMetadata` DTO，按最新优先排序）。
    @objc func loadAllSessions() -> [KCSessionMetadata] {
        guard let sessions = try? store.loadSessions() else { return [] }
        return sessions.map { KCSessionMetadata($0) }
    }

    // MARK: - 保存画作（UIImage 便捷方法）

    /// 保存来自 UIImage 的画作，内部生成 PNG 数据 + 240×180 JPEG 缩略图。
    /// 若 `existingSessionId` 非空则更新该会话，否则新建会话。
    /// 返回会话元数据 DTO，失败返回 nil。
    @objc func saveImage(_ image: UIImage, existingSessionId: String?) -> KCSessionMetadata? {
        guard let pngData = image.pngData() else { return nil }
        let thumbnail = Self.generateThumbnail(from: image)
        guard let thumbData = thumbnail.jpegData(compressionQuality: 0.85) else { return nil }
        return saveArtwork(pngData: pngData, thumbnailJPEGData: thumbData, existingSessionId: existingSessionId)
    }

    // MARK: - 保存/读取画作（Data）

    /// 保存画作 PNG + JPEG 缩略图。若 `existingSessionId` 非空则更新该会话，
    /// 否则新建会话。返回会话元数据 DTO，失败返回 nil。
    @objc func saveArtwork(
        pngData: Data,
        thumbnailJPEGData: Data,
        existingSessionId: String?
    ) -> KCSessionMetadata? {
        let existing: KCArtworkSession? = existingSessionId.flatMap { id in
            (try? store.loadSessions())?.first { $0.id == id }
        }
        guard let session = try? store.saveArtwork(
            pngData: pngData,
            thumbnailJPEGData: thumbnailJPEGData,
            existing: existing
        ) else { return nil }
        if let cachedThumbnail = UIImage(data: thumbnailJPEGData) {
            thumbnailImageCache.setObject(cachedThumbnail, forKey: session.id as NSString)
        } else {
            thumbnailImageCache.removeObject(forKey: session.id as NSString)
        }
        return KCSessionMetadata(session)
    }

    /// 返回全分辨率画作 UIImage。
    @objc func artworkImage(forSessionId sessionId: String) -> UIImage? {
        guard let data = artworkData(forSessionId: sessionId) else { return nil }
        return UIImage(data: data)
    }

    /// 返回指定会话的全分辨率画作 PNG 数据。
    @objc func artworkData(forSessionId sessionId: String) -> Data? {
        guard let session = findSession(id: sessionId) else { return nil }
        return store.artworkData(for: session)
    }

    /// 返回缩略图 UIImage。
    @objc func thumbnailImage(forSessionId sessionId: String) -> UIImage? {
        if let cachedThumbnail = thumbnailImageCache.object(forKey: sessionId as NSString) {
            return cachedThumbnail
        }
        guard let data = thumbnailData(forSessionId: sessionId) else { return nil }
        guard let image = UIImage(data: data) else { return nil }
        thumbnailImageCache.setObject(image, forKey: sessionId as NSString)
        return image
    }

    /// 返回指定会话的缩略图 JPEG 数据。
    @objc func thumbnailData(forSessionId sessionId: String) -> Data? {
        guard let session = findSession(id: sessionId) else { return nil }
        return store.thumbnailData(for: session)
    }

    // MARK: - 删除会话

    /// 删除会话及其关联文件。
    @objc func deleteSession(withId sessionId: String) {
        guard let session = findSession(id: sessionId) else { return }
        try? store.delete(session)
        thumbnailImageCache.removeObject(forKey: sessionId as NSString)
    }

    // MARK: - 草稿自动保存

    /// 保存来自 UIImage 的草稿（便捷方法）。
    @objc func saveDraftImage(_ image: UIImage) -> Bool {
        guard let data = image.pngData() else { return false }
        return saveDraftData(pngData: data)
    }

    /// 以 UIImage 形式加载草稿。
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

    // MARK: - 私有辅助方法

    private func findSession(id: String) -> KCArtworkSession? {
        try? store.loadSessions().first { $0.id == id }
    }

    /// 生成 240×180 缩略图，白底、aspect-fit，与原型 `thumbnailImageFromImage:`
    /// 行为一致。
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
