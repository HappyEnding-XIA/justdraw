# KCEditorPanelsFeature

App 层编辑器面板 Feature：集中浮动工具面板收起/展开状态和折叠态工具芯片色块决策。位于 `KidCanvas/KCEditorPanelsFeature.swift`，不是独立 SPM target。

## 1. 职责

- 持有 `panelsCollapsed`，记录当前工具面板是否处于收起态。
- 通过 `toggleCollapsed()` 翻转收起状态，并返回 `KCDomain.KCEditorPanelsCollapseState` 决策模型。
- 根据当前工具模式和颜色输出折叠态工具芯片色块。
- 作为 `KCMainViewController` 与 KCDomain 折叠状态纯逻辑之间的 App 层胶水。

## 2. 边界

- 不创建浮动面板、不安装约束、不执行折叠动画。
- 不直接读写 `UIView.isHidden`、`alpha`、`isUserInteractionEnabled`；这些仍由主控制器应用。
- 不决定工具标题，标题由 `KCToolStateChipTitle` / drawing adapter 路径提供。
- 不负责颜色面板、贴纸面板、历史面板、保存、草稿或画布绘制。

## 3. 对外 API / 接入路径

- `panelsCollapsed`：当前收起状态，只读暴露。
- `collapseState`：当前收起状态对应的纯决策模型。
- `toggleCollapsed()`：切换收起状态并返回新的 `KCEditorPanelsCollapseState`。
- `chipSwatchColor(toolMode:currentColor:)`：为折叠态工具芯片输出色块颜色。
- 当前接入：`KCMainViewController.editorPanels` 持有实例；`togglePanelsCollapsed(_:)`、`applyPanelsCollapsedAnimated` 和 `refreshToolStateChip` 通过它读取状态和色块。

## 4. 禁止回流规则

- 禁止把浮动面板创建、约束、动画细节回流到 `KCEditorPanelsFeature`。
- 禁止把画布工具切换、颜色选择、贴纸选择等业务事件下沉到该 Feature。
- 禁止在主控制器重新维护第二套 `panelsCollapsed` 决策规则；收起/展开纯状态以本 Feature 和 KCDomain 为准。
- 禁止让该 Feature 直接依赖会话存储、相册或绘图引擎实现。
