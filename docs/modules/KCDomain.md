# KCDomain

领域模型模块：承载 KidCanvas 的纯业务模型、状态决策和协议边界。位于 `Packages/KidCanvasModules/Sources/KCDomain`，依赖 `KCCommon`，不依赖 UIKit。

## 1. 职责

- 定义作品、笔触、工具、贴纸、内容目录、编辑器状态等业务模型。
- 定义 `KCSessionRepository`、`KCPhotoLibraryServicing` 等协议边界，让 Feature 依赖抽象而不是具体存储或系统框架。
- 承载可单测的纯决策逻辑，例如历史分页、历史缩略图相邻页预热索引、历史缩略图状态、颜色面板布局、最近色队列、贴纸分类映射、贴纸约束、印章显示指标、工具状态标题、一次性工具完成后的工具恢复规则。
- 为 `KCDrawingEngine`、`KCContentCatalog`、`KCSessionPersistence` 和 App Feature 提供稳定业务语义。

## 2. 边界

- 不依赖 UIKit、SwiftUI、Photos、FileManager 业务路径或 App target。
- 不创建视图、不安装约束、不处理 target/action。
- 不做真实图片编码、相册读写、会话文件读写或 Core Graphics 绘制。
- 不直接知道 `KCMainViewController`、`KCDrawingCanvasView` 或任何 App 层 Feature 实现。

## 3. 对外 API / 接入路径

- 业务枚举：`KCToolMode`、`KCBrushStyle`、`KCEraserShape`。
- 作品与画布模型：`KCArtworkSession`、`KCCanvasSnapshot`、`KCStroke`、`KCStickerItem`、`KCStickerTransform`。
- 内容模型：`KCContentPalette`、`KCStickerGroup`、`KCLineArtTemplate`、`KCPaletteSize`。
- 纯逻辑：`KCContentPickerLayout`、`KCRecentColorQueue`、`KCStickerCategoryMapping`、`KCHistoryPaging`、`KCHistoryThumbStatus`、`KCEditorPanelsCollapseState`、`KCStickerConstraints`、`KCStickerSymbolDisplayMetrics`、`KCToolStateChipTitle`、`KCTransientToolModeMemory`。
- `KCHistoryPaging.adjacentPageSessionIndexes()`：按“下一页优先、上一页补充”的顺序返回相邻页会话索引，用于 App 层后台预热历史缩略图缓存；该规则必须在 Domain 层单测，不得散落在控制器中。
- 协议：`KCSessionRepository` 由 `KCSessionPersistence.KCSessionStore` 实现；`KCPhotoLibraryServicing` 留给 App / Infra 适配系统相册。

## 4. 禁止回流规则

- 禁止把 `UIColor`、`UIImage`、`UIView`、`UIBezierPath`、`UserDefaults` 或 Photos 类型放入 `KCDomain`。
- 禁止让 Domain 模型直接调用 App 服务、Composition Root 或 Feature。
- 禁止把 UI 样式常量、按钮布局、弹窗尺寸写入领域层；这类内容属于 App Feature / DesignSystem。
- 禁止在 App 层复制领域纯逻辑；新增规则应优先进入 `KCDomain` 并补单元测试。
- 印章 SF Symbol 的可测试显示规则统一放在 `KCStickerSymbolDisplayMetrics`；App 层只根据其返回的容器、点大小和安全边距生成 `UIImage`，不得在画布中散落单个符号的尺寸特判。
