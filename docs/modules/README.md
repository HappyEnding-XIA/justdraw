# 模块文档索引

本目录记录 `Packages/KidCanvasModules`（单一本地 SPM package，多 target）中各模块的职责边界、对外 API 与 App 接入方式。架构层总览见 [`../architecture/MODULAR_ARCHITECTURE_DESIGN.md`](../architecture/MODULAR_ARCHITECTURE_DESIGN.md)。

## 已记录模块

- [KCContentCatalog](./KCContentCatalog.md) — 色盘 / 贴纸分组 / 线稿模板的内容来源与 App 接入路径。
- [KCDrawingEngine](./KCDrawingEngine.md) — 位图、笔触、橡皮擦、蜡笔纹理与线稿几何生成。
- [KCLineArtFeature](./KCLineArtFeature.md) — App 层线稿列表、缩略图与画布线稿渲染编排。

> 其余模块（KCCommon / KCDomain / KCSessionPersistence）待按需补充。
