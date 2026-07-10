# KCBrushStickerPanelView

App 层画笔 / 印章 / 橡皮编辑面板组装器：承接尺寸 slider、实时尺寸预览容器、印章分类、印章列表、橡皮形状按钮和印章编辑按钮的 UIKit 创建与约束。位于 `KidCanvas/Features/Tools/KCBrushStickerPanelView.swift`，不是独立 SPM target。

> 文件名与内部 API 暂保留 `Sticker`，对应现有 `KDToolMode.sticker`、`KCSticker*` 与内容目录 schema；用户可见文案统一展示为“印章 / Stamp”。

## 1. 职责

- 创建画笔/印章面板标题、尺寸 slider 和实时尺寸预览容器；尺寸控制采用横向紧凑布局，避免旧版纵向提示块占据过多右侧面板空间。
- 创建印章分类按钮行，并保持图标优先、中文/英文无障碍文本由外层传入。
- 创建印章横向滚动列表，并提供 `reloadStickerButtons(...)` 刷新入口。
- 创建橡皮擦 circle/cloud/star 形状按钮。
- 创建印章前置和删除按钮，并提供启用/禁用态样式刷新入口。
- 统一维护印章分类、印章素材按钮、印章编辑按钮的背景色、tint、边框、阴影、选中态和禁用态表现，并复用 `KCEditorVisualStyle` 的 App 级状态视觉 helper。

## 2. 边界

- 只负责 UIKit 组装和按钮表现，不持有画布状态。
- 不决定当前工具、当前画笔、当前印章、橡皮形状或选中印章。
- 不处理 target/action 的业务语义；事件 selector 仍由 `KCMainViewController` 提供。
- 不访问 `KCDrawingCanvasView`、会话存储、历史、相册或草稿能力。
- 不改变橡皮擦真实擦除路径、印章拖动/捏合/旋转手势、undo/redo 行为。

## 3. 当前接入

- `KCMainViewController.brushStickerPanelView` 持有组装器实例。
- `buildSizePanel(_:)` 委托 `renderPanel(...)` 创建面板，并保存返回的 slider、预览 layer、印章行、橡皮按钮和印章编辑按钮引用。
- `viewDidLoad` 只建立印章分类和默认 `currentStickerSymbol`，不立即重建印章素材按钮；`scheduleStartupDeferredWorkIfNeeded()` 把 `loadStickerButtonsAfterStartupIfNeeded()` 放到首帧后较晚批次执行（当前 `KCStartupDeferredDelay.stickerButtons = 0.48`），再由 `reloadStickerButtons()` 委托 `reloadStickerButtons(...)` 重建印章按钮列表，避免色盘、历史、草稿和印章同时抢主线程。主控制器继续负责当前印章选择和画布状态协调。
- `refreshStickerCategoryButtons()` 委托 `applyStickerCategorySelection(...)` 应用分类选中态。
- `selectStickerSymbol(_:)` 委托 `applyStickerSymbolSelection(...)` 应用印章素材按钮选中态，避免主控制器硬编码按钮颜色或缩放。
- `refreshStickerEditButtons()` 委托 `applyStickerEditButtonsEnabled(...)` 应用印章编辑按钮可用态。
- 切换印章分类时，如果自动选中该分类第一个印章，必须同步进入一次性印章工具；下一次点画布插入该印章后再恢复到进入印章前的常驻工具。
- `applyPillSelectionAppearance(...)` 和 `applyStampButtonAppearance(...)` 作为 T056/T061 视觉精修的本地样式入口，内部复用 `KCEditorVisualStyle.applySelectableButtonAppearance(...)` / `applyActionButtonAvailability(...)`，避免分类/印章/编辑按钮各自散落样式或复制 token。

## 4. 验收规则

- 不允许在 `KCMainViewController.buildSizePanel(_:)` 重新手写尺寸 slider、印章滚动行、橡皮按钮或印章编辑按钮组装。
- 不允许恢复无交互的圆点式尺寸示意；尺寸控制以 slider + 实时预览为主，且预览应与 slider 横向同组展示。若后续要新增常用尺寸快捷档位，必须具备点击、明确选中态，并与 slider、预览和实际尺寸双向同步。
- 不允许把画布状态、选中印章状态、undo/redo 或印章手势下沉到本组装器。
- 不允许新增印章分类/印章列表/编辑按钮样式时绕过本组装器的样式 helper，或在本文件复制一套独立颜色/阴影/禁用态 token。
- 不允许在 `KCMainViewController.selectStickerSymbol(_:)` 重新手写印章素材按钮的背景、边框、阴影或缩放。
- 不允许在 `viewDidLoad` 首帧路径直接调用 `reloadStickerButtons()`；印章素材按钮首轮创建必须推迟到首帧后的短延迟任务（当前由 `KCStartupDeferredDelay.stickerButtons` 统一控制），避免首屏构建同步生成全部印章按钮。
- 印章列表刷新后仍必须由主控制器调用 `selectStickerSymbol(_:)` 完成当前印章选择协调。
- 不允许切换印章分类后只更新 `currentStickerSymbol` 而不更新当前工具状态；用户看到印章被选中时，下一次点画布必须执行插入印章。
- iPhone 与 iPad build、`swift test` 和 validator 必须通过。
