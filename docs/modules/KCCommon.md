# KCCommon

基础公共模块：提供跨模块共享的错误、颜色和日志能力。位于 `Packages/KidCanvasModules/Sources/KCCommon`，是单一本地 SPM package 中最底层的 target。

## 1. 职责

- 提供 `KCError`，统一表达资源缺失、I/O、解码、非法输入和旧格式迁移延迟等通用错误。
- 提供 `KCHexColor`，用 UIKit 无关的 RGBA 归一化分量和十六进制字符串表示颜色。
- 提供 `KCLogging`、`KCLogLevel`、`KCLog`、`KCNullLogger`、`KCBufferedLogger`，为各模块提供最小日志抽象和测试日志器。
- 作为 `KCDomain`、`KCDrawingEngine`、`KCContentCatalog`、`KCSessionPersistence` 等基础 target 的共同依赖。

## 2. 边界

- 不依赖 UIKit、SwiftUI、Photos 或 App target。
- 不放画布、会话、内容目录、贴纸、历史等业务流程。
- 不创建 UI，不读写磁盘业务文件，不访问 `UserDefaults`。
- 不知道任何 Feature，也不反向依赖上层模块。

## 3. 对外 API / 接入路径

- `KCError`：各模块抛出或包装通用失败时使用。
- `KCHexColor`：Domain、内容目录、绘图引擎用它传递颜色；App 层通过 `UIColor(kcHex:)` 做 UIKit 桥接。
- `KCLog`：模块内部输出诊断信息的统一入口；App 壳层可替换 `KCLog.sink`。
- `KCBufferedLogger`：主要用于单元测试或调试时采集日志快照。

## 4. 禁止回流规则

- 禁止把 UIKit 类型、App Feature 类型、会话磁盘路径或 UI 文案下沉到 `KCCommon`。
- 禁止让 `KCCommon` 依赖 `KCDomain` 或任何更高层模块。
- 禁止为单一业务场景在 `KCCommon` 增加专用工具；应先判断是否属于对应 Feature / Core / Infra 模块。
- 禁止在 App 层重新定义与 `KCHexColor`、`KCError` 等重复的公共类型。
