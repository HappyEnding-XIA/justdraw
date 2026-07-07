# KCToastPresenter

App 层保存反馈 Toast 展示器：承接保存成功、真实保存失败、空画布保存提示、相册导出失败提示的 UIKit 视图创建、位置约束、图标、文字和动画。位于 `KidCanvas/DesignSystem/KCToastPresenter.swift`，不是独立 SPM target。

## 1. 职责

- 创建保存反馈 Toast 的 `UIVisualEffectView`、系统图标和固定尺寸。
- 根据保存成功、真实保存失败、空画布保存或相册导出失败选择对应图标、文字与颜色。
- 将 Toast 锚定到保存按钮下方，保持原有位置和展示尺寸。
- 播放出现、自动消失动画，并在消失后通过 `dismissalHandler` 通知外层清理引用。
- 提供 `dismiss(_:)`，让主控制器在下一次展示或销毁时移除旧 Toast。

## 2. 边界

- 只负责 Toast 表现层，不判断保存是否成功。
- 不调用相册、会话存储、历史保存或草稿清理。
- 不持有 `KCMainViewController`，只通过传入的 `view` 和 `anchorView` 安装约束。
- 不决定多语言 key；展示文字由 `KCL10n` 提供。

## 3. 当前接入

- `KCMainViewController.toastPresenter` 持有展示器实例，并设置 `dismissalHandler` 清空 `saveToastView`。
- `KCMainViewController.showSaveToastWithSuccess(_:)` 先委托 `toastPresenter.dismiss(_:)` 移除旧 Toast，再调用 `showSaveToast(success:in:anchorView:)` 展示新 Toast。
- `KCMainViewController.showEmptyCanvasSaveToast()` 用于空画布点保存的操作提示，文案必须表达“先画再保存”，不能复用真实保存失败。
- `KCMainViewController.showPhotoExportFailedToast()` 用于相册导出失败的附加反馈，文案必须表达“作品已保存，只是相册未保存”。
- `KCMainViewController.deinit` 委托 `toastPresenter.dismiss(_:)` 清理可能残留的 Toast。
- `scripts/validate_project.py` 校验新文件已进入 App target Sources，并防止 Toast 视图创建逻辑回流主控制器。

## 4. 验收规则

- 不允许在 `KCMainViewController` 重新直接创建 `UIVisualEffectView` Toast 或保存反馈图标。
- 不允许把保存、相册写入、历史记录、草稿逻辑下沉到 Toast 展示器。
- 不允许相册导出失败或空画布保存复用“无法保存”文案；该文案只用于 App 内真实保存失败。
- 保存成功 / 失败的 icon、尺寸、锚点和自动消失行为必须保持一致。
- iPhone 与 iPad build 必须通过。
