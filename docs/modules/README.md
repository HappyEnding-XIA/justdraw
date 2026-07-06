# 模块文档索引

本目录记录 `Packages/KidCanvasModules`（单一本地 SPM package，多 target）中各模块的职责边界、对外 API 与 App 接入方式。架构层总览见 [`../architecture/MODULAR_ARCHITECTURE_DESIGN.md`](../architecture/MODULAR_ARCHITECTURE_DESIGN.md)。

## 已记录模块

- [KCContentCatalog](./KCContentCatalog.md) — 色盘 / 贴纸分组 / 线稿模板的内容来源与 App 接入路径。
- [KCDrawingEngine](./KCDrawingEngine.md) — 位图、笔触、橡皮擦、蜡笔纹理与线稿几何生成。
- [KCLineArtFeature](./KCLineArtFeature.md) — App 层线稿列表、缩略图与画布线稿渲染编排。
- [KCDeviceLayoutMetrics](./KCDeviceLayoutMetrics.md) — App 层 iPhone/iPad 布局指标与尺寸决策。
- [KCEditorUIFactory](./KCEditorUIFactory.md) — App 层编辑器通用 UIKit 控件样式工厂。
- [KCBrushDockFeature](./KCBrushDockFeature.md) — App 层底部画笔 Dock 配置与强调色决策。
- [KCEraserControlsFeature](./KCEraserControlsFeature.md) — App 层橡皮擦预览路径与形状按钮选中态。

> 其余模块（KCCommon / KCDomain / KCSessionPersistence）待按需补充。
