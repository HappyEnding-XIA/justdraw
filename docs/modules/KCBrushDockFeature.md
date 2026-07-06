# KCBrushDockFeature

App 层画笔 Dock Feature：集中底部画笔项配置，包括画笔 id、`KDBrushStyle`、`KDToolMode`、SF Symbol、强调色和本地化标题。位于 `KidCanvas/KCBrushDockFeature.swift`，不是独立 SPM target。

## 1. 职责

- 提供底部 Dock 当前支持的画笔项列表：铅笔、钢笔、蜡笔。
- 统一维护画笔卡片强调色，按 `KDBrushStyle` 匹配，不依赖展示文案。
- 判断 Dock 按钮是否匹配当前工具 / 当前画笔，并统一应用选中态样式。
- 输出 `KCBrushDockItem` DTO，供 `KCMainViewController` 创建按钮、设置无障碍标识和绑定事件。

## 2. 边界

- 只负责配置数据和 Dock 选中态外观，不创建 UIKit 控件，不注册 target/action。
- 不负责 Dock 尺寸和卡片样式；尺寸由 `KCDeviceLayoutMetrics` 提供，控件样式由 `KCEditorUIFactory` 创建。
- 不负责画布绘制行为；按钮点击后仍由 `KCMainViewController.didTapBrushButton(_:)` 协调工具状态和画布状态。

## 3. 当前接入

- `KCMainViewController.brushDockFeature` 持有 `KCBrushDockFeature` 实例。
- `buildBottomDock(_:)` 通过 `brushDockFeature.brushItems()` 获取画笔配置，再交给 `toolCardButtonWithSymbolName(...)` 创建卡片按钮。
- `refreshBrushDockSelection()` 委托 `brushDockFeature.isButton(...)` 和 `applySelectionAppearance(...)` 处理选中态判断与外观。
- `scripts/validate_project.py` 校验新文件已进入 App target Sources，并防止画笔 tuple 配置、`brushColor` 决策和 Dock 选中态样式回流主控制器。

## 4. 验收规则

- 底部画笔项新增或调整时，优先修改 `KCBrushDockFeature`。
- 不允许在 `KCMainViewController.buildBottomDock(_:)` 重新硬编码画笔 tuple 数组。
- 不允许在 `KCMainViewController.refreshBrushDockSelection()` 直接硬编码 Dock 选中态颜色、边框、阴影和缩放。
- iPhone 与 iPad build、runtime smoke 必须通过。
