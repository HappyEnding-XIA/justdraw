# 模块文档索引

本目录记录 `Packages/KidCanvasModules`（单一本地 SPM package，多 target）中各模块的职责边界、对外 API 与 App 接入方式。架构层总览见 [`../architecture/MODULAR_ARCHITECTURE_DESIGN.md`](../architecture/MODULAR_ARCHITECTURE_DESIGN.md)。

## 已记录模块

- [KCContentCatalog](./KCContentCatalog.md) — 色盘 / 贴纸分组 / 线稿模板的内容来源与 App 接入路径。
- [KCContentPickerFeature](./KCContentPickerFeature.md) — App 层色盘、最近色与贴纸分类状态决策。
- [KCCommon](./KCCommon.md) — SPM 基础公共错误、颜色和日志能力。
- [KCDomain](./KCDomain.md) — UIKit-free 领域模型、协议和纯业务状态决策。
- [KCDrawingEngine](./KCDrawingEngine.md) — 位图、笔触、橡皮擦、蜡笔纹理与线稿几何生成。
- [KCSessionPersistence](./KCSessionPersistence.md) — 本地会话、缩略图、草稿和元数据持久化。
- [KCCanvasFeature](./KCCanvasFeature.md) — App 层画布创建、动作状态与动作按钮外观。
- [KCEditorPanelsFeature](./KCEditorPanelsFeature.md) — App 层工具面板收起状态与折叠态工具芯片色块。
- [KCHistoryFeature](./KCHistoryFeature.md) — App 层历史缩略图状态和删除可用性决策。
- [KCLineArtFeature](./KCLineArtFeature.md) — App 层线稿列表、缩略图与画布线稿渲染编排。
- [KCLineArtPickerViewController](./KCLineArtPickerViewController.md) — App 层线稿选择弹窗 UIKit 展示与选择回调。
- [KCDeviceLayoutMetrics](./KCDeviceLayoutMetrics.md) — App 层 iPhone/iPad 布局指标与尺寸决策。
- [KCEditorUIFactory](./KCEditorUIFactory.md) — App 层编辑器通用 UIKit 控件样式工厂。
- [KCBrushDockFeature](./KCBrushDockFeature.md) — App 层底部画笔 Dock 配置与强调色决策。
- [KCEraserControlsFeature](./KCEraserControlsFeature.md) — App 层橡皮擦预览路径与形状按钮选中态。
- [KCToolRailFeature](./KCToolRailFeature.md) — App 层左侧工具栏配置、强调色与选中态决策。
- [KCPressFeedbackController](./KCPressFeedbackController.md) — App 层通用按钮按压反馈注册与动画。
- [KCToastPresenter](./KCToastPresenter.md) — App 层保存成功 / 失败 Toast 展示与消失动画。
- [KCColorPalettePanelRenderer](./KCColorPalettePanelRenderer.md) — App 层颜色面板 UIKit 渲染与当前色高亮。
- [KCBrushStickerPanelView](./KCBrushStickerPanelView.md) — App 层画笔、贴纸、橡皮与贴纸编辑面板组装。
