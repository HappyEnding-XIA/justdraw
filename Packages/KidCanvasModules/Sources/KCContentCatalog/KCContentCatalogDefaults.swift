//
//  KCContentCatalogDefaults.swift
//  KCContentCatalog
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCDomain
import KCCommon

/// Built-in content catalog: color palettes, sticker groups, and line-art
/// templates. Values are ported verbatim from the Objective-C prototype
/// (`makePalette24`/`makePalette36`, `stickerSymbolsByCategory`, `makeLineArtItems`).
// TODO(content): move to JSON/package resource.
public enum KCContentCatalogDefaults {
    /// The default 24-color palette, in display order.
    public static let palette24: [KCHexColor] = [
        KCHexColor(red: 0.94, green: 0.43, blue: 0.45),
        KCHexColor(red: 0.94, green: 0.55, blue: 0.36),
        KCHexColor(red: 0.96, green: 0.71, blue: 0.34),
        KCHexColor(red: 0.95, green: 0.80, blue: 0.41),
        KCHexColor(red: 0.75, green: 0.84, blue: 0.39),
        KCHexColor(red: 0.56, green: 0.84, blue: 0.63),
        KCHexColor(red: 0.43, green: 0.79, blue: 0.70),
        KCHexColor(red: 0.45, green: 0.73, blue: 0.97),
        KCHexColor(red: 0.55, green: 0.54, blue: 0.95),
        KCHexColor(red: 0.70, green: 0.49, blue: 0.93),
        KCHexColor(red: 0.94, green: 0.63, blue: 0.74),
        KCHexColor(red: 0.91, green: 0.39, blue: 0.65),
        KCHexColor(red: 0.88, green: 0.26, blue: 0.38),
        KCHexColor(red: 0.70, green: 0.22, blue: 0.27),
        KCHexColor(red: 0.66, green: 0.44, blue: 0.22),
        KCHexColor(red: 0.81, green: 0.64, blue: 0.34),
        KCHexColor(red: 0.59, green: 0.47, blue: 0.87),
        KCHexColor(red: 0.38, green: 0.58, blue: 0.95),
        KCHexColor(red: 0.22, green: 0.54, blue: 0.82),
        KCHexColor(red: 0.20, green: 0.63, blue: 0.57),
        KCHexColor(red: 0.26, green: 0.52, blue: 0.34),
        KCHexColor(red: 0.37, green: 0.35, blue: 0.31),
        KCHexColor(white: 0.63),
        KCHexColor(red: 0.14, green: 0.16, blue: 0.19),
    ]

    /// The extended 36-color palette: the 24-color set plus 12 lighter pastels
    /// and grayscale tones, appended in prototype order.
    public static let palette36: [KCHexColor] = palette24 + [
        KCHexColor(red: 0.98, green: 0.81, blue: 0.81),
        KCHexColor(red: 0.99, green: 0.90, blue: 0.76),
        KCHexColor(red: 0.86, green: 0.93, blue: 0.73),
        KCHexColor(red: 0.75, green: 0.92, blue: 0.89),
        KCHexColor(red: 0.80, green: 0.89, blue: 0.99),
        KCHexColor(red: 0.89, green: 0.83, blue: 0.98),
        KCHexColor(red: 0.97, green: 0.82, blue: 0.91),
        KCHexColor(red: 0.89, green: 0.69, blue: 0.56),
        KCHexColor(red: 0.63, green: 0.72, blue: 0.79),
        KCHexColor(white: 0.86),
        KCHexColor(white: 0.96),
        KCHexColor(white: 0.05),
    ]

    /// Built-in sticker groups (category -> SF Symbol names), in display order.
    public static let stickerGroups: [KCStickerGroup] = [
        KCStickerGroup(id: "animals", title: "Animals",
                     symbols: ["butterfly.fill", "pawprint.fill", "tortoise.fill", "hare.fill"]),
        KCStickerGroup(id: "nature", title: "Nature",
                     symbols: ["leaf.fill", "camera.macro", "sun.max.fill", "cloud.fill"]),
        KCStickerGroup(id: "decor", title: "Decor",
                     symbols: ["star.fill", "heart.fill", "moon.stars.fill", "rainbow", "gift.fill"]),
        KCStickerGroup(id: "faces", title: "Faces",
                     symbols: ["face.smiling.fill", "figure.2", "hand.thumbsup.fill", "sparkles"]),
    ]

    /// Built-in line-art templates, in display order. The prototype renders these
    /// procedurally; categories are assigned here for future grouping.
    public static let lineArtTemplates: [KCLineArtTemplate] = [
        KCLineArtTemplate(id: "bunny", title: "Bunny", category: "Animals"),
        KCLineArtTemplate(id: "car", title: "Car", category: "Vehicles"),
        KCLineArtTemplate(id: "fish", title: "Fish", category: "Animals"),
        KCLineArtTemplate(id: "flower", title: "Flower", category: "Nature"),
        KCLineArtTemplate(id: "house", title: "House", category: "Objects"),
        KCLineArtTemplate(id: "rocket", title: "Rocket", category: "Vehicles"),
        KCLineArtTemplate(id: "cupcake", title: "Cupcake", category: "Food"),
        KCLineArtTemplate(id: "dino", title: "Dino", category: "Animals"),
    ]
}

extension KCHexColor {
    /// Grayscale initializer mirroring `UIColor(white:alpha:)`.
    public init(white: Double, alpha: Double = 1.0) {
        self.init(red: white, green: white, blue: white, alpha: alpha)
    }
}

/// A bundled view of all built-in content, convenient for injection.
public struct KCBundledContentCatalog: Sendable {
    public let standardPalette: KCContentPalette
    public let extendedPalette: KCContentPalette
    public let stickerGroups: [KCStickerGroup]
    public let lineArtTemplates: [KCLineArtTemplate]

    public init(
        standardPalette: KCContentPalette = KCContentPalette(
            id: "palette.24", title: "24 Colors", colors: KCContentCatalogDefaults.palette24
        ),
        extendedPalette: KCContentPalette = KCContentPalette(
            id: "palette.36", title: "36 Colors", colors: KCContentCatalogDefaults.palette36
        ),
        stickerGroups: [KCStickerGroup] = KCContentCatalogDefaults.stickerGroups,
        lineArtTemplates: [KCLineArtTemplate] = KCContentCatalogDefaults.lineArtTemplates
    ) {
        self.standardPalette = standardPalette
        self.extendedPalette = extendedPalette
        self.stickerGroups = stickerGroups
        self.lineArtTemplates = lineArtTemplates
    }

    /// Returns the palette matching `size`.
    public func palette(for size: KCPaletteSize) -> KCContentPalette {
        switch size {
        case .standard: return standardPalette
        case .extended: return extendedPalette
        }
    }
}
