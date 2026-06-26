//
//  KCContentCatalogDefaults.swift
//  KCContentCatalog
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCDomain
import KCCommon

/// 内置内容目录：色盘、贴纸分组和线稿模板。
/// 取值逐字迁移自 Objective-C 原型
/// （`makePalette24`/`makePalette36`、`stickerSymbolsByCategory`、`makeLineArtItems`）。
// TODO(content): palette24/36 仍硬编码，待后续迁移到 JSON（贴纸/线稿已迁移）。
public enum KCContentCatalogDefaults {
    /// 默认 24 色色盘，按显示顺序排列。
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

    /// 扩展 36 色色盘：在 24 色集合基础上追加 12 种更浅的粉彩色与灰阶色，
    /// 按原型顺序追加。
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

    /// 内置贴纸分组（类别 -> SF Symbol 名称），从 package resource 加载。
    public static let stickerGroups: [KCStickerGroup] = loaded.stickerGroups

    /// 内置线稿模板，从 package resource 加载。原型以程序化方式渲染这些模板。
    public static let lineArtTemplates: [KCLineArtTemplate] = loaded.lineArtTemplates

    /// 从 `Resources/content.json` 加载贴纸/线稿元数据；资源缺失或解码失败时回退到硬编码默认值。
    private static let loaded: KCContentDocument = {
        let data: Data? = {
            guard let url = Bundle.module.url(forResource: "content", withExtension: "json") else { return nil }
            return try? Data(contentsOf: url)
        }()
        return decodedContent(from: data)
            ?? KCContentDocument(stickerGroups: Fallback.stickerGroups, lineArtTemplates: Fallback.lineArtTemplates)
    }()

    /// 解码 JSON 数据为内容文档；数据为空或解码失败时返回 `nil`，由调用方回退。供加载与测试复用。
    static func decodedContent(from data: Data?) -> KCContentDocument? {
        guard let data,
              let doc = try? JSONDecoder().decode(KCContentDocument.self, from: data),
              !doc.stickerGroups.isEmpty,
              !doc.lineArtTemplates.isEmpty else { return nil }
        return doc
    }

    /// JSON 不可用时的硬编码回退，内容与 `Resources/content.json` 逐字一致。
    private enum Fallback {
        static let stickerGroups: [KCStickerGroup] = [
            KCStickerGroup(id: "animals", title: "Animals",
                         symbols: ["butterfly.fill", "pawprint.fill", "tortoise.fill", "hare.fill"]),
            KCStickerGroup(id: "nature", title: "Nature",
                         symbols: ["leaf.fill", "camera.macro", "sun.max.fill", "cloud.fill"]),
            KCStickerGroup(id: "decor", title: "Decor",
                         symbols: ["star.fill", "heart.fill", "moon.stars.fill", "rainbow", "gift.fill"]),
            KCStickerGroup(id: "faces", title: "Faces",
                         symbols: ["face.smiling.fill", "figure.2", "hand.thumbsup.fill", "sparkles"]),
        ]
        static let lineArtTemplates: [KCLineArtTemplate] = [
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
}

/// 内置内容 JSON 文档的解码容器（贴纸/线稿元数据外置为 package resource）。
struct KCContentDocument: Codable {
    let stickerGroups: [KCStickerGroup]
    let lineArtTemplates: [KCLineArtTemplate]
}

extension KCHexColor {
    /// 灰阶初始化方法，对应 `UIColor(white:alpha:)`。
    public init(white: Double, alpha: Double = 1.0) {
        self.init(red: white, green: white, blue: white, alpha: alpha)
    }
}

/// 所有内置内容的打包视图，便于注入。
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

    /// 返回与 `size` 对应的色盘。
    public func palette(for size: KCPaletteSize) -> KCContentPalette {
        switch size {
        case .standard: return standardPalette
        case .extended: return extendedPalette
        }
    }
}
