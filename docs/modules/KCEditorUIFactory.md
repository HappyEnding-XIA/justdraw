# KCEditorUIFactory

App 层编辑器 UI 工厂：集中浮动面板、图标按钮、分段按钮、小工具按钮、历史缩略图按钮、画笔卡片等通用 UIKit 控件的样式创建。位于 `KidCanvas/KCEditorUIFactory.swift`，不是独立 SPM target。

## 1. 职责

- 创建通用浮动面板背景与模糊层。
- 创建顶部图标按钮、左侧工具按钮、历史缩略图按钮、分段按钮、历史操作按钮、小工具按钮和底部画笔卡片。
- 集中维护 App 内可复用的 `KCEditorVisualStyle`，统一玻璃态面板、连续圆角、按钮边框、阴影、紧凑按钮和小工具按钮外观。
- 通过 `KCDeviceLayoutMetrics` 使用 iPhone/iPad 设备尺寸指标，避免主控制器重复写尺寸判断。

## 2. 边界

- 只负责控件外观、固定尺寸和层级结构，不注册业务事件。
- 按压反馈 target 仍由 `KCMainViewController.registerPressFeedbackForControl(_:)` 注册，避免事件目标扩散。
- 具体面板里的控件组合、约束安装、按钮 action、状态刷新仍由 `KCMainViewController` 协调。
- 视觉 token 只在 App 层使用，不下沉到 `KCDomain` 或 SPM 基础模块。

## 3. 当前接入

- `KCMainViewController.editorUIFactory` 通过当前 `KCDeviceLayoutMetrics` 构造工厂。
- 原 `floatingPanel()`、`iconButtonWithSymbolName(...)`、`smallToolButtonWithSymbolName(...)` 等控制器方法暂时保留为薄转发，降低调用点改动风险。
- `scripts/validate_project.py` 校验新文件已进入 App target Sources，并守护关键控件创建、控制器委托和 T056 视觉样式入口。

## 4. 验收规则

- 不允许把通用控件样式重新堆回 `KCMainViewController`。
- 不允许绕过 `KCEditorVisualStyle` 新增散落的浮层面板、通用按钮、紧凑按钮、小工具按钮或印章面板 token。
- 不允许把业务 action 或按压反馈 target 下沉到工厂。
- iPhone 与 iPad build、runtime smoke 必须通过。
