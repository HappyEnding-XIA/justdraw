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

/// Decodes the legacy OC `sessions.archive` (`NSKeyedArchiver` format containing
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
            KDArtworkSession.self,
            NSString.self,
            NSDate.self,
        ]

        guard let ocSessions = try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: allowedClasses,
            from: data
        ) as? [KDArtworkSession] else {
            return nil
        }

        guard !ocSessions.isEmpty else { return nil }

        return ocSessions.map { oc in
            KCArtworkSession(
                id: oc.sessionIdentifier ?? UUID().uuidString,
                title: oc.title ?? "",
                artworkFileName: oc.artworkFileName ?? "",
                thumbnailFileName: oc.thumbnailFileName ?? "",
                modifiedAt: oc.modifiedAt ?? Date.distantPast
            )
        }
    }
}
