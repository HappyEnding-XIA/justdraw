# KCContentCatalog

内置内容目录：色盘、贴纸分组、线稿模板的**单一事实来源**。位于 `Packages/KidCanvasModules/Sources/KCContentCatalog`，依赖 `KCCommon`（`KCHexColor`）与 `KCDomain`（`KCContentPalette` / `KCStickerGroup` / `KCLineArtTemplate` / `KCPaletteSize`）。模块本身无 UIKit。

## 1. 内容资源格式

色盘、贴纸分组与线稿模板的元数据外置为 package resource `Resources/content.json`：

```json
{
  "palettes": [
    { "id": "palette.24", "title": "24 Colors", "colors": ["#F06E73", "..."] }
  ],
  "stickerGroups": [
    { "id": "animals", "title": "Animals", "symbols": ["butterfly.fill", ...] }
  ],
  "lineArtTemplates": [
    { "id": "bunny", "title": "Bunny", "category": "Animals" }
  ]
}
```

- 字段：`KCContentPalette { id, title, colors[] }`、`KCStickerGroup { id, title, symbols[] }`、`KCLineArtTemplate { id, title, category }`（类型定义在 `KCDomain/KCContentTypes.swift`）。
- 解析：`KCContentCatalogDefaults.decodedContent(from:)` 用 `Codable` 解码；JSON 缺失、为空或损坏时回退到逐字一致的硬编码 `Fallback`，保证内容永不缺失。
- 色盘校验：`palette.24` 必须包含 24 色，`palette.36` 必须包含 36 色，且扩展色盘前 24 色必须与标准色盘一致，避免 UI 顺序悄悄漂移。
- `Package.swift` 用 `.process("Resources")`（非 `.copy`）—— 外置盘 + Xcode 16 下 `.copy` 会触发 CodeSign `bundle format unrecognized`。

## 2. 对外 API

- `KCContentCatalogDefaults.palette24` / `.palette36`：`[KCHexColor]`，从 JSON 加载并按显示顺序返回。
- `KCContentCatalogDefaults.stickerGroups`：`[KCStickerGroup]`，从 JSON 加载。
- `KCContentCatalogDefaults.lineArtTemplates`：`[KCLineArtTemplate]`，从 JSON 加载。
- `KCContentCatalogDefaults.decodedContent(from:)`：JSON 解码 + 回退，供加载与测试复用。
- `KCBundledContentCatalog`：Sendable 打包视图，一次性暴露 `standardPalette` / `extendedPalette` / `stickerGroups` / `lineArtTemplates`，并提供 `palette(for: KCPaletteSize)`。

## 3. App 接入路径

1. **装配**：`KidCanvas/App/KCAppCompositionRoot.swift` 在 `init()` 中构造 `KCBundledContentCatalog()`，与 `KCSessionService`、`KCDrawingEngineProviding` 一并作为 App 级依赖。
2. **注入**：`makeMainViewController()` 以 `KCMainViewController(sessionService:contentCatalog:drawingEngine:)` 构造注入；控制器持有 `let contentCatalog: KCBundledContentCatalog`。
3. **消费**（`KidCanvas/Features/Editor/KCMainViewController.swift` `viewDidLoad`）：
   - 色盘：`KCContentPickerFeature` 在构造时调用 `contentCatalog.palette(for: .standard/.extended).colors.map { UIColor(kcHex: $0) }`。`UIColor(kcHex:)` 是 App 层胶水扩展（KCCommon 无 UIKit），用归一化分量无损还原 `KCHexColor → UIColor`。T049 后，色盘 UIKit 按钮、最近色横向行和当前色高亮由 `KCColorPalettePanelRenderer` 渲染，内容来源仍保持 `KCContentCatalog → KCContentPickerFeature → Renderer` 的单向链路。
   - 贴纸分类：`stickerCategories = stickerGroups.map(\.title)`；`stickerSymbolsByCategory = Dictionary(uniqueKeysWithValues: stickerGroups.map { ($0.title, $0.symbols) })`（要求 group title 唯一，由测试守护）。
   - 线稿：`KCLineArtFeature.makeLineArtItems()` 按 `contentCatalog.lineArtTemplates` 的顺序与 `template.title` 产出；程序化绘制几何由 `KCDrawingEngine.KCLineArtDrawing` 按 id 提供。

## 4. 边界与遗留

- **线稿元数据与几何分离**：`KCLineArtTemplate` 只描述元数据；实际程序化几何在 `KCDrawingEngine.KCLineArtDrawing` 内生成 `CGPath` 指令，App adapter 只做 `UIBezierPath` 包装与描边转发。
- **硬编码 fallback 只作兜底**：色盘、贴纸、线稿的主路径均来自 `Resources/content.json`；`Fallback` 只在资源缺失、为空或解码失败时使用。
- 控制器不得再硬编码贴纸分组 / 线稿元数据 / 色盘取值，`scripts/validate_project.py` 有正向（消费 catalog）与禁止（硬编码回退）校验守护。
