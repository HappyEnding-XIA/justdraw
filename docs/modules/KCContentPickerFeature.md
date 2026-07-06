# KCContentPickerFeature

App 层内容选择 Feature：集中持有色盘、最近色和贴纸分类的状态与决策。位于 `KidCanvas/KCContentPickerFeature.swift`，不是独立 SPM target。

## 1. 职责

- 从注入的 `KCBundledContentCatalog` 构造 24 色和 36 色 `UIColor` 色盘。
- 维护当前展示 24 色或 36 色的状态。
- 从 `UserDefaults` 读取、去重、裁剪并持久化最近色，存储键保持 `KDRecentColors`。
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
- `viewDidLoad()` 调用 `contentPicker.loadRecentColors()`，保持原有最近色数据兼容。
- `currentPalette()`、`paletteGridColumns()`、`paletteColorButtonSize()` 等主控制器方法保留为薄转发，供布局与 Renderer 使用。
- `KCColorPalettePanelRenderer` 消费 `contentPicker.currentPalette`、`contentPicker.recentColors` 和布局指标生成颜色面板 UI。
- 贴纸面板通过 `currentStickerSymbols()`、`selectStickerCategory(_:)` 和无障碍标签方法读取分类状态。

## 4. 禁止回流规则

- 色盘内容必须来自 `KCContentCatalog`，不得在主控制器或 Renderer 中重新硬编码。
- 最近色持久化必须继续使用 `KDRecentColors`，不得迁移 key 或改变数据格式。
- UIKit 渲染逻辑不得回流到 `KCContentPickerFeature`。
- iPhone 与 iPad build、`swift test` 和 validator 必须通过。
