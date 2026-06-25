//
//  KCContentBridge.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCCommon
import KCDomain
import KCContentCatalog

/// Lightweight `@objc` bridge so the Objective-C canvas can consume the
/// Swift content catalog without pulling in the full package API surface.
///
/// All methods are `class` (static) and return Foundation types that
/// automatically bridge to the OC side via `#import "KidCanvas-Swift.h"`.
///
/// NOTE: This is a temporary adapter for the OC→Swift migration period.
/// Once the main canvas is fully in Swift, call `KCContentCatalogDefaults`
/// directly instead of going through this bridge.
@objc(KCContentBridge)
final class KCContentBridge: NSObject {

    /// 24-color default palette, returned as hex strings (`#RRGGBB`).
    @objc static func default24PaletteHexStrings() -> [String] {
        KCContentCatalogDefaults.palette24.map(\.hex)
    }

    /// 36-color extended palette, returned as hex strings.
    @objc static func default36PaletteHexStrings() -> [String] {
        KCContentCatalogDefaults.palette36.map(\.hex)
    }

    /// Sticker groups in display order.
    /// Each dictionary contains `"id"`, `"title"`, and `"symbols"` (array of SF Symbol names).
    @objc static func defaultStickerGroupDictionaries() -> [[String: Any]] {
        KCContentCatalogDefaults.stickerGroups.map { [
            "id": $0.id,
            "title": $0.title,
            "symbols": $0.symbols,
        ] as [String: Any]
        }
    }

    /// Line-art template titles in display order.
    @objc static func defaultLineArtTemplateTitles() -> [String] {
        KCContentCatalogDefaults.lineArtTemplates.map(\.title)
    }

    /// Line-art template identifiers in display order.
    @objc static func defaultLineArtTemplateIds() -> [String] {
        KCContentCatalogDefaults.lineArtTemplates.map(\.id)
    }
}
