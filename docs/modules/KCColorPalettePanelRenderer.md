# KCColorPalettePanelRenderer

App 层颜色面板 UIKit 渲染器：承接颜色面板的视图创建、色盘网格、最近色横向行、24/36 分段样式和当前色高亮。位于 `KidCanvas/Features/ContentPicker/KCColorPalettePanelRenderer.swift`，不是独立 SPM target。

## 1. 职责

- 创建颜色面板的标题、24/36 分段容器、色盘网格、自定义颜色按钮和最近色横向滚动行。
- 渲染当前色盘的颜色按钮，维护按钮尺寸、圆角、边框、无障碍标识和网格约束；色盘按钮网格由主控制器在首帧后第一批 staged task 加载，避免启动前创建 24 个颜色按钮。
- 渲染最近色按钮，保持最多 8 个最近色的横向展示入口。
- 统一更新 24/36 分段按钮的选中态样式；分段容器、自定义颜色按钮和选中态颜色复用 `KCEditorVisualStyle`。
- 根据当前颜色在色盘按钮和最近色按钮中应用高亮边框。

## 2. 边界

- 只负责 UIKit 表现层，不持有 `KCContentPickerFeature` 状态。
- 不读写 `UserDefaults`，最近色加载、去重、裁剪和持久化仍由 `KCContentPickerFeature` 负责。
- 不决定当前画布颜色，不调用 `KCDrawingCanvasView`。
- 不展示 `UIColorPickerViewController`；自定义颜色 popover 的锚点仍由 `KCMainViewController.customColorButton` 协调。
- 不负责贴纸分类、线稿、历史、保存或草稿流程。
- 不重复定义通用按钮背景、文字色或分段选中强调色。

## 3. 当前接入

- `KCMainViewController.colorPaletteRenderer` 持有渲染器实例。
- `buildColorsPanel(_:)` 委托 `renderPanel(...)` 创建颜色面板主要 UIKit 结构，并保存返回的按钮、网格高度约束和最近色行引用。
- `reloadPaletteGrid()` 委托 `reloadPaletteGrid(...)` 刷新当前 24/36 色盘按钮；启动路径必须通过 `scheduleStartupDeferredWorkIfNeeded()` 分批调度，并由 `loadColorControlsAfterStartupIfNeeded()` 延后第一次调用。
- `reloadRecentColorRow()` 委托 `reloadRecentColorRow(...)` 刷新最近色按钮；最近色读取完成前保持空行，首帧后再补齐。
- `updatePaletteButtons()` 委托 `updateSegmentButtons(...)` 应用 24/36 分段选中态。
- `selectColor(_:sender:)` 委托 `applyActiveColor(...)` 执行当前色高亮匹配。

## 4. 验收规则

- 不允许在 `KCMainViewController` 重新直接写色盘按钮、最近色按钮、自定义颜色按钮或分段按钮的样式细节。
- 不允许在 Renderer 内新增最近色持久化、色盘来源或 UserDefaults key。
- 24/36 色盘切换、自定义颜色 popover 锚点、当前色高亮和最近色横向滚动必须保持一致。
- `viewDidLoad` 不允许直接构建色盘按钮网格；首帧前颜色面板只保留结构和高度，颜色按钮由 deferred loader 补齐。
- iPhone 与 iPad build 必须通过。
