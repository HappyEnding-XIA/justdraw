# KCDeviceLayoutMetrics

App 层设备布局指标：集中 iPhone 与 iPad 的尺寸决策。位于 `KidCanvas/KCDeviceLayoutMetrics.swift`，不是独立 SPM target。

## 1. 职责

- 判断当前是否为紧凑 iPhone 布局。
- 输出右侧面板、底部工具坞、画笔卡片、历史缩略图等固定尺寸和安全区距离。
- 保持 iPhone 与 iPad 的现有视觉尺寸不变，让 `KCMainViewController` 不再直接散落设备尺寸三元表达式。

## 2. 边界

- 本类型只保存布局指标，不创建 UIKit 视图，不绑定事件，不访问画布或会话状态。
- `KCMainViewController` 仍负责实际视图构建和 Auto Layout 约束安装。
- 如果后续需要更完整的响应式布局，应在此基础上扩展指标模型，避免把新尺寸重新写回控制器。

## 3. 当前接入

- `KCMainViewController.layoutMetrics` 通过 `UIDevice.current.userInterfaceIdiom` 构造当前指标。
- 控制器的 `rightPanelWidth()`、`bottomDockWidth()`、`brushCardWidth()` 等方法暂时保留为薄转发，降低本次改动对现有调用点的影响。
- T056 后底部工具坞约束到 `safeAreaLayoutGuide.bottomAnchor`，由 `bottomDockBottomInset` 提供 iPhone/iPad 差异距离，避免横屏贴近系统安全区。
- `scripts/validate_project.py` 校验新文件已进入 App target Sources，并守护关键 iPhone/iPad 尺寸值。

## 4. 验收规则

- 不允许把右侧面板、底部工具坞、画笔卡片、历史缩略图的设备尺寸判断重新散落回 `KCMainViewController`。
- 不允许底部工具坞重新约束到裸 `view.bottomAnchor`。
- iPhone 与 iPad build、runtime smoke 必须通过。
