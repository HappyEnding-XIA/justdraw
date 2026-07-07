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
public enum KCContentCatalogDefaults {
    /// 无 IO 启动目录使用的 24 色 fallback。内容必须与 `Resources/content.json` 保持一致。
    public static let fallbackPalette24: [KCHexColor] = Fallback.palette24

    /// 无 IO 启动目录使用的 36 色 fallback。内容必须与 `Resources/content.json` 保持一致。
    public static let fallbackPalette36: [KCHexColor] = Fallback.palette36

    /// 无 IO 启动目录使用的贴纸分组 fallback。内容必须与 `Resources/content.json` 保持一致。
    public static let fallbackStickerGroups: [KCStickerGroup] = Fallback.stickerGroups

    /// 无 IO 启动目录使用的线稿模板 fallback。内容必须与 `Resources/content.json` 保持一致。
    public static let fallbackLineArtTemplates: [KCLineArtTemplate] = Fallback.lineArtTemplates

    /// 默认 24 色色盘，按显示顺序排列，从 package resource 加载。
    public static let palette24: [KCHexColor] = loaded.palette(id: "palette.24")?.colors ?? Fallback.palette24

    /// 扩展 36 色色盘：在 24 色集合基础上追加 12 种更浅的粉彩色与灰阶色，
    /// 按原型顺序追加，从 package resource 加载。
    public static let palette36: [KCHexColor] = loaded.palette(id: "palette.36")?.colors ?? Fallback.palette36

    /// 内置贴纸分组（类别 -> SF Symbol 名称），从 package resource 加载。
    public static let stickerGroups: [KCStickerGroup] = loaded.stickerGroups

    /// 内置线稿模板，从 package resource 加载。原型以程序化方式渲染这些模板。
    public static let lineArtTemplates: [KCLineArtTemplate] = loaded.lineArtTemplates

    /// 从 `Resources/content.json` 加载色盘、贴纸和线稿元数据；资源缺失或解码失败时回退到硬编码默认值。
    private static let loaded: KCContentDocument = {
        let data: Data? = {
            guard let url = Bundle.module.url(forResource: "content", withExtension: "json") else { return nil }
            return try? Data(contentsOf: url)
        }()
        return decodedContent(from: data)
            ?? KCContentDocument(
                palettes: Fallback.palettes,
                stickerGroups: Fallback.stickerGroups,
                lineArtTemplates: Fallback.lineArtTemplates
            )
    }()

    /// 解码 JSON 数据为内容文档；数据为空或解码失败时返回 `nil`，由调用方回退。供加载与测试复用。
    static func decodedContent(from data: Data?) -> KCContentDocument? {
        guard let data,
              let doc = try? JSONDecoder().decode(KCContentDocument.self, from: data),
              hasValidPalettes(doc),
              !doc.stickerGroups.isEmpty,
              !doc.lineArtTemplates.isEmpty else { return nil }
        return doc
    }

    /// 检查色盘资源是否完整，防止 JSON 漏字段后让 UI 布局悄悄漂移。
    private static func hasValidPalettes(_ doc: KCContentDocument) -> Bool {
        guard let palette24 = doc.palette(id: "palette.24"),
              let palette36 = doc.palette(id: "palette.36"),
              palette24.colors.count == 24,
              palette36.colors.count == 36 else { return false }
        return Array(palette36.colors.prefix(24)) == palette24.colors
    }

    /// JSON 不可用时的硬编码回退，内容与 `Resources/content.json` 逐字一致。
    private enum Fallback {
        static let palette24: [KCHexColor] = [
            KCHexColor(hex: "#F06E73")!,
            KCHexColor(hex: "#F08C5C")!,
            KCHexColor(hex: "#F5B557")!,
            KCHexColor(hex: "#F2CC69")!,
            KCHexColor(hex: "#BFD663")!,
            KCHexColor(hex: "#8FD6A1")!,
            KCHexColor(hex: "#6EC9B3")!,
            KCHexColor(hex: "#73BAF7")!,
            KCHexColor(hex: "#8C8AF2")!,
            KCHexColor(hex: "#B37DED")!,
            KCHexColor(hex: "#F0A1BD")!,
            KCHexColor(hex: "#E863A6")!,
            KCHexColor(hex: "#E04261")!,
            KCHexColor(hex: "#B33845")!,
            KCHexColor(hex: "#A87038")!,
            KCHexColor(hex: "#CFA357")!,
            KCHexColor(hex: "#9678DE")!,
            KCHexColor(hex: "#6194F2")!,
            KCHexColor(hex: "#388AD1")!,
            KCHexColor(hex: "#33A191")!,
            KCHexColor(hex: "#428557")!,
            KCHexColor(hex: "#5E594F")!,
            KCHexColor(hex: "#A1A1A1")!,
            KCHexColor(hex: "#242930")!,
        ]
        static let palette36: [KCHexColor] = palette24 + [
            KCHexColor(hex: "#FACFCF")!,
            KCHexColor(hex: "#FCE6C2")!,
            KCHexColor(hex: "#DBEDBA")!,
            KCHexColor(hex: "#BFEBE3")!,
            KCHexColor(hex: "#CCE3FC")!,
            KCHexColor(hex: "#E3D4FA")!,
            KCHexColor(hex: "#F7D1E8")!,
            KCHexColor(hex: "#E3B08F")!,
            KCHexColor(hex: "#A1B8C9")!,
            KCHexColor(hex: "#DBDBDB")!,
            KCHexColor(hex: "#F5F5F5")!,
            KCHexColor(hex: "#0D0D0D")!,
        ]
        static let palettes: [KCContentPalette] = [
            KCContentPalette(id: "palette.24", title: "24 Colors", colors: palette24),
            KCContentPalette(id: "palette.36", title: "36 Colors", colors: palette36),
        ]
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

/// 内置内容 JSON 文档的解码容器（色盘、贴纸、线稿元数据外置为 package resource）。
struct KCContentDocument: Codable {
    let palettes: [KCContentPalette]
    let stickerGroups: [KCStickerGroup]
    let lineArtTemplates: [KCLineArtTemplate]

    func palette(id: String) -> KCContentPalette? {
        palettes.first { $0.id == id }
    }
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

    /// 显式构造资源目录版本。该入口会读取 package resource，适合测试或后续内容热更新，
    /// 不应放在首帧前的 App 启动路径上。
    public static func resourceBacked() -> KCBundledContentCatalog {
        KCBundledContentCatalog(
            standardPalette: KCContentPalette(
                id: "palette.24", title: "24 Colors", colors: KCContentCatalogDefaults.palette24
            ),
            extendedPalette: KCContentPalette(
                id: "palette.36", title: "36 Colors", colors: KCContentCatalogDefaults.palette36
            ),
            stickerGroups: KCContentCatalogDefaults.stickerGroups,
            lineArtTemplates: KCContentCatalogDefaults.lineArtTemplates
        )
    }

    public init(
        standardPalette: KCContentPalette = KCContentPalette(
            id: "palette.24", title: "24 Colors", colors: KCContentCatalogDefaults.fallbackPalette24
        ),
        extendedPalette: KCContentPalette = KCContentPalette(
            id: "palette.36", title: "36 Colors", colors: KCContentCatalogDefaults.fallbackPalette36
        ),
        stickerGroups: [KCStickerGroup] = KCContentCatalogDefaults.fallbackStickerGroups,
        lineArtTemplates: [KCLineArtTemplate] = KCContentCatalogDefaults.fallbackLineArtTemplates
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
