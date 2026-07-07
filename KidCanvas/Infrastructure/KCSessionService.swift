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
    private let thumbnailImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        return cache
    }()
    private let sessionMetadataQueue = DispatchQueue(label: "com.kidcanvas.session.metadata", qos: .utility)
    private let thumbnailPreloadQueue = DispatchQueue(label: "com.kidcanvas.session.thumbnail-preload", qos: .utility)
    private let thumbnailPreloadLock = NSLock()
    private var thumbnailPreloadInFlight: Set<String> = []
    private let artworkSessionCacheLock = NSLock()
    private var artworkSessionCache: [KCArtworkSession]?
    private let draftCacheLock = NSLock()
    private var draftImageCache: UIImage?
    private var draftThumbnailCache: UIImage?
    private static let thumbnailSize = CGSize(width: 240, height: 180)

    // MARK: - 会话查询

    @objc func hasSavedSessions() -> Bool {
        !cachedArtworkSessions().isEmpty
    }

    @objc func sessionCount() -> Int {
        cachedArtworkSessions().count
    }

    /// 返回所有会话（类型化的 `KCSessionMetadata` DTO，按最新优先排序）。
    @objc func loadAllSessions() -> [KCSessionMetadata] {
        cachedArtworkSessions().map { KCSessionMetadata($0) }
    }

    /// 后台加载会话 metadata，避免启动后的首次历史栏刷新读取
    /// `sessions.json` 时阻塞主线程。
    func loadAllSessionsAsync(completion: @escaping ([KCSessionMetadata]) -> Void) {
        sessionMetadataQueue.async { [weak self] in
            let sessions = self?.loadAllSessions() ?? []
            DispatchQueue.main.async {
                completion(sessions)
            }
        }
    }

    // MARK: - 保存画作（UIImage 便捷方法）

    /// 保存来自 UIImage 的画作，内部生成 PNG 数据 + 240×180 JPEG 缩略图。
    /// 若 `existingSessionId` 非空则更新该会话，否则新建会话。
    /// 返回会话元数据 DTO，失败返回 nil。
    @objc func saveImage(_ image: UIImage, existingSessionId: String?) -> KCSessionMetadata? {
        guard let encodedData = encodedArtworkData(from: image) else { return nil }
        return saveArtwork(
            pngData: encodedData.pngData,
            thumbnailJPEGData: encodedData.thumbnailJPEGData,
            existingSessionId: existingSessionId
        )
    }

    /// 将完整画作编码为持久化所需的 PNG + 缩略图 JPEG。
    ///
    /// 该方法不访问磁盘、不读写缓存，可由编辑器放到后台队列执行，避免正式保存时
    /// PNG/JPEG 编码阻塞主线程。
    func encodedArtworkData(from image: UIImage) -> (pngData: Data, thumbnailJPEGData: Data)? {
        guard let pngData = image.pngData() else { return nil }
        let thumbnail = Self.generateThumbnail(from: image)
        guard let thumbData = thumbnail.jpegData(compressionQuality: 0.85) else { return nil }
        return (pngData: pngData, thumbnailJPEGData: thumbData)
    }

    /// 将图片 Data 转成已解码的 UIKit 位图。
    ///
    /// `UIImage(data:)` 可能延迟到首次 `draw(in:)` 时才真正解码像素；打开历史作品
    /// 或恢复草稿时必须在后台队列调用本入口，避免主线程首次绘制画布时承担大图解码。
    func displayDecodedImage(from data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return Self.displayDecodedImage(image)
    }

    // MARK: - 保存/读取画作（Data）

    /// 保存画作 PNG + JPEG 缩略图。若 `existingSessionId` 非空则更新该会话，
    /// 否则新建会话。返回会话元数据 DTO，失败返回 nil。
    @objc func saveArtwork(
        pngData: Data,
        thumbnailJPEGData: Data,
        existingSessionId: String?
    ) -> KCSessionMetadata? {
        let existing: KCArtworkSession? = existingSessionId.flatMap { findSession(id: $0) }
        guard let session = try? store.saveArtwork(
            pngData: pngData,
            thumbnailJPEGData: thumbnailJPEGData,
            existing: existing
        ) else { return nil }
        if let cachedThumbnail = displayDecodedImage(from: thumbnailJPEGData) {
            thumbnailImageCache.setObject(cachedThumbnail, forKey: session.id as NSString)
        } else {
            thumbnailImageCache.removeObject(forKey: session.id as NSString)
        }
        replaceCachedSession(session)
        return KCSessionMetadata(session)
    }

    /// 返回全分辨率画作 UIImage。
    @objc func artworkImage(forSessionId sessionId: String) -> UIImage? {
        guard let data = artworkData(forSessionId: sessionId) else { return nil }
        return displayDecodedImage(from: data)
    }

    /// 返回指定会话的全分辨率画作 PNG 数据。
    @objc func artworkData(forSessionId sessionId: String) -> Data? {
        guard let session = findSession(id: sessionId) else { return nil }
        return store.artworkData(for: session)
    }

    /// 按已加载的 metadata 读取全分辨率画作 PNG 数据，避免后台打开作品时再次触碰
    /// 服务层 metadata cache。
    func artworkData(forSession session: KCSessionMetadata) -> Data? {
        let artworkSession = KCArtworkSession(
            id: session.identifier,
            title: session.title,
            artworkFileName: session.artworkFileName,
            thumbnailFileName: session.thumbnailFileName,
            modifiedAt: session.modifiedAt
        )
        return store.artworkData(for: artworkSession)
    }

    /// 返回缩略图 UIImage。
    @objc func thumbnailImage(forSessionId sessionId: String) -> UIImage? {
        if let cachedThumbnail = cachedThumbnailImage(forSessionId: sessionId) {
            return cachedThumbnail
        }
        guard let data = thumbnailData(forSessionId: sessionId) else { return nil }
        guard let image = displayDecodedImage(from: data) else { return nil }
        thumbnailImageCache.setObject(image, forKey: sessionId as NSString)
        return image
    }

    /// 只读取内存缓存，不触发磁盘读取或图片解码，供历史栏主线程刷新使用。
    @objc func cachedThumbnailImage(forSessionId sessionId: String) -> UIImage? {
        guard findSession(id: sessionId) != nil else {
            thumbnailImageCache.removeObject(forKey: sessionId as NSString)
            return nil
        }
        return thumbnailImageCache.object(forKey: sessionId as NSString)
    }

    /// 按已加载 metadata 读取内存缩略图缓存，供历史栏刷新使用，避免主线程重复查找会话列表。
    func cachedThumbnailImage(forSession session: KCSessionMetadata) -> UIImage? {
        guard !session.identifier.isEmpty else { return nil }
        return thumbnailImageCache.object(forKey: session.identifier as NSString)
    }

    /// 后台预热指定会话的缩略图缓存，减少历史翻页时的主线程读盘/解码。
    func preloadThumbnailImages(forSessionIds sessionIds: [String], completion: (() -> Void)? = nil) {
        let requestedIds = Set(sessionIds)
        guard !requestedIds.isEmpty else {
            if let completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }

        let sessionsToPreload = cachedArtworkSessions().filter { session in
            guard requestedIds.contains(session.id) else { return false }
            let cacheKey = session.id as NSString
            if thumbnailImageCache.object(forKey: cacheKey) != nil {
                return false
            }

            thumbnailPreloadLock.lock()
            defer { thumbnailPreloadLock.unlock() }
            guard !thumbnailPreloadInFlight.contains(session.id) else {
                return false
            }
            thumbnailPreloadInFlight.insert(session.id)
            return true
        }
        guard !sessionsToPreload.isEmpty else {
            if let completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }

        thumbnailPreloadQueue.async { [weak self, sessionsToPreload] in
            guard let self else { return }
            for session in sessionsToPreload {
                let cacheKey = session.id as NSString
                if self.thumbnailImageCache.object(forKey: cacheKey) == nil,
                   let data = self.store.thumbnailData(for: session),
                   let image = self.displayDecodedImage(from: data) {
                    self.thumbnailImageCache.setObject(image, forKey: cacheKey)
                }

                self.thumbnailPreloadLock.lock()
                self.thumbnailPreloadInFlight.remove(session.id)
                self.thumbnailPreloadLock.unlock()
            }
            if let completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
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
        guard (try? store.delete(session)) != nil else { return }
        thumbnailImageCache.removeObject(forKey: sessionId as NSString)
        removeCachedSession(id: sessionId)
    }

    // MARK: - 草稿自动保存

    /// 保存来自 UIImage 的草稿（便捷方法）。
    @objc func saveDraftImage(_ image: UIImage) -> Bool {
        guard let data = image.pngData() else { return false }
        return saveDraftData(pngData: data, cachedImage: image)
    }

    /// 以 UIImage 形式加载草稿。
    @objc func loadDraftImage() -> UIImage? {
        draftCacheLock.lock()
        if let draftImageCache {
            draftCacheLock.unlock()
            return draftImageCache
        }
        draftCacheLock.unlock()
        guard let data = store.loadDraft() else { return nil }
        guard let image = displayDecodedImage(from: data) else { return nil }
        cacheLoadedDraftImage(image)
        return image
    }

    /// 只读取草稿缩略图内存缓存，不触发读盘或图片解码。
    @objc func cachedDraftThumbnailImage() -> UIImage? {
        draftCacheLock.lock()
        let thumbnail = draftThumbnailCache
        draftCacheLock.unlock()
        return thumbnail
    }

    /// 缓存已经异步解码出的草稿图，并同步补齐历史栏缩略图缓存。
    func cacheLoadedDraftImage(_ image: UIImage) {
        let thumbnail = Self.generateThumbnail(from: image)
        draftCacheLock.lock()
        draftImageCache = image
        draftThumbnailCache = thumbnail
        draftCacheLock.unlock()
    }

    /// 返回草稿缩略图，供历史面板使用。该路径不长期持有全尺寸草稿图，避免
    /// 高频历史刷新为了一个 240×180 缩略图保留整张画布。
    @objc func draftThumbnailImage() -> UIImage? {
        draftCacheLock.lock()
        if let draftThumbnailCache {
            draftCacheLock.unlock()
            return draftThumbnailCache
        }
        let cachedDraftImage = draftImageCache
        draftCacheLock.unlock()

        let sourceImage: UIImage
        if let cachedDraftImage {
            sourceImage = cachedDraftImage
        } else {
            guard let data = store.loadDraft(), let image = displayDecodedImage(from: data) else { return nil }
            sourceImage = image
        }

        let thumbnail = Self.generateThumbnail(from: sourceImage)
        draftCacheLock.lock()
        draftThumbnailCache = thumbnail
        draftCacheLock.unlock()
        return thumbnail
    }

    /// 轻量判断是否存在草稿文件，不读取或解码 `draft.png`，用于按钮状态和删除流程。
    @objc func hasDraft() -> Bool {
        draftCacheLock.lock()
        if draftImageCache != nil || draftThumbnailCache != nil {
            draftCacheLock.unlock()
            return true
        }
        draftCacheLock.unlock()
        return store.hasDraft()
    }

    @objc func saveDraftData(pngData: Data) -> Bool {
        saveDraftData(pngData: pngData, cachedImage: nil)
    }

    func saveDraftData(pngData: Data, cachedImage: UIImage?) -> Bool {
        let saved = (try? store.saveDraft(pngData: pngData)) ?? false
        let thumbnail = saved ? cachedImage.map { Self.generateThumbnail(from: $0) } : nil
        draftCacheLock.lock()
        draftImageCache = nil
        draftThumbnailCache = thumbnail
        draftCacheLock.unlock()
        return saved
    }

    @objc func loadDraftData() -> Data? {
        store.loadDraft()
    }

    @objc func clearDraft() {
        draftCacheLock.lock()
        draftImageCache = nil
        draftThumbnailCache = nil
        draftCacheLock.unlock()
        store.clearDraft()
    }

    // MARK: - 私有辅助方法

    private func findSession(id: String) -> KCArtworkSession? {
        cachedArtworkSessions().first { $0.id == id }
    }

    private func cachedArtworkSessions() -> [KCArtworkSession] {
        artworkSessionCacheLock.lock()
        if let artworkSessionCache {
            artworkSessionCacheLock.unlock()
            return artworkSessionCache
        }
        artworkSessionCacheLock.unlock()

        let sessions = (try? store.loadSessions()) ?? []

        artworkSessionCacheLock.lock()
        if let artworkSessionCache {
            artworkSessionCacheLock.unlock()
            return artworkSessionCache
        }
        artworkSessionCache = sessions
        artworkSessionCacheLock.unlock()
        return sessions
    }

    private func replaceCachedSession(_ session: KCArtworkSession) {
        artworkSessionCacheLock.lock()
        if var sessions = artworkSessionCache {
            sessions.removeAll { $0.id == session.id }
            sessions.insert(session, at: 0)
            artworkSessionCache = sessions
            artworkSessionCacheLock.unlock()
            return
        }
        artworkSessionCacheLock.unlock()

        guard let sessions = try? store.loadSessions() else { return }
        artworkSessionCacheLock.lock()
        artworkSessionCache = sessions
        artworkSessionCacheLock.unlock()
    }

    private func removeCachedSession(id sessionId: String) {
        artworkSessionCacheLock.lock()
        guard var sessions = artworkSessionCache else {
            artworkSessionCacheLock.unlock()
            thumbnailPreloadLock.lock()
            thumbnailPreloadInFlight.remove(sessionId)
            thumbnailPreloadLock.unlock()
            return
        }
        sessions.removeAll { $0.id == sessionId }
        artworkSessionCache = sessions
        artworkSessionCacheLock.unlock()
        thumbnailPreloadLock.lock()
        thumbnailPreloadInFlight.remove(sessionId)
        thumbnailPreloadLock.unlock()
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

    private static func displayDecodedImage(_ image: UIImage) -> UIImage? {
        let imageSize = image.size
        guard imageSize.width > 0.0, imageSize.height > 0.0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        return autoreleasepool {
            UIGraphicsImageRenderer(size: imageSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: imageSize))
            }
        }
    }
}
