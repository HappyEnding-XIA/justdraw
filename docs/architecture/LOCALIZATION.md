# 本地化（Localization）

> 配套任务：T025（多语言基础）/ T026（工具文案中文化）。默认中文、支持英文。

## 语言策略

- **默认语言：简体中文（`zh-Hans`）**。工程的 `developmentRegion = zh-Hans`，
  `Info.plist` 的 `CFBundleDevelopmentRegion` 经 `$(DEVELOPMENT_LANGUAGE)` 解析为 `zh-Hans`。
  非中文/非英文环境回退到默认语言（中文）。
- **备用语言：英文（`en`）**。设备语言为英文时展示英文。
- `knownRegions = (zh-Hans, en, Base)`，两种语言均作为正式本地化资源存在。

## 资源位置

App target（`KidCanvas/`）内以 `.lproj` 变体组承载本地化资源：

| 文件 | zh-Hans | en | 说明 |
|------|---------|----|----|
| `Localizable.strings` | `KidCanvas/zh-Hans.lproj/Localizable.strings` | `KidCanvas/en.lproj/Localizable.strings` | App 用户可见文案（工具菜单、面板标题、画笔名、无障碍标签等） |
| `InfoPlist.strings` | `KidCanvas/zh-Hans.lproj/InfoPlist.strings` | `KidCanvas/en.lproj/InfoPlist.strings` | `Info.plist` key 覆盖（相册权限文案） |

`Info.plist` 的 base 值用中文（与默认语言一致）；`en.lproj/InfoPlist.strings` 覆盖为英文。

## 文案入口（App 层）

`KidCanvas/KCLocalizedStrings.swift` 中的 `KCL10n`：

- `KCL10n.tr(_ key:)`：`NSLocalizedString(key, comment:)` 的薄封装，缺失回退到 key 本身。
- `KCL10n.tr(_ key:, _ args:)`：带位置参数（`%d` / `%@`）。
- 一组类型安全的计算属性 / 便捷方法（如 `KCL10n.colorsPanelTitle`、`KCL10n.pencilTitle`、
  `KCL10n.paletteColorTitle(_ index:)`），集中所有 key，避免在控制器里散落字符串字面量。

> 不引入第三方本地化库；统一走 `NSLocalizedString` + `KCL10n`。

## KCDomain 与本地化

`KCDomain`（SPM，无 UIKit）中的纯展示型 helper 只返回**稳定的本地化 key（ASCII）**，
不直接调用 `NSLocalizedString`（避免 bundle 依赖、保持可单测）：

| KCDomain helper | 返回 | App 层解析 |
|-----------------|------|-----------|
| `KCToolStateChipTitle.title(tool:brush:)` | `chip.title.*` key | `KCL10n.tr(...)` / 经 `KCDrawingEngineAdapter` |
| `KCStickerCategoryMapping.accessibilityLabel(forSymbol:)` | `sticker.symbol.*` key | `KCL10n.stickerSymbolAccessibility(...)` |
| `KCHistoryThumbStatus.accessibilityPrefix` | `history.thumb.*` key | `KCL10n.historyThumbPrefix(...)` |

分类标题（Animals/Nature/Decor/Faces）在 `content.json` 中作为**稳定标识**保留英文，
由 `KCL10n.stickerCategoryTitle(_:)` 映射为本地化展示名。

## 命名规范

- key 形式：`<域>.<对象>.<属性>`，如 `toolbar.colors.title`、`brush.pencil.title`、`action.customColor.title`。
- 新增文案流程：① 在 `zh-Hans.lproj/Localizable.strings` 和 `en.lproj/Localizable.strings`
  **同时**加 key；② 在 `KCL10n` 补类型安全入口；③ 在调用处使用 `KCL10n.xxx`。
- 用户可见文案不得硬编码在控制器/Feature 中；中文值只存在于 `.strings`，Swift 源码只引用 key。

## 验证

`scripts/validate_project.py` 的 `localization_checks` 负责：

- zh-Hans / en 的 `Localizable.strings` 与 `InfoPlist.strings` 均存在；
- 两种语言的 `Localizable.strings` key 集合**对齐**（多/缺 key 会失败）；
- `KCLocalizedStrings.swift` 入口存在且走 `NSLocalizedString`；
- 两种语言的 `InfoPlist.strings` 均覆盖相册权限 key；
- 工程 `developmentRegion = zh-Hans`、`knownRegions` 含 zh-Hans + en、`.strings` 经变体组进 Resources。

> T025 起不再「简单禁止 UI 源码中文字符」；改为上述正向本地化检查。Swift 源码不含
> 中文值（中文集中在 `.strings`），由 key 对齐 + 入口检查 + T026 的英文硬编码禁止项共同保证。
