# KCCanvasFeature

App 层主画布 Feature：集中画布视图创建、画布动作状态和 undo / redo / save 动作按钮外观。位于 `KidCanvas/Features/Canvas/KCCanvasFeature.swift`，不是独立 SPM target。

## 1. 职责

- 创建并配置 `KCDrawingCanvasView`，注入 `KCDrawingEngineProviding`。
- 输出 `ActionState`，统一描述 undo、redo、save 是否可用。
- 应用 undo / redo / save 按钮的 enabled、alpha、背景色、边框、阴影和 save 图标 tint；状态视觉复用 `KCEditorVisualStyle.applyActionButtonAvailability(...)`。
- 保存按钮在空画布时只做视觉弱化，不完全禁用，让用户点击后能收到“无法保存”的本地化 Toast。
- 封装画布是否有可保存内容、当前填充色和贴纸 symbol fallback。

## 2. 边界

- 不负责触摸绘制、撤销栈、贴纸手势或 Core Graphics 绘制，这些仍在 `KCDrawingCanvasView` / `KCDrawingEngine`。
- 不负责保存、草稿、历史、相册导入导出流程，这些仍由 `KCMainViewController` 协调。
- 不创建工具栏按钮，只应用动作按钮状态和外观；不重复定义动作按钮颜色或禁用态 token。

## 3. 当前接入

- `KCMainViewController.canvasFeature` 由注入的 `drawingEngine` 构造。
- `buildInterface()` 通过 `canvasFeature.makeCanvasView(delegate:)` 创建画布。
- `refreshActionButtons()` 通过 `canvasFeature.actionState(for:)` 获取状态；控制器会缓存最近一次已应用的 `ActionState`，状态未变化时直接返回，避免画布内容变化期间反复重写 undo / redo / save 的 enabled、alpha、背景色、边框和阴影。
- 当 `ActionState` 变化时，`refreshActionButtons()` 再委托 `applyActionButtonAppearance(...)` 应用按钮外观。
- `scripts/validate_project.py` 校验创建、动作状态和动作按钮外观均委托给 `KCCanvasFeature`，并要求动作按钮复用 `KCEditorVisualStyle` 的共享状态样式；同时守护空画布保存反馈可触发。

## 4. 验收规则

- 不允许在 `KCMainViewController.refreshActionButtons()` 直接写 undo / redo / save 的 enabled 与外观。
- 不允许把真实绘制、保存、草稿或历史流程迁入 `KCCanvasFeature`。
- iPhone 与 iPad build、runtime smoke 必须通过。
