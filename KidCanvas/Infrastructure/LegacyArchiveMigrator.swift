//
//  LegacyArchiveMigrator.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCCommon
import KCDomain
import KCSessionPersistence

/// 替代原 Objective-C `KDArtworkSession` 模型的 Swift 类，使用**相同的
/// Objective-C 运行时类名**（`@objc(KDArtworkSession)`）暴露，这样
/// `NSKeyedUnarchiver` 在解码旧版 OC app 写入的 `sessions.archive` 时，
/// 仍能按类名解析到本类型。
///
/// `NSSecureCoding` 的 key 与原 OC 的 `encodeWithCoder:`/`initWithCoder:`
/// 完全一致（`sessionIdentifier`、`title`、`artworkFileName`、
/// `thumbnailFileName`、`modifiedAt`），因此老用户的 archive 无需数据迁移
/// 即可解码。与唯一消费者（`LegacyArchiveMigrator`）共置于同一文件，避免
/// 新增单独的文件/工程条目。
@objc(KDArtworkSession)
final class KCLegacyArtworkSession: NSObject, NSSecureCoding {
    @objc var sessionIdentifier: String?
    @objc var title: String?
    @objc var artworkFileName: String?
    @objc var thumbnailFileName: String?
    @objc var modifiedAt: Date?

    override init() {
        self.modifiedAt = Date()
        super.init()
    }

    static var supportsSecureCoding: Bool { true }

    func encode(with coder: NSCoder) {
        coder.encode(sessionIdentifier, forKey: "sessionIdentifier")
        coder.encode(title, forKey: "title")
        coder.encode(artworkFileName, forKey: "artworkFileName")
        coder.encode(thumbnailFileName, forKey: "thumbnailFileName")
        coder.encode(modifiedAt, forKey: "modifiedAt")
    }

    required init?(coder: NSCoder) {
        self.sessionIdentifier = coder.decodeObject(of: NSString.self, forKey: "sessionIdentifier") as String?
        self.title = coder.decodeObject(of: NSString.self, forKey: "title") as String?
        self.artworkFileName = coder.decodeObject(of: NSString.self, forKey: "artworkFileName") as String?
        self.thumbnailFileName = coder.decodeObject(of: NSString.self, forKey: "thumbnailFileName") as String?
        self.modifiedAt = coder.decodeObject(of: NSDate.self, forKey: "modifiedAt") as Date?
        super.init()
    }
}

/// 解码旧版 `sessions.archive`（`NSKeyedArchiver` 格式，内含
/// `KDArtworkSession` 对象），并映射为 `KCArtworkSession` 供 Swift
/// `KCSessionStore` 使用。
///
/// 本迁移器注入 `KCSessionStore`，使老用户的画作历史在首次加载时自动
/// 迁移到新的 `sessions.json` 格式。
final class LegacyArchiveMigrator: NSObject, KCLegacySessionMigrator {
    func decode(legacyArchiveAt url: URL) -> [KCArtworkSession]? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        let allowedClasses: [AnyClass] = [
            NSArray.self,
            KCLegacyArtworkSession.self,
            NSString.self,
            NSDate.self,
        ]

        guard let legacySessions = try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: allowedClasses,
            from: data
        ) as? [KCLegacyArtworkSession] else {
            return nil
        }

        guard !legacySessions.isEmpty else { return nil }

        return legacySessions.map { legacy in
            KCArtworkSession(
                id: legacy.sessionIdentifier ?? UUID().uuidString,
                title: legacy.title ?? "",
                artworkFileName: legacy.artworkFileName ?? "",
                thumbnailFileName: legacy.thumbnailFileName ?? "",
                modifiedAt: legacy.modifiedAt ?? Date.distantPast
            )
        }
    }
}
