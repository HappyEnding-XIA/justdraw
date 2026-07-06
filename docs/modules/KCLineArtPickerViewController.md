# KCLineArtPickerViewController

App 层线稿选择弹窗 ViewController：承接线稿弹窗的 UIKit 网格、滚动容器、缩略图按钮和选择回调。位于 `KidCanvas/KCLineArtPickerViewController.swift`，不是独立 SPM target。

## 1. 职责

- 展示线稿选择弹窗，保持现有 `450 x 420` popover 尺寸和 `line-art.picker` 自动化标识。
- 以 2 列网格展示 `KCLineArtItem` 列表。
- 使用 `KCLineArtFeature.thumbnailImage(for:)` 生成每个线稿缩略图。
- 在用户点击线稿后，通过 `SelectionHandler` 回调把 `KCLineArtItem` 交还给主控制器。
- 通过注入的按压反馈注册闭包复用现有按钮按压动画。

## 2. 边界

- 只负责弹窗展示和选择事件回调，不处理草稿保存、历史会话、画布替换或工具切换。
- 不直接访问 `KCDrawingCanvasView`、`KCSessionService` 或相册能力。
- 不持有 popover 锚点；popover 的 source view、source rect 和展示动作仍由 `KCMainViewController.didTapLineArtPicker()` 协调。
- 不改变 `KCLineArtFeature` 的线稿 item、缩略图和画布线稿图片生成职责。

## 3. 当前接入

- `KCMainViewController.didTapLineArtPicker()` 创建 `KCLineArtPickerViewController`。
- 主控制器把 `lineArtItems`、`lineArtFeature`、按压反馈注册闭包和选择回调传入 picker。
- picker 点击线稿后触发 `SelectionHandler`；主控制器 dismiss 弹窗后继续调用 `loadLineArtItem(_:)`，保留原有草稿/会话处理顺序。
- `scripts/validate_project.py` 校验 picker 已进入 App target Sources，并防止线稿弹窗 UI 回流 `KCMainViewController`。

## 4. 验收规则

- 不允许在 `KCMainViewController.didTapLineArtPicker()` 重新创建匿名 `UIViewController` 并手写线稿网格。
- 不允许在主控制器重新出现 `lineArtPreviewButtonForItem(...)` 或线稿预览按钮 target-action。
- 线稿选择后必须仍通过 `KCMainViewController.loadLineArtItem(_:)` 进入画布替换流程。
- iPhone 与 iPad build 必须通过。
