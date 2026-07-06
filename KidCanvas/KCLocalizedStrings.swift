//
//  KCLocalizedStrings.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/03.
//

import Foundation

/// 用户可见文案的统一本地化入口（T025）。
///
/// 默认语言为简体中文（`zh-Hans.lproj/Localizable.strings`），英文为可切换语言
/// （`en.lproj/Localizable.strings`）。所有用户可见文案通过本入口取值，不在
/// 控制器/Feature 中硬编码；新增文案时先在两个 `.strings` 文件中同时加 key，
/// 再在这里补类型安全的访问入口。
///
/// `KCDomain` 中的纯展示型 helper（如 `KCToolStateChipTitle`、
/// `KCStickerCategoryMapping`、`KCHistoryThumbStatus.accessibilityPrefix`）
/// 只返回稳定的本地化 key（ASCII），由本入口在 App 层解析为最终文案，
/// 从而保持 `KCDomain` 无 UIKit、无 bundle 依赖、可单测。
enum KCL10n {

    /// 按 key 取本地化文案；缺失时 `NSLocalizedString` 回退到 key 本身。
    static func tr(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, comment: comment)
    }

    /// 带位置参数的本地化文案（`%d` / `%@` 等）。缺失时回退到 key 本身。
    static func tr(_ key: String, _ args: CVarArg..., comment: String = "") -> String {
        String(format: NSLocalizedString(key, comment: comment), arguments: args)
    }

    // MARK: - 顶部工具栏

    static var paletteTitle: String { tr("top.palette.title") }
    static var newCanvasTitle: String { tr("top.new-canvas.title") }
    static var undoTitle: String { tr("top.undo.title") }
    static var redoTitle: String { tr("top.redo.title") }
    static var openLatestTitle: String { tr("top.open-latest.title") }
    static var lineArtTitle: String { tr("top.line-art.title") }
    static var importPhotoTitle: String { tr("top.import-photo.title") }
    static var saveTitle: String { tr("top.save.title") }

    // MARK: - 左侧工具栏

    static var toolBrushTitle: String { tr("tool.brush.title") }
    static var toolEraserTitle: String { tr("tool.eraser.title") }
    static var toolFillTitle: String { tr("tool.fill.title") }
    static var toolStickerTitle: String { tr("tool.sticker.title") }
    static var toolPickerTitle: String { tr("tool.picker.title") }

    // MARK: - 面板标题

    static var colorsPanelTitle: String { tr("panel.colors.title") }
    static var brushStickerPanelTitle: String { tr("panel.brush-sticker.title") }
    static var stickersPanelTitle: String { tr("panel.stickers.title") }
    static var eraserPanelTitle: String { tr("panel.eraser.title") }
    static var stickerEditPanelTitle: String { tr("panel.sticker-edit.title") }
    static var historyPanelTitle: String { tr("panel.history.title") }
    static var brushesPanelTitle: String { tr("panel.brushes.title") }

    // MARK: - 色盘

    static var palette24Title: String { tr("palette.24.title") }
    static var palette36Title: String { tr("palette.36.title") }
    static func paletteColorTitle(_ index: Int) -> String { tr("palette.color.title", index) }
    static func recentColorAccessibility(_ index: Int) -> String { tr("palette.recent.accessibility", index) }

    // MARK: - 自定义颜色

    static var customColorTitle: String { tr("action.custom-color.title") }
    static var customColorAccessibility: String { tr("action.custom-color.accessibility") }

    // MARK: - 画笔名称

    static var pencilTitle: String { tr("brush.pencil.title") }
    static var penTitle: String { tr("brush.pen.title") }
    static var crayonTitle: String { tr("brush.crayon.title") }

    // MARK: - 粗细 / 橡皮 / 印章编辑

    static var sizeSliderAccessibility: String { tr("size.slider.accessibility") }
    static var circleEraserTitle: String { tr("eraser.circle.title") }
    static var cloudEraserTitle: String { tr("eraser.cloud.title") }
    static var starEraserTitle: String { tr("eraser.star.title") }
    static var bringStickerForwardTitle: String { tr("sticker.bring-forward.title") }
    static var deleteStickerTitle: String { tr("sticker.delete.title") }

    // MARK: - 印章分类

    /// 分类稳定标识（与 `content.json` 的 `stickerGroups[].title` 一致）→ 本地化展示名。
    /// 产品侧展示为“印章”，内部仍沿用 sticker 稳定模型和资源 schema。
    static func stickerCategoryTitle(_ categoryIdentifier: String) -> String {
        switch categoryIdentifier {
        case "Animals": return tr("sticker.category.animals.title")
        case "Nature": return tr("sticker.category.nature.title")
        case "Decor": return tr("sticker.category.decor.title")
        case "Faces": return tr("sticker.category.faces.title")
        default: return categoryIdentifier
        }
    }

    /// 分类稳定标识 → 「<分类> 印章」无障碍标签。
    static func stickerCategoryAccessibility(_ categoryIdentifier: String) -> String {
        String(format: tr("sticker.category.accessibility"), stickerCategoryTitle(categoryIdentifier))
    }

    /// 印章本地化 key（由 `KCStickerCategoryMapping` 返回）→ 本地化无障碍标签。
    static func stickerSymbolAccessibility(_ localizationKey: String) -> String {
        tr(localizationKey)
    }

    // MARK: - 历史面板

    static var draftTitle: String { tr("history.draft.title") }
    static var savedTitle: String { tr("history.saved.title") }
    static var openLatestHistoryTitle: String { tr("history.open-latest.title") }
    static var importPhotoHistoryTitle: String { tr("history.import-photo.title") }
    static var deleteLatestHistoryTitle: String { tr("history.delete-latest.title") }
    static var previousHistoryPageTitle: String { tr("history.previous-page.title") }
    static var nextHistoryPageTitle: String { tr("history.next-page.title") }
    static var draftThumbAccessibility: String { tr("history.draft-thumb.accessibility") }
    static func savedThumbAccessibility(_ index: Int) -> String { tr("history.saved-thumb.accessibility", index) }

    /// 历史缩略图状态本地化 key（由 `KCHistoryThumbStatus.accessibilityPrefix` 返回）→ 本地化前缀。
    static func historyThumbPrefix(_ localizationKey: String) -> String {
        tr(localizationKey)
    }

    // MARK: - 画布角标 / 折叠按钮 / 弹窗

    static var canvasBadge: String { tr("badge.canvas") }
    static var lineArtBadge: String { tr("badge.line-art") }
    static var hideToolsTitle: String { tr("action.hide-tools.title") }
    static var showToolsTitle: String { tr("action.show-tools.title") }
    static var clearCanvasAlertTitle: String { tr("alert.clear-canvas.title") }
    static var clearCanvasAlertMessage: String { tr("alert.clear-canvas.message") }
    static var cancelTitle: String { tr("alert.cancel") }
    static var clearTitle: String { tr("alert.clear") }
    static var deleteTitle: String { tr("alert.delete") }
    static func deleteAlertTitle(isDraft: Bool) -> String { tr(isDraft ? "alert.delete-draft.title" : "alert.delete-session.title") }
    static func deleteAlertMessage(isDraft: Bool) -> String { tr(isDraft ? "alert.delete-draft.message" : "alert.delete-session.message") }

    // MARK: - 线稿标题（无障碍）

    /// 线稿稳定标识（`content.json` 的 `lineArtTemplates[].title`）→ 本地化展示名。
    static func lineArtTitle(_ lineArtIdentifier: String) -> String {
        switch lineArtIdentifier {
        case "Bunny": return tr("line-art.bunny")
        case "Car": return tr("line-art.car")
        case "Fish": return tr("line-art.fish")
        case "Flower": return tr("line-art.flower")
        case "House": return tr("line-art.house")
        case "Rocket": return tr("line-art.rocket")
        case "Cupcake": return tr("line-art.cupcake")
        case "Dino": return tr("line-art.dino")
        default: return lineArtIdentifier
        }
    }
}
