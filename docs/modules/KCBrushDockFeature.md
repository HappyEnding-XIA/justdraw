# KCBrushDockFeature

App 层画笔 Dock Feature：集中底部画笔项配置，包括画笔 id、`KDBrushStyle`、`KDToolMode`、SF Symbol、强调色和本地化标题。位于 `KidCanvas/Features/Tools/KCBrushDockFeature.swift`，不是独立 SPM target。

## 1. 职责

- 提供底部 Dock 当前支持的画笔项列表：铅笔、钢笔、蜡笔。
- 统一维护画笔卡片强调色，按 `KDBrushStyle` 匹配，不依赖展示文案。
- 判断 Dock 按钮是否匹配当前工具 / 当前画笔，并应用选中态背景、边框和阴影；选中态视觉复用 `KCEditorVisualStyle.applySelectableButtonAppearance(...)`，不再通过缩放改变按钮尺寸。
- 输出 `KCBrushDockItem` DTO，供 `KCMainViewController` 创建按钮、设置无障碍标识和绑定事件。

## 2. 边界

- 只负责配置数据和 Dock 选中态应用，不创建 UIKit 控件，不注册 target/action。
- 不负责 Dock 尺寸和卡片样式；尺寸由 `KCDeviceLayoutMetrics` 提供，控件样式由 `KCEditorUIFactory` 创建。
- 不重复定义选中背景、普通背景、边框或阴影 token；这些视觉常量由 `KCEditorVisualStyle` 统一维护。
- 不负责画布绘制行为；按钮点击后仍由 `KCMainViewController.didTapBrushButton(_:)` 协调工具状态和画布状态。

## 3. 当前接入

- `KCMainViewController.brushDockFeature` 持有 `KCBrushDockFeature` 实例。
- `buildBottomDock(_:)` 通过 `brushDockFeature.brushItems()` 获取画笔配置，再交给 `toolCardButtonWithSymbolName(...)` 创建卡片按钮。
- `refreshBrushDockSelection()` 委托 `brushDockFeature.isButton(...)` 和 `applySelectionAppearance(...)` 处理选中态判断与外观，并只对当前活跃按钮执行一次 `scrollRectToVisible`。
- `didTapBrushButton(_:)` 点击画笔样式时必须先更新 `currentBrushStyle`，再统一调用一次 `selectToolMode(.brush)`；不得先按旧样式刷新 Dock，再调用 `selectBrushStyle(_:)` 二次刷新。
- `scripts/validate_project.py` 校验新文件已进入 App target Sources，并防止画笔 tuple 配置、`brushColor` 决策和 Dock 选中态样式回流主控制器；T056/T060/T061 后基础卡片质感和通用状态视觉来自 `KCEditorUIFactory` / `KCEditorVisualStyle`，本 Feature 只负责匹配状态并调用共享样式。

## 4. 验收规则

- 底部画笔项新增或调整时，优先修改 `KCBrushDockFeature`。
- 不允许在 `KCMainViewController.buildBottomDock(_:)` 重新硬编码画笔 tuple 数组。
- 不允许在 `KCMainViewController.refreshBrushDockSelection()` 直接硬编码 Dock 选中态颜色、边框、阴影和缩放。
- 不允许在 `selectToolMode(_:)` 里先调用 `refreshBrushDockSelection()` 再额外调用第二套 Dock 滚动 helper；Dock 滚动只能由活跃按钮选中刷新顺带完成一次。
- 不允许在 `didTapBrushButton(_:)` 对同一次画笔样式点击连续调用 `selectToolMode(.brush)` 和 `selectBrushStyle(_:)`。
- 不允许为 Dock 选中态新增 `CGAffineTransform(scaleX:y:)` 这类会导致布局跳动的缩放。
- iPhone 与 iPad build、runtime smoke 必须通过。
