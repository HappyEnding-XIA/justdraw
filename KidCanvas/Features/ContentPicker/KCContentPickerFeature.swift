//
//  KCContentPickerFeature.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/02.
//

import UIKit
import CoreGraphics
import KCDomain
import KCCommon
import KCContentCatalog

/// App 层内容选择 Feature：集中持有色盘、最近色、贴纸分类选择的状态与决策，
/// 是从 `KCMainViewController` 抽出的内容选择边界（T022）。
///
/// 纯几何/纯字符串/纯队列逻辑委托给 KCDomain（`KCContentPickerLayout`、
/// `KCStickerCategoryMapping`、`KCRecentColorQueue`），便于 `swift test` 单测；
/// 本类型只承担与 UIKit/`UIColor`/`UserDefaults` 相关的状态持有与胶水。
/// UIKit 的按钮创建、约束、事件回调仍留在控制器；线稿列表（绘制闭包与画布耦合）
/// 暂不纳入本 Feature，留待画布核心迁移时一并处理。
final class KCContentPickerFeature {

    // MARK: 色盘（颜色取自 contentCatalog，经 UIColor(kcHex:) 无损转换）

    /// 默认 24 色色盘。
    let palette24: [UIColor]
    /// 扩展 36 色色盘。
    let palette36: [UIColor]
    /// 是否当前展示 36 色色盘。
    private(set) var showing36Palette: Bool = false
    /// 当前生效的色盘（按 `showing36Palette` 选择）。
    var currentPalette: [UIColor] {
        showing36Palette ? palette36 : palette24
    }
    /// 网格布局尺寸模型。
    let layout: KCContentPickerLayout

    // MARK: 最近色（UserDefaults 持久化）

    /// 最近使用的颜色（最新在前，最多 8 个）。
    private(set) var recentColors: [UIColor] = []
    /// UserDefaults 存储键，与 Objective-C 原型保持一致以兼容已存数据。
    static let recentColorsKey = "KDRecentColors"

    // MARK: 贴纸分类（分组与符号取自 contentCatalog）

    /// 贴纸分类标题顺序。
    let stickerCategories: [String]
    /// 分类标题 → 该分类下的 SF Symbol 列表。
    let stickerSymbolsByCategory: [String: [String]]
    /// 当前选中的贴纸分类标题。
    private(set) var selectedStickerCategory: String

    /// 由内容目录构造。`layout` 默认使用原型的色盘网格常量。
    init(contentCatalog: KCBundledContentCatalog, layout: KCContentPickerLayout = KCContentPickerLayout()) {
        self.palette24 = contentCatalog.palette(for: .standard).colors.map { UIColor(kcHex: $0) }
        self.palette36 = contentCatalog.palette(for: .extended).colors.map { UIColor(kcHex: $0) }
        self.layout = layout
        let groups = contentCatalog.stickerGroups
        self.stickerCategories = groups.map(\.title)
        self.stickerSymbolsByCategory = Dictionary(
            uniqueKeysWithValues: groups.map { ($0.title, $0.symbols) }
        )
        self.selectedStickerCategory = self.stickerCategories.first ?? ""
    }

    // MARK: 色盘切换

    /// 设置是否展示 36 色色盘。
    func setShowing36Palette(_ value: Bool) {
        showing36Palette = value
    }

    // MARK: 色盘网格布局便捷访问（委托 layout）

    var paletteGridColumns: Int { layout.columns }
    var paletteColorButtonSize: CGFloat { layout.buttonSize }
    var paletteColorButtonSpacing: CGFloat { layout.spacing }
    var paletteGridWidth: CGFloat { layout.gridWidth }
    func paletteGridHeight(forColorCount colorCount: Int) -> CGFloat {
        layout.gridHeight(forColorCount: colorCount)
    }

    // MARK: 最近色

    /// 从 `UserDefaults` 载入最近色（覆盖当前 `recentColors`），与原型 `loadRecentColors` 一致。
    func loadRecentColors() {
        let storedColors = UserDefaults.standard.array(forKey: Self.recentColorsKey) as? [[String: Any]] ?? []
        var colors: [UIColor] = []
        for components in storedColors {
            guard let red = components["r"] as? Double,
                  let green = components["g"] as? Double,
                  let blue = components["b"] as? Double,
                  let alpha = components["a"] as? Double else {
                continue
            }
            colors.append(UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha)))
        }
        recentColors = colors
    }

    /// 把 `color` 记入最近色：先移除已存在的近似色，再插到队首，再裁剪到 8 个，
    /// 并持久化。`color` 为 `nil` 时忽略（对应原型早返回）。
    func addRecentColor(_ color: UIColor?) {
        recentColors = KCRecentColorQueue.inserting(
            color, into: recentColors, areEqual: KCContentPickerFeature.colorsMatch
        )
        persistRecentColors()
    }

    /// 把当前 `recentColors` 写回 `UserDefaults`，与原型 `persistRecentColors` 一致。
    func persistRecentColors() {
        var storedColors: [[String: Any]] = []
        storedColors.reserveCapacity(recentColors.count)
        for color in recentColors {
            var red: CGFloat = 0.0
            var green: CGFloat = 0.0
            var blue: CGFloat = 0.0
            var alpha: CGFloat = 0.0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
                continue
            }
            storedColors.append(["r": Double(red), "g": Double(green), "b": Double(blue), "a": Double(alpha)])
        }
        UserDefaults.standard.set(storedColors, forKey: Self.recentColorsKey)
    }

    /// 两个 `UIColor` 是否在 0.01 容差内逐分量相等；任一为 `nil` 或无法取分量时回退到 `==`。
    /// 从原型 `color(_:matchesColor:)` 原样提取，供最近色去重与色板高亮复用。
    static func colorsMatch(_ lhs: UIColor?, _ rhs: UIColor?) -> Bool {
        guard let lhs, let rhs else { return false }
        var lhsRed: CGFloat = 0.0, lhsGreen: CGFloat = 0.0, lhsBlue: CGFloat = 0.0, lhsAlpha: CGFloat = 0.0
        var rhsRed: CGFloat = 0.0, rhsGreen: CGFloat = 0.0, rhsBlue: CGFloat = 0.0, rhsAlpha: CGFloat = 0.0
        if !lhs.getRed(&lhsRed, green: &lhsGreen, blue: &lhsBlue, alpha: &lhsAlpha) { return lhs == rhs }
        if !rhs.getRed(&rhsRed, green: &rhsGreen, blue: &rhsBlue, alpha: &rhsAlpha) { return lhs == rhs }
        let tolerance: CGFloat = 0.01
        return abs(lhsRed - rhsRed) < tolerance &&
            abs(lhsGreen - rhsGreen) < tolerance &&
            abs(lhsBlue - rhsBlue) < tolerance &&
            abs(lhsAlpha - rhsAlpha) < tolerance
    }

    // MARK: 贴纸分类

    /// 当前选中分类下的 SF Symbol 列表。
    func currentStickerSymbols() -> [String] {
        stickerSymbolsByCategory[selectedStickerCategory] ?? (stickerSymbolsByCategory[stickerCategories.first ?? ""] ?? [])
    }

    /// 切换贴纸分类；未知分类忽略。
    func selectStickerCategory(_ category: String) {
        if stickerCategories.contains(category) {
            selectedStickerCategory = category
        }
    }

    /// 分类标题 → 分类按钮图标 SF Symbol（委托 `KCStickerCategoryMapping`）。
    func categorySymbol(forCategory category: String) -> String {
        KCStickerCategoryMapping.categorySymbol(forCategory: category)
    }

    /// 贴纸符号 → 无障碍标签（委托 `KCStickerCategoryMapping`）。
    func accessibilityLabel(forSymbol symbol: String) -> String {
        KCStickerCategoryMapping.accessibilityLabel(forSymbol: symbol)
    }

    /// 按钮 accessibility identifier → 分类标题（委托 `KCStickerCategoryMapping`）。
    func category(forButtonIdentifier identifier: String) -> String? {
        KCStickerCategoryMapping.category(forIdentifier: identifier, inCategories: stickerCategories)
    }
}
