# KCLineArtFeature

App 层线稿 Feature：承接线稿列表组装、缩略图渲染和画布线稿图片渲染。位于 `KidCanvas/Features/LineArt/KCLineArtFeature.swift`，不是独立 SPM target。

## 1. 职责

- 按 `KCContentCatalog` 的 `lineArtTemplates` 顺序生成 `KCLineArtItem`。
- 通过 `KCDrawingEngineProviding.lineArtDrawingBlock(templateId:stroke:)` 获取线稿几何绘制能力。
- 为线稿选择面板生成缩略图，并在 Feature 内用 `NSCache` 复用已渲染缩略图。
- 为画布生成指定尺寸的线稿底图，并允许调用方传入可见绘图区，让线稿避开浮动工具栏。
- 画布尺寸线稿底图可能较大，必须由控制器放到专用后台队列渲染；主线程只负责读取布局、应用最终图片和刷新 UI。

## 2. 边界

- `KCContentCatalog` 只负责线稿 id、标题、分类和展示顺序。
- `KCDrawingEngine.KCLineArtDrawing` 只负责 UIKit 无关的 `CGPath` 几何。
- `KCDrawingEngineAdapter` 负责 `CGPath -> UIBezierPath` 的 App 层桥接。
- `KCLineArtFeature` 负责把内容元数据、绘制能力和 UIKit 图片渲染编排起来。
- 缩略图缓存只缓存选择面板预览图，不缓存画布尺寸线稿底图；画布底图仍按当前画布尺寸和可见绘图区实时生成，但不能阻塞主线程。
- `KCLineArtPickerViewController` 负责线稿弹窗展示和预览按钮点击回调。
- `KCMainViewController` 只保留弹窗呈现、popover 锚点、可见绘图区计算、异步渲染调度和替换画布的页面协调。

## 3. 当前接入

- `KCMainViewController` 持有 `private(set) lazy var lineArtFeature: KCLineArtFeature`。
- `KCMainViewController.currentLineArtItems()` 首次打开线稿面板时才调用 `lineArtFeature.makeLineArtItems()`，随后复用内存缓存；启动首帧前不构造线稿列表。
- `KCLineArtPickerViewController` 的线稿按钮缩略图通过 `lineArtFeature.thumbnailImage(for:)` 获取；重复打开弹窗时优先命中 Feature 层缓存，避免重复同步渲染所有缩略图。
- 加载线稿时，`KCMainViewController` 先在主线程读取 `canvasSize` 与 `drawingRect`，再通过 `lineArtRenderingQueue` 调用 `lineArtFeature.lineArtImage(for:canvasSize:drawingRect:)` 生成画布图片，完成后回主线程交给 `KCDrawingCanvasView.loadLineArtImage(_:)`。
- `lineArtLoadGeneration` 用于取消过期线稿渲染；如果用户在渲染期间编辑画布或发起新的线稿加载，旧结果不得覆盖当前画布。

## 4. 验收规则

- 控制器只能在 `currentLineArtItems()` 懒加载入口中调用 `makeLineArtItems()`；不得在 `viewDidLoad` 启动路径构造线稿列表。
- 控制器不得重新出现 `thumbnailImageForLineArtItem()`、`lineArtStrokeScale` 或线稿专用 `strokePath`。
- `KCLineArtFeature.thumbnailImage(for:)` 必须先查 `thumbnailCache.object(forKey:)`，miss 后再调用私有渲染方法并 `setObject`。
- 线稿画布渲染必须支持 `drawingRect`，展开态优先按可见绘图区居中；无法计算可见区域时保留旧的全画布 inset fallback。
- 线稿画布渲染不得在主线程同步生成整张底图；必须保留 `lineArtRenderingQueue`、`lineArtLoadGeneration` 和主线程应用结果的边界。
- `scripts/validate_project.py` 必须校验 `KCLineArtFeature.swift` 已加入 App target Sources。
- iPhone 与 iPad 构建、运行时烟测都必须通过。
