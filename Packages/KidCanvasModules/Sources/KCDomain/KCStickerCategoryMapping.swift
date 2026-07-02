//
//  KCStickerCategoryMapping.swift
//  KCDomain
//
//  Created by 小大 on 2026/07/02.
//

import Foundation

/// 不依赖 UIKit 的贴纸分类映射模型——内容选择 Feature
/// （`KCContentPickerFeature`）抽出的纯字符串边界。
///
/// 此前 `KCMainViewController` 把三套映射内联在控制器里：
/// 分类 → SF Symbol（`stickerCategorySymbolForCategory:`）、
/// 贴纸符号 → 无障碍标签（`stickerAccessibilityLabelForSymbol:`）、
/// 以及按钮 accessibility identifier slug → 分类（`stickerCategoryFromButton:`）。
/// 这里集中为纯函数，便于单测。实际的 UIKit 按钮构建仍留在控制器。
public enum KCStickerCategoryMapping {

    /// 分类 → 分类按钮图标 SF Symbol。
    public static func categorySymbol(forCategory category: String) -> String {
        switch category {
        case "Animals": return "pawprint.fill"
        case "Nature": return "leaf.fill"
        case "Decor": return "sparkles"
        case "Faces": return "face.smiling.fill"
        default: return "star.fill"
        }
    }

    /// 贴纸符号 → 无障碍标签；未知符号回退到 "Sticker"。
    public static func accessibilityLabel(forSymbol symbol: String) -> String {
        let labels: [String: String] = [
            "star.fill": "Star Sticker",
            "heart.fill": "Heart Sticker",
            "sun.max.fill": "Sun Sticker",
            "leaf.fill": "Leaf Sticker",
            "cloud.fill": "Cloud Sticker",
            "moon.stars.fill": "Moon Sticker",
            "rainbow": "Rainbow Sticker",
            "camera.macro": "Flower Sticker",
            "butterfly.fill": "Butterfly Sticker",
            "pawprint.fill": "Paw Sticker",
            "gift.fill": "Gift Sticker",
            "face.smiling.fill": "Smile Sticker",
        ]
        return labels[symbol] ?? "Sticker"
    }

    /// 把按钮 accessibility identifier 解析回分类标题。
    /// identifier 形如 `sticker.category.<slug>`，slug 为分类标题的小写形式；
    /// 在 `categories` 中找到大小写不敏感匹配则返回该分类标题，否则返回 `nil`。
    public static func category(forIdentifier identifier: String, inCategories categories: [String]) -> String? {
        let prefix = "sticker.category."
        guard identifier.hasPrefix(prefix) else { return nil }
        let slug = String(identifier.dropFirst(prefix.count))
        return categories.first { $0.lowercased() == slug }
    }
}
