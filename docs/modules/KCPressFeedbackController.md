# KCPressFeedbackController

App 层通用按压反馈控制器：承接按钮按下、拖入、释放、取消时的缩放与透明度动画。位于 `KidCanvas/DesignSystem/KCPressFeedbackController.swift`，不是独立 SPM target。

## 1. 职责

- 为 `UIControl` 注册统一的按压反馈事件。
- 在按下时记录控件原始 `transform` 和 `alpha`，释放时恢复。
- 对 disabled 控件跳过按压反馈，避免不可点击控件产生误导。
- 使用 UIKit 动画保持原有编辑器按钮的轻量缩放和透明度反馈。

## 2. 边界

- 只负责按压动画和临时 UI 状态，不处理业务点击事件。
- 不创建按钮，不决定按钮样式、图标、标题或布局。
- 不持有画布、会话、工具模式、颜色或贴纸状态。
- `objc_getAssociatedObject` / `objc_setAssociatedObject` 仅在该控制器内部使用，不允许回流到 `KCMainViewController`。

## 3. 当前接入

- `KCMainViewController.pressFeedbackController` 持有控制器实例。
- `KCMainViewController.registerPressFeedbackForControl(_:)` 保留为薄转发，统一调用 `pressFeedbackController.register(control)`。
- 线稿弹窗通过闭包复用主控制器的按压反馈注册入口，避免弹窗自行复制动画逻辑。
- `scripts/validate_project.py` 校验新文件已进入 App target Sources，并防止 associated-object 状态回流主控制器。

## 4. 验收规则

- 不允许在 `KCMainViewController` 重新直接读写按压反馈 associated-object。
- 不允许把业务 action、工具状态切换或保存逻辑下沉到按压反馈控制器。
- disabled 控件不得触发按压动画。
- iPhone 与 iPad build 必须通过。
