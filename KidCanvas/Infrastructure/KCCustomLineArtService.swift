//
//  KCCustomLineArtService.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/09.
//

import Foundation
import UIKit
import KCDomain
import KCSessionPersistence

/// `KCCustomLineArt` 的只读 App 视图模型（DTO）。标题经本地化格式化为“我的线稿 N”，
/// 不改变磁盘 schema（store 仍持久化 `sequenceNumber` 等稳定字段）。
@objc(KCCustomLineArtMetadata)
final class KCCustomLineArtMetadata: NSObject {
    @objc let identifier: String
    @objc let sequenceNumber: Int
    @objc let title: String
    @objc let lineArtFileName: String
    @objc let thumbnailFileName: String
    @objc let createdAt: Date

    init(
        identifier: String,
        sequenceNumber: Int,
        title: String,
        lineArtFileName: String,
        thumbnailFileName: String,
        createdAt: Date
    ) {
        self.identifier = identifier
        self.sequenceNumber = sequenceNumber
        self.title = title
        self.lineArtFileName = lineArtFileName
        self.thumbnailFileName = thumbnailFileName
        self.createdAt = createdAt
    }

    init(_ item: KCCustomLineArt) {
        self.identifier = item.id
        self.sequenceNumber = item.sequenceNumber
        self.title = KCL10n.customLineArtTitle(item.sequenceNumber)
        self.lineArtFileName = item.lineArtFileName
        self.thumbnailFileName = item.thumbnailFileName
        self.createdAt = item.createdAt
    }
}

/// 基于 `KCCustomLineArtStore` 的 App 适配层（T099）。镜像 `KCSessionService` 的形态：
/// 持有 store、缩略图 `NSCache`，以类型化 `KCCustomLineArtMetadata` DTO 返回，
/// 存储错误静默降级（`try?`，返回 nil/空/false），不抛出跨越 ObjC 桥。
///
/// 删除我的线稿只删线稿库条目（store 独立目录），不影响历史作品。
@objc(KCCustomLineArtService)
final class KCCustomLineArtService: NSObject {
    private let store: KCCustomLineArtStore
    private let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 48
        return cache
    }()
    private let persistenceQueue = DispatchQueue(label: "com.kidcanvas.custom-line-art", qos: .userInitiated)

    private static let thumbnailSize = CGSize(width: 240, height: 180)

    override init() {
        self.store = KCCustomLineArtStore()
        super.init()
    }

    /// 测试/注入入口。
    init(store: KCCustomLineArtStore) {
        self.store = store
        super.init()
    }

    /// 当前我的线稿数量上限（与 store 一致）。
    @objc var maxItemCount: Int { KCCustomLineArtStore.maxItemCount }

    /// 加载全部我的线稿（最新创建在前）。失败返回空。
    @objc func loadAll() -> [KCCustomLineArtMetadata] {
        ((try? store.loadAll()) ?? []).map { KCCustomLineArtMetadata($0) }
    }

    /// 当前数量。
    @objc func count() -> Int {
        (try? store.count()) ?? 0
    }

    /// 是否已达数量上限。
    @objc func hasReachedCap() -> Bool {
        count() >= KCCustomLineArtStore.maxItemCount
    }

    /// 把线稿位图编码为持久化所需的 PNG + 缩略图 JPEG（不访问磁盘，可在后台队列执行）。
    func encodedLineArtData(from image: UIImage) -> (pngData: Data, thumbnailJPEGData: Data)? {
        guard let pngData = image.pngData() else { return nil }
        let thumbnail = Self.generateThumbnail(from: image)
        guard let thumbData = thumbnail.jpegData(compressionQuality: 0.85) else { return nil }
        return (pngData, thumbData)
    }

    /// 保存一条位图线稿。返回新条目 DTO；图像无效或达上限返回 nil。
    /// 在后台队列执行磁盘写入，completion 回主线程。
    @objc func saveLineArt(
        image: UIImage,
        sourceKind: Int,
        sourceSessionId: String?,
        completion: ((KCCustomLineArtMetadata?) -> Void)?
    ) {
        let kind = KCCustomLineArtSourceKind(rawValue: sourceKind == 1 ? "photoExtraction" : "canvasSave") ?? .canvasSave
        guard let encoded = encodedLineArtData(from: image) else {
            DispatchQueue.main.async { completion?(nil) }
            return
        }
        let store = self.store
        let thumbnailCache = self.thumbnailCache
        persistenceQueue.async {
            let saved = try? store.save(
                lineArtPNG: encoded.pngData,
                thumbnailJPEG: encoded.thumbnailJPEGData,
                sourceKind: kind,
                sourceSessionId: sourceSessionId
            )
            if let saved, let thumb = UIImage(data: encoded.thumbnailJPEGData) {
                thumbnailCache.setObject(thumb, forKey: saved.id as NSString)
            }
            let dto = saved.map { KCCustomLineArtMetadata($0) }
            DispatchQueue.main.async { completion?(dto) }
        }
    }

    /// 读取某条线稿的全分辨率位图（磁盘读取，调用方应避免主线程大图）。
    @objc func lineArtImage(forId identifier: String) -> UIImage? {
        guard let item = item(matching: identifier) else { return nil }
        guard let data = store.lineArtData(for: item) else { return nil }
        return UIImage(data: data)
    }

    /// 读取缩略图（磁盘 + 缓存回填）。
    @objc func thumbnailImage(forId identifier: String) -> UIImage? {
        if let cached = thumbnailCache.object(forKey: identifier as NSString) {
            return cached
        }
        guard let item = item(matching: identifier),
              let data = store.thumbnailData(for: item),
              let image = UIImage(data: data) else {
            return nil
        }
        thumbnailCache.setObject(image, forKey: identifier as NSString)
        return image
    }

    /// 仅内存缓存的缩略图（主线程安全）。
    @objc func cachedThumbnailImage(forId identifier: String) -> UIImage? {
        thumbnailCache.object(forKey: identifier as NSString)
    }

    /// 预热缩略图缓存（后台解码）。
    func preloadThumbnailImages(forIds identifiers: [String], completion: (() -> Void)?) {
        let store = self.store
        let thumbnailCache = self.thumbnailCache
        persistenceQueue.async {
            for id in identifiers {
                guard thumbnailCache.object(forKey: id as NSString) == nil,
                      let item = (try? store.loadAll())?.first(where: { $0.id == id }),
                      let data = store.thumbnailData(for: item),
                      let image = UIImage(data: data) else { continue }
                thumbnailCache.setObject(image, forKey: id as NSString)
            }
            DispatchQueue.main.async { completion?() }
        }
    }

    /// 删除一条我的线稿（先更新内存/缓存，再后台删盘）。只删线稿库，不影响历史。
    @objc func deleteLineArt(withIdentifier identifier: String) {
        thumbnailCache.removeObject(forKey: identifier as NSString)
        let store = self.store
        persistenceQueue.async {
            if let item = (try? store.loadAll())?.first(where: { $0.id == identifier }) {
                try? store.delete(item)
            }
        }
    }

    // MARK: - 内部

    private func item(matching identifier: String) -> KCCustomLineArt? {
        ((try? store.loadAll()) ?? []).first { $0.id == identifier }
    }

#if DEBUG
    /// Debug/运行时验收：同步保存（绕过持久化队列），便于探针同步断言。生产路径仍走 `saveLineArt`。
    @discardableResult
    func runtimeAcceptanceSaveSynchronously(image: UIImage, sourceSessionId: String?) -> KCCustomLineArtMetadata? {
        guard let encoded = encodedLineArtData(from: image),
              let saved = try? store.save(
                lineArtPNG: encoded.pngData,
                thumbnailJPEG: encoded.thumbnailJPEGData,
                sourceKind: .canvasSave,
                sourceSessionId: sourceSessionId
              ) else {
            return nil
        }
        if let thumb = UIImage(data: encoded.thumbnailJPEGData) {
            thumbnailCache.setObject(thumb, forKey: saved.id as NSString)
        }
        return KCCustomLineArtMetadata(saved)
    }

    /// Debug/运行时验收：同步删除。
    func runtimeAcceptanceDeleteSynchronously(identifier: String) {
        thumbnailCache.removeObject(forKey: identifier as NSString)
        if let item = (try? store.loadAll())?.first(where: { $0.id == identifier }) {
            try? store.delete(item)
        }
    }
#endif

    private static func generateThumbnail(from image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: thumbnailSize))
            let imageSize = image.size
            guard imageSize.width > 0, imageSize.height > 0 else { return }
            let scale = min(thumbnailSize.width / imageSize.width, thumbnailSize.height / imageSize.height)
            let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
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
