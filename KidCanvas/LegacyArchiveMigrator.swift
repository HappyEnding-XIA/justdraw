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

/// Swift replacement for the Objective-C `KDArtworkSession` model, exposed under
/// the **same Objective-C runtime name** (`@objc(KDArtworkSession)`) so that
/// `NSKeyedUnarchiver` resolves it against legacy `sessions.archive` files
/// written by the old OC app.
///
/// The `NSSecureCoding` keys are byte-identical to the former OC
/// `encodeWithCoder:`/`initWithCoder:` (`sessionIdentifier`, `title`,
/// `artworkFileName`, `thumbnailFileName`, `modifiedAt`), so existing users'
/// archives decode without any data migration. Co-located with its only consumer
/// (`LegacyArchiveMigrator`) to avoid a separate file/project entry.
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

/// Decodes the legacy `sessions.archive` (`NSKeyedArchiver` format containing
/// `KDArtworkSession` objects) and maps them to `KCArtworkSession` for the
/// Swift `KCSessionStore`.
///
/// This migrator is injected into `KCSessionStore` so that existing users'
/// artwork history is automatically carried over to the new `sessions.json`
/// format on first load.
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
