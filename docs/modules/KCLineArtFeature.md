# KCLineArtFeature

App 层线稿 Feature：承接线稿列表组装、缩略图渲染和画布线稿图片渲染。位于 `KidCanvas/Features/LineArt/KCLineArtFeature.swift`，不是独立 SPM target。

## 1. 职责

- 按 `KCContentCatalog` 的 `lineArtTemplates` 顺序生成 `KCLineArtItem`。
- 通过 `KCDrawingEngineProviding.lineArtDrawingBlock(templateId:stroke:)` 获取线稿几何绘制能力。
- 为线稿选择面板生成缩略图。
- 为画布生成指定尺寸的线稿底图，并允许调用方传入可见绘图区，让线稿避开浮动工具栏。

## 2. 边界

- `KCContentCatalog` 只负责线稿 id、标题、分类和展示顺序。
- `KCDrawingEngine.KCLineArtDrawing` 只负责 UIKit 无关的 `CGPath` 几何。
- `KCDrawingEngineAdapter` 负责 `CGPath -> UIBezierPath` 的 App 层桥接。
- `KCLineArtFeature` 负责把内容元数据、绘制能力和 UIKit 图片渲染编排起来。
- `KCLineArtPickerViewController` 负责线稿弹窗展示和预览按钮点击回调。
- `KCMainViewController` 只保留弹窗呈现、popover 锚点、可见绘图区计算和替换画布的页面协调。

## 3. 当前接入

- `KCMainViewController` 持有 `private(set) lazy var lineArtFeature: KCLineArtFeature`。
- `viewDidLoad` 调用 `lineArtFeature.makeLineArtItems()` 初始化线稿列表。
- `KCLineArtPickerViewController` 的线稿按钮缩略图通过 `lineArtFeature.thumbnailImage(for:)` 获取。
- 加载线稿时通过 `lineArtFeature.lineArtImage(for:canvasSize:drawingRect:)` 获取画布图片，`drawingRect` 由 `KCMainViewController.visibleLineArtDrawingRect(forCanvasSize:)` 按当前浮动面板可见区域计算，再交给 `KCDrawingCanvasView.loadLineArtImage(_:)`。

## 4. 验收规则

- 控制器不得重新出现 `makeLineArtItems()`、`thumbnailImageForLineArtItem()`、`lineArtStrokeScale` 或线稿专用 `strokePath`。
- 线稿画布渲染必须支持 `drawingRect`，展开态优先按可见绘图区居中；无法计算可见区域时保留旧的全画布 inset fallback。
- `scripts/validate_project.py` 必须校验 `KCLineArtFeature.swift` 已加入 App target Sources。
- iPhone 与 iPad 构建、运行时烟测都必须通过。
