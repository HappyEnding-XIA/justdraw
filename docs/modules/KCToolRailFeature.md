# KCToolRailFeature

App 层左侧工具栏 Feature：集中左侧工具项配置、取色器强调色和按钮选中态样式。位于 `KidCanvas/KCToolRailFeature.swift`，不是独立 SPM target。

> 产品侧工具名称为“印章 / Stamp”；内部仍沿用 `sticker` id 与 `KDToolMode.sticker` 稳定模型，避免为文案调整引入数据迁移。

## 1. 职责

- 提供左侧工具栏当前支持的工具项列表：画笔、橡皮擦、填色、印章、取色器。
- 统一维护工具项的稳定 id、`KDToolMode`、SF Symbol 和本地化标题。
- 印章工具使用 `seal.fill` 作为入口图标，工具模式仍是 `.sticker`。
- 统一维护取色器按钮的黄色强调色。
- 判断工具按钮是否匹配当前工具模式，并应用选中态 / 未选中态背景、边框和阴影强度；通用颜色、边框与文字颜色 token 复用 `KCEditorVisualStyle`。
- 输出 `KCToolRailItem` DTO，供 `KCMainViewController` 创建按钮、设置无障碍标识和绑定事件。

## 2. 边界

- 只负责工具栏配置数据和按钮状态应用，不创建 UIKit 控件，不注册 target/action。
- 不负责左侧工具栏尺寸、滚动容器和按钮基础样式；尺寸与基础样式仍由 `KCDeviceLayoutMetrics`、`KCEditorUIFactory` 和控制器布局承担。
- 不重复定义选中背景、普通背景或边框 token；这些视觉常量由 `KCEditorVisualStyle` 统一维护。
- 不负责画布工具行为；按钮点击后仍由 `KCMainViewController.didTapToolButton(_:)` / `selectToolMode(_:)` 协调画布状态、尺寸预览、印章编辑按钮和底部画笔 Dock。

## 3. 当前接入

- `KCMainViewController.toolRailFeature` 持有 `KCToolRailFeature` 实例。
- `buildLeftRail(_:)` 通过 `toolRailFeature.toolItems()` 获取工具栏配置，再交给 `railToolButtonWithSymbolName(...)` 创建按钮。
- `selectToolMode(_:)` 委托 `toolRailFeature.isButton(...)` 和 `applySelectionAppearance(...)` 处理工具按钮选中态判断与外观。
- `scripts/validate_project.py` 校验新文件已进入 App target Sources，并防止工具 tuple 配置和工具栏选中态样式回流主控制器；T056/T060 后基础按钮质感和通用视觉 token 来自 `KCEditorUIFactory` / `KCEditorVisualStyle`，本 Feature 只叠加选中态。

## 4. 验收规则

- 左侧工具新增、删除或调整顺序时，优先修改 `KCToolRailFeature.toolItems()`。
- 不允许在 `KCMainViewController.buildLeftRail(_:)` 重新硬编码工具 tuple 数组。
- 不允许在 `KCMainViewController.selectToolMode(_:)` 直接硬编码左侧工具栏选中态颜色、边框、阴影和缩放。
- iPhone 与 iPad build、runtime smoke 必须通过。
