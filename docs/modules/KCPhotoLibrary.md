# KCPhotoLibrary

App 层系统相册适配模块：承接作品导出到系统相册的 UIKit / Photos API 调用。位于 `KidCanvas/Infrastructure/KCPhotoLibraryService.swift`，不是独立 SPM target。

## 1. 职责

- 实现 `KCDomain.KCPhotoLibraryServicing`，为 App 层提供系统相册导出能力。
- 将 PNG / JPEG `Data` 转为系统相册可写入的图片，并通过系统 API 获取导出结果。
- 把相册导出结果从 App 内历史保存结果中拆开：历史保存成功即视为作品已保存，相册失败只作为附加反馈。

## 2. 边界

- 不负责 App 内历史存储、草稿清理、缩略图生成或保存按钮状态。
- 不直接操作 `KCMainViewController` 的历史列表和会话状态。
- 不决定 Toast 文案；用户反馈由 `KCMainViewController` 和 `KCToastPresenter` 编排。
- 不替代当前 `UIImagePickerController` 导入流程；导入仍由编辑器控制器负责系统 UI 呈现。

## 3. 当前接入

- `KCAppCompositionRoot` 创建 `KCPhotoLibraryService`，并以 `KCPhotoLibraryServicing` 注入 `KCMainViewController`。
- `KCMainViewController.finishSavingSession(...)` 在 App 内历史保存成功后先展示“已保存”，再调用 `exportSavedArtworkToPhotoLibrary(imageData:)` 进行 best-effort 相册导出。
- 相册导出失败时展示独立文案“已保存，相册未保存”，不得复用“无法保存”否定 App 内保存成功。
- Debug 运行时探针 `photo-export-failure` 会强制相册导出失败，验证历史数增加、当前会话建立、主保存成功反馈已观察到，并且失败反馈不覆盖成本地保存失败语义。

## 4. 禁止回流规则

- 禁止在 `KCMainViewController` 中直接调用 `UIImageWriteToSavedPhotosAlbum` 或等价相册写入 API；系统相册导出必须通过 `KCPhotoLibraryServicing`。
- 禁止把相册导出失败当成 App 内历史保存失败展示“无法保存”。
- 禁止让 `KCSessionPersistence` 或 `KCSessionService` 感知系统相册权限、导出结果或 Toast 文案。
- 禁止为了相册导出重新生成画布快照或重复 PNG 编码；正式保存已生成的 PNG 数据应复用于相册导出。
