# KCEditorPanelsFeature

App 层编辑器面板 Feature：集中浮动工具面板收起/展开状态和折叠态工具芯片色块决策。位于 `KidCanvas/Features/Editor/KCEditorPanelsFeature.swift`，不是独立 SPM target。

## 1. 职责

- 持有 `panelsCollapsed`，记录当前工具面板是否处于收起态。
- 通过 `toggleCollapsed()` 翻转收起状态，并返回 `KCDomain.KCEditorPanelsCollapseState` 决策模型。
- 根据当前工具模式和颜色输出折叠态工具芯片色块。
- 作为 `KCMainViewController` 与 KCDomain 折叠状态纯逻辑之间的 App 层胶水。
- `KCEditorUIFactory` 负责通用编辑器控件的 SF Symbol 图标缓存，避免顶部按钮、底部画笔卡片、折叠按钮反复创建相同配置图片。
- `KCBrushStickerPanelView` 负责右侧印章分类图标的轻量缓存，避免面板重建时重复创建分类 SF Symbol。

## 2. 边界

- 不创建浮动面板、不安装约束、不执行折叠动画。
- 不直接读写 `UIView.isHidden`、`alpha`、`isUserInteractionEnabled`；这些仍由主控制器应用。
- 不决定工具标题，标题由 `KCToolStateChipTitle` / drawing adapter 路径提供。
- 不负责颜色面板、贴纸面板、历史面板、保存、草稿或画布绘制。
- 尺寸滑杆属于主控制器的 UIKit 事件协调；拖动过程只能调度偏好保存，不能在每次 `valueChanged` 中直接写 `UserDefaults`。
- 图标缓存只能缓存纯 SF Symbol 图片或已配置图片，不持有业务状态、画布状态或用户作品数据。

## 3. 对外 API / 接入路径

- `panelsCollapsed`：当前收起状态，只读暴露。
- `collapseState`：当前收起状态对应的纯决策模型。
- `toggleCollapsed()`：切换收起状态并返回新的 `KCEditorPanelsCollapseState`。
- `chipSwatchColor(toolMode:currentColor:)`：为折叠态工具芯片输出色块颜色。
- 当前接入：`KCMainViewController.editorPanels` 持有实例；`togglePanelsCollapsed(_:)`、`applyPanelsCollapsedAnimated` 和 `refreshToolStateChip` 通过它读取状态和色块。
- 尺寸滑杆接入：`didChangeSizeSlider(_:)` 更新画布宽度和预览后调用 `scheduleBrushWidthPreferenceSave()`；拖动结束、场景退后台或控制器释放时调用 `flushBrushWidthPreferenceSave()` 兜底落盘。
- 图标接入：`KCEditorUIFactory.cachedSystemImage(symbolName:)` 为印章列表、折叠按钮和通用按钮提供安全的系统图标复用；`KCBrushStickerPanelView` 自身缓存 15pt bold 分类图标。

## 4. 禁止回流规则

- 禁止把浮动面板创建、约束、动画细节回流到 `KCEditorPanelsFeature`。
- 禁止把画布工具切换、颜色选择、贴纸选择等业务事件下沉到该 Feature。
- 禁止在主控制器重新维护第二套 `panelsCollapsed` 决策规则；收起/展开纯状态以本 Feature 和 KCDomain 为准。
- 禁止让该 Feature 直接依赖会话存储、相册或绘图引擎实现。
- 禁止在尺寸滑杆连续变化路径里同步写偏好；任何恢复直接写入的改动都必须先证明不会造成滑动卡顿。
- 禁止在面板 reload 或印章列表刷新路径里恢复裸 `UIImage(systemName:)` 重复生成；新增图标入口必须优先复用现有缓存工具。
