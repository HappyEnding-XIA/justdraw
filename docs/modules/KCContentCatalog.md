# KCContentCatalog

内置内容目录：色盘、贴纸分组、线稿模板的**单一事实来源**。位于 `Packages/KidCanvasModules/Sources/KCContentCatalog`，依赖 `KCCommon`（`KCHexColor`）与 `KCDomain`（`KCContentPalette` / `KCStickerGroup` / `KCLineArtTemplate` / `KCPaletteSize`）。模块本身无 UIKit。

## 1. 内容资源格式

贴纸分组与线稿模板的元数据外置为 package resource `Resources/content.json`：

```json
{
  "stickerGroups": [
    { "id": "animals", "title": "Animals", "symbols": ["butterfly.fill", ...] }
  ],
  "lineArtTemplates": [
    { "id": "bunny", "title": "Bunny", "category": "Animals" }
  ]
}
```

- 字段：`KCStickerGroup { id, title, symbols[] }`、`KCLineArtTemplate { id, title, category }`（类型定义在 `KCDomain/KCContentTypes.swift`）。
- 解析：`KCContentCatalogDefaults.decodedContent(from:)` 用 `Codable` 解码；JSON 缺失、为空或损坏时回退到逐字一致的硬编码 `Fallback`，保证内容永不缺失。
- `Package.swift` 用 `.process("Resources")`（非 `.copy`）—— 外置盘 + Xcode 16 下 `.copy` 会触发 CodeSign `bundle format unrecognized`。

调色板（24/36 色）目前仍以 `KCHexColor` 内置在 `KCContentCatalogDefaults.palette24/palette36`，**尚未**外置为 JSON（迁移中间态）。

## 2. 对外 API

- `KCContentCatalogDefaults.palette24` / `.palette36`：`[KCHexColor]`，按显示顺序。
- `KCContentCatalogDefaults.stickerGroups`：`[KCStickerGroup]`，从 JSON 加载。
- `KCContentCatalogDefaults.lineArtTemplates`：`[KCLineArtTemplate]`，从 JSON 加载。
- `KCContentCatalogDefaults.decodedContent(from:)`：JSON 解码 + 回退，供加载与测试复用。
- `KCBundledContentCatalog`：Sendable 打包视图，一次性暴露 `standardPalette` / `extendedPalette` / `stickerGroups` / `lineArtTemplates`，并提供 `palette(for: KCPaletteSize)`。

## 3. App 接入路径

1. **装配**：`KidCanvas/KCAppCompositionRoot.swift` 在 `init()` 中构造 `KCBundledContentCatalog()`，与 `KCSessionService` 一并作为 App 级依赖。
2. **注入**：`makeMainViewController()` 以 `KCMainViewController(sessionService:contentCatalog:)` 构造注入；控制器持有 `let contentCatalog: KCBundledContentCatalog`。
3. **消费**（`KidCanvas/KCMainViewController.swift` `viewDidLoad`）：
   - 色盘：`contentCatalog.palette(for: .standard/.extended).colors.map { UIColor(kcHex: $0) }`。`UIColor(kcHex:)` 是 App 层胶水扩展（KCCommon 无 UIKit），用归一化分量无损还原 `KCHexColor → UIColor`。
   - 贴纸分类：`stickerCategories = stickerGroups.map(\.title)`；`stickerSymbolsByCategory = Dictionary(uniqueKeysWithValues: stickerGroups.map { ($0.title, $0.symbols) })`（要求 group title 唯一，由测试守护）。
   - 线稿：`makeLineArtItems()` 按 `contentCatalog.lineArtTemplates` 的顺序与 `template.title` 产出；程序化绘制闭包按 `id` 收录在控制器内，命中则注入。

## 4. 边界与遗留

- **线稿绘制闭包留在 App 层**：`KCLineArtTemplate` 只描述元数据；实际的程序化 `UIBezierPath` 绘制（UIKit/Core Graphics）仍在 `KCMainViewController.makeLineArtItems()` 内，通过 catalog id → 绘制闭包的局部映射衔接。后续若把绘制迁入 engine，需先补视觉/像素回归。
- **调色板尚未 JSON 化**：见 §1，作为后续任务。
- 控制器不得再硬编码贴纸分组 / 线稿元数据 / 色盘取值，`scripts/validate_project.py` 有正向（消费 catalog）与禁止（硬编码回退）校验守护。
