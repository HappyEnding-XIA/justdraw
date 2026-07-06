# KCBrushStickerPanelView

App 层画笔 / 贴纸 / 橡皮编辑面板组装器：承接尺寸 slider、尺寸预览容器、贴纸分类、贴纸列表、橡皮形状按钮和贴纸编辑按钮的 UIKit 创建与约束。位于 `KidCanvas/KCBrushStickerPanelView.swift`，不是独立 SPM target。

## 1. 职责

- 创建画笔/贴纸面板标题、尺寸 slider、尺寸预览容器和尺寸示意点。
- 创建贴纸分类按钮行，并保持图标优先、中文/英文无障碍文本由外层传入。
- 创建贴纸横向滚动列表，并提供 `reloadStickerButtons(...)` 刷新入口。
- 创建橡皮擦 circle/cloud/star 形状按钮。
- 创建贴纸前置和删除按钮，并提供启用/禁用态样式刷新入口。
- 统一维护贴纸分类选中态的背景色、tint 和边框表现。

## 2. 边界

- 只负责 UIKit 组装和按钮表现，不持有画布状态。
- 不决定当前工具、当前画笔、当前贴纸、橡皮形状或选中贴纸。
- 不处理 target/action 的业务语义；事件 selector 仍由 `KCMainViewController` 提供。
- 不访问 `KCDrawingCanvasView`、会话存储、历史、相册或草稿能力。
- 不改变橡皮擦真实擦除路径、贴纸手势、undo/redo 行为。

## 3. 当前接入

- `KCMainViewController.brushStickerPanelView` 持有组装器实例。
- `buildSizePanel(_:)` 委托 `renderPanel(...)` 创建面板，并保存返回的 slider、预览 layer、贴纸行、橡皮按钮和贴纸编辑按钮引用。
- `reloadStickerButtons()` 委托 `reloadStickerButtons(...)` 重建贴纸按钮列表，主控制器继续负责当前贴纸选择和画布状态协调。
- `refreshStickerCategoryButtons()` 委托 `applyStickerCategorySelection(...)` 应用分类选中态。
- `refreshStickerEditButtons()` 委托 `applyStickerEditButtonsEnabled(...)` 应用贴纸编辑按钮可用态。

## 4. 验收规则

- 不允许在 `KCMainViewController.buildSizePanel(_:)` 重新手写尺寸 slider、贴纸滚动行、橡皮按钮或贴纸编辑按钮组装。
- 不允许把画布状态、选中贴纸状态、undo/redo 或贴纸手势下沉到本组装器。
- 贴纸列表刷新后仍必须由主控制器调用 `selectStickerSymbol(_:)` 完成当前贴纸选择协调。
- iPhone 与 iPad build、`swift test` 和 validator 必须通过。
