# KCContentPickerFeature

App 层内容选择 Feature：集中持有色盘、最近色和贴纸分类的状态与决策。位于 `KidCanvas/Features/ContentPicker/KCContentPickerFeature.swift`，不是独立 SPM target。

## 1. 职责

- 从注入的 `KCBundledContentCatalog` 构造 24 色和 36 色 `UIColor` 色盘。
- 维护当前展示 24 色或 36 色的状态。
- 从 `UserDefaults` 读取、去重、裁剪并持久化最近色，存储键保持 `KDRecentColors`；最近色读取由主控制器延后到首帧后触发，避免启动同步读偏好数据。
- 最近色选择后立即更新内存队列和 UI，`UserDefaults` 写入使用 0.35 秒 debounce；场景退后台和控制器释放时必须 flush，避免连续点色阻塞交互或丢失最后一次选择。
- 提供色盘网格的列数、按钮尺寸、间距和高度计算入口，底层委托 `KCDomain.KCContentPickerLayout`。
- 维护贴纸分类顺序、当前选中分类和分类下的 SF Symbol 列表。
- 委托 `KCDomain.KCStickerCategoryMapping` 处理贴纸分类图标、无障碍标签和 identifier 解析。

## 2. 边界

- 不创建 UIKit 控件，不安装约束，不注册 target/action。
- 不负责颜色面板按钮样式；T049 后由 `KCColorPalettePanelRenderer` 负责 UIKit 渲染与高亮。
- 不负责画布当前颜色写入，颜色选择仍由 `KCMainViewController.selectColor(_:sender:)` 协调。
- 不负责自定义颜色选择器展示；`UIColorPickerViewController` 仍由主控制器呈现。
- 不持有线稿弹窗、历史会话、保存或草稿状态。

## 3. 当前接入

- `KCMainViewController.contentPicker` 通过 `contentCatalog` 懒加载构造。
- `KCMainViewController.loadRecentColorsIfNeeded()` 在首帧后的 deferred work 或首次写入最近色前调用 `contentPicker.loadRecentColors()`，保持原有最近色数据兼容且不阻塞首帧。
- `KCMainViewController.sceneWillResignActiveNotification`、`sceneDidEnterBackgroundNotification` 和 `deinit` 调用 `contentPicker.flushRecentColorSave()`，保证延迟写入在生命周期边界落盘。
- `currentPalette()`、`paletteGridColumns()`、`paletteColorButtonSize()` 等主控制器方法保留为薄转发，供布局与 Renderer 使用。
- `KCColorPalettePanelRenderer` 消费 `contentPicker.currentPalette`、`contentPicker.recentColors` 和布局指标生成颜色面板 UI。
- `KCColorPalettePanelRenderer.RenderedPanel` 必须返回色盘 grid 和最近色 row 的强类型引用；主控制器刷新色盘/最近色时使用这些引用，不允许通过 magic tag 在整棵视图树中查找。
- 贴纸面板通过 `currentStickerSymbols()`、`selectStickerCategory(_:)` 和无障碍标签方法读取分类状态。

## 4. 禁止回流规则

- 色盘内容必须来自 `KCContentCatalog`，不得在主控制器或 Renderer 中重新硬编码。
- 最近色持久化必须继续使用 `KDRecentColors`，不得迁移 key 或改变数据格式。
- 不允许在 `addRecentColor(_:)` 中同步写 `UserDefaults`；只能更新内存队列并调度延迟写入，生命周期边界由 `flushRecentColorSave()` 收口。
- 不允许在 `viewDidLoad` 中同步调用 `loadRecentColors()`；启动首帧前只能完成默认颜色选择，最近色按钮由 `loadColorControlsAfterStartupIfNeeded()` 补齐。
- UIKit 渲染逻辑不得回流到 `KCContentPickerFeature`。
- 禁止用 `viewWithTag(...)!` 定位色盘 grid 或最近色 row；颜色面板内部视图必须通过 `RenderedPanel` 显式传回控制器。
- iPhone 与 iPad build、`swift test` 和 validator 必须通过。
