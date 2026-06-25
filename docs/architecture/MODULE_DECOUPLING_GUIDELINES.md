# KidCanvas 模块解耦设计指南

## 1. 目标

本文档定义 KidCanvas 在模块化架构下的解耦原则与落地方式，目标是：

- 降低模块之间的直接耦合
- 让模块边界稳定、清晰、可替换
- 支持多人并行开发
- 支持后续模块独立测试、独立演进、独立重构
- 避免重新回到“一个页面知道所有底层细节”的结构

本文档是 [MODULAR_ARCHITECTURE_DESIGN.md](/Volumes/xiaoda_SSD/KidCanvas/justdraw/docs/architecture/MODULAR_ARCHITECTURE_DESIGN.md) 的补充，专门关注“模块怎么解耦”。

## 2. 解耦结论

KidCanvas 的模块解耦必须建立在以下原则上：

```text
上层依赖抽象
下层提供实现
模块之间通过协议、状态模型、命令、适配器通信
不直接共享内部实现细节
```

不允许的模式：

- Feature 直接访问别的 Feature 的内部类型
- UI 模块直接操作文件系统或相册 API
- 页面直接依赖绘图引擎内部数组、内部 view、内部状态结构
- 多个模块共享“可随意修改”的全局单例

## 3. 解耦原则

### 3.1 依赖倒置

高层模块不依赖低层实现，只依赖抽象。

例如：

- `KCCanvasFeature` 不直接依赖 `SessionStore` 具体类
- `KCCanvasFeature` 只依赖 `SessionRepository` 协议
- `KCPhotoLibrary` 提供 `PhotoImporting` / `PhotoExporting` 实现

### 3.2 最少知识原则

模块只知道自己完成任务所必需的信息。

例如：

- 历史模块只知道会话列表和打开/删除动作
- 不知道 flood fill 怎么实现
- 不知道画布内部如何组织 sticker 状态

### 3.3 单向通信优先

模块间通信优先使用：

- 输入参数
- 返回值
- 协议回调
- 状态驱动

尽量避免：

- 双向强引用
- 跨模块直接持有彼此控制器或 view

### 3.4 接口稳定，内部自由演化

模块对外 API 一旦约定，内部实现可以替换。

例如：

- `KCDrawingEngine` 未来可以优化 flood fill 算法
- 只要 `CanvasRendering` 接口不变，`KCCanvasFeature` 不需要感知

### 3.5 业务语义先于技术语义

跨模块传递的是业务模型，不是底层技术对象。

推荐：

- `ArtworkSession`
- `StickerItem`
- `LineArtTemplate`
- `EditorToolState`

不推荐直接跨模块传：

- `UIView`
- `UIImageView`
- `IndexPath`
- 内部 bitmap buffer

## 4. 模块间通信方式

KidCanvas 推荐 5 种通信方式。

### 4.1 协议

适用于：

- 依赖能力
- 依赖服务
- 依赖仓储

示例：

```swift
public protocol SessionRepository {
    func loadSessions() throws -> [ArtworkSession]
    func save(image: UIImage, existing: ArtworkSession?) throws -> ArtworkSession
    func delete(sessionID: String) throws
}
```

规则：

- 协议定义在上层能依赖的稳定模块中，通常是 `KCDomain`
- 实现放在下层能力模块中

### 4.2 DTO / Domain Model

适用于：

- 模块间传递数据
- 避免泄露内部实现结构

示例：

- `ArtworkSession`
- `StickerItem`
- `PaletteDefinition`
- `HistoryEntryViewData`

规则：

- 对外传输的数据要尽量轻量、稳定
- 不要把内部算法状态直接暴露出去

### 4.3 Command / Action

适用于：

- 模块驱动另一个模块执行动作
- 统一画布交互入口

示例：

```swift
public enum CanvasCommand {
    case selectTool(ToolMode)
    case setColor(ColorToken)
    case setLineWidth(CGFloat)
    case insertSticker(StickerItem)
    case undo
    case redo
    case clear
}
```

收益：

- 上层不需要知道底层具体方法组合
- 便于日志记录、回放、测试、权限控制

### 4.4 Query / Facade

适用于：

- 上层只想拿结果，不想知道内部细节

例如：

- `HistoryFeature` 通过 `HistoryFacade` 获取缩略图和列表
- `CanvasFeature` 通过 `EditorPanelsFacade` 获取展示配置

门面模式适合收口复杂依赖，避免上层同时 import 多个底层模块。

### 4.5 Adapter / Bridge

适用于：

- UIKit 和 SwiftUI 之间
- 系统 API 和业务接口之间
- 旧实现与新实现之间

例如：

- `DrawingCanvasBridge`: SwiftUI 对 UIKit 画布的桥接
- `PhotoLibraryAdapter`: 对系统相册 API 的包装

## 5. 模块解耦规则

### 5.1 Feature 不直接依赖 Feature 内部实现

允许：

- `KCCanvasFeature` 组合 `KCHistoryFeature`
- `KCCanvasFeature` 组合 `KCEditorPanelsFeature`

不允许：

- `KCCanvasFeature` 直接访问 `KCHistoryFeature` 的私有 store
- `KCEditorPanelsFeature` 直接依赖 `KCHistoryFeature` 页面内部 view model

Feature 间如需协作，应通过：

- 公共协议
- view data
- action 回调

### 5.2 Feature 不直接依赖 Infra 实现细节

允许：

- 依赖 `SessionRepository`
- 依赖 `PhotoImporting`

不允许：

- 直接 new `SessionStore` 后读写文件
- 直接在 Feature 中用 `FileManager`
- 直接在 Feature 中写 `UIImagePickerController`

### 5.3 Engine 对外只暴露引擎接口

`KCDrawingEngine` 不应暴露：

- 内部 `UIView` 子节点管理细节
- sticker 数组的可变引用
- undo 栈内部结构
- raw bitmap buffer

对外应该暴露：

- command 接口
- snapshot 接口
- selection state
- capability query

### 5.4 DesignSystem 不反向感知业务

`KCDesignSystem` 只提供样式和通用组件：

- Panel 样式
- Button 样式
- Color token

不允许：

- `HistoryButtonStyle`
- `StickerBusinessBadge`
- 带业务语义的特定功能逻辑

业务语义应留在 Feature。

### 5.5 Domain 不依赖技术实现

`KCDomain` 中禁止出现：

- UIKit
- SwiftUI
- Photos
- FileManager
- UIImagePickerController

Domain 只定义：

- 模型
- 枚举
- 状态
- 协议

## 6. KidCanvas 的解耦设计

### 6.1 `KCCanvasFeature` 与 `KCDrawingEngine`

推荐关系：

```text
KCCanvasFeature
  -> CanvasRendering
  -> CanvasSnapshotProviding
  -> CanvasSelectionProviding
```

而不是：

```text
KCCanvasFeature
  -> DrawingCanvasView concrete type internals
```

建议协议：

```swift
public protocol CanvasRendering: AnyObject {
    func send(_ command: CanvasCommand)
}

public protocol CanvasSnapshotProviding: AnyObject {
    func snapshotImage() -> UIImage?
}

public protocol CanvasSelectionProviding: AnyObject {
    var hasSelectedSticker: Bool { get }
}
```

### 6.2 `KCCanvasFeature` 与 `KCSessionPersistence`

推荐关系：

```text
KCCanvasFeature
  -> SessionRepository
```

而不是：

```text
KCCanvasFeature
  -> SessionStore concrete file implementation
```

### 6.3 `KCHistoryFeature` 与 `KCSessionPersistence`

历史模块不直接处理文件路径，只处理：

- 历史列表 view data
- 打开动作
- 删除动作

缩略图获取建议通过 facade 或 repository 方法包装，而不是让页面自己拼装文件 URL。

### 6.4 `KCEditorPanelsFeature` 与 `KCCanvasFeature`

面板模块只负责：

- 展示工具状态
- 发出用户动作

不要负责：

- 文件读写
- 画布 bitmap 操作
- 相册权限判断

推荐用：

- `EditorToolState`
- `EditorPanelAction`

### 6.5 `KCPhotoLibrary` 与上层模块

上层只应该知道：

- 能否导入
- 导入结果
- 导出结果

不应该知道：

- 使用的是 `UIImagePickerController` 还是后续别的实现
- 权限判断的底层 API 细节

## 7. 解耦反模式

以下是本项目必须避免的反模式。

### 7.1 巨型协调器直接知道所有实现

例如一个 screen 同时：

- 持有 SessionStore
- 持有 DrawingCanvasView
- 持有 FileManager
- 持有 Photos API
- 持有贴纸资源数组
- 持有线稿渲染逻辑

这是当前原型里最需要拆掉的耦合形式。

### 7.2 共享可变全局单例

禁止：

- `AppContext.shared`
- 任意模块都可改的全局状态仓库

推荐：

- 通过 composition root 注入
- 通过协议暴露能力

### 7.3 跨模块传 UIView

不要把具体 UIKit view 当作业务通信对象在模块间传递。

可以传：

- view data
- action
- state
- protocol reference

但不要跨模块直接共享具体 view 层对象。

### 7.4 用 Common 当垃圾桶

`KCCommon` 不是任何“放不下的代码”的收容所。

符合以下条件才能放进 `KCCommon`：

- 与业务无关
- 被多个模块真正复用
- 边界稳定

## 8. 接口设计规范

### 8.1 输入输出明确

跨模块 public API 设计要求：

- 输入参数语义化
- 返回值稳定
- 错误可表达

推荐：

```swift
func loadTemplates(category: LineArtCategory) throws -> [LineArtTemplate]
```

不推荐：

```swift
func loadData(_ value: Any) -> Any
```

### 8.2 避免过大的接口

单个协议不要承担太多职责。

不推荐：

```swift
protocol AppService {
    func save()
    func delete()
    func importImage()
    func exportImage()
    func loadTemplates()
    func fill()
    func undo()
}
```

推荐拆分为：

- `SessionRepository`
- `PhotoImporting`
- `PhotoExporting`
- `CanvasRendering`
- `ContentCatalogProviding`

### 8.3 稳定的跨模块 ViewData

对于 UI 展示数据，优先定义只读 view data：

```swift
public struct HistoryEntryViewData: Equatable {
    public let id: String
    public let title: String
    public let thumbnail: UIImage?
    public let modifiedAtText: String
}
```

这样可以避免页面直接依赖底层存储模型的全部字段。

## 9. 依赖注入规范

### 9.1 所有装配都收口到 App 层

模块具体实现应在 App 层或 composition root 中装配。

禁止：

- Feature 内部偷偷 new Infra 实现
- View 中直接 new Store / Service

### 9.2 默认使用构造注入

优先：

- initializer injection

次选：

- 明确 setter injection

避免：

- 隐式单例注入
- 运行时到处查找依赖

## 10. 测试与解耦

解耦必须服务测试。

模块边界建立后，应做到：

- `KCCanvasFeature` 可用 mock `SessionRepository`
- `KCHistoryFeature` 可用 fake persistence
- `KCEditorPanelsFeature` 可用 mock editor state provider
- `KCDrawingEngine` 的算法模块可直接单测

如果一个模块难以 mock，大概率说明边界还没解耦干净。

## 11. 执行建议

建议按以下顺序推进模块解耦：

1. 先定义 `KCDomain` 中的协议和模型
2. 再把 `KCSessionPersistence`、`KCPhotoLibrary`、`KCContentCatalog` 接到协议后面
3. 再为 `KCDrawingEngine` 设计稳定接口
4. 最后拆 `KCCanvasFeature`、`KCHistoryFeature`、`KCEditorPanelsFeature`

顺序不要反过来。否则上层页面先写死，后续很难拆。

## 12. 最终要求

KidCanvas 的模块化不是“把代码分目录”，而是：

```text
模块边界稳定
模块接口清晰
模块实现可替换
模块依赖单向
模块之间不共享内部细节
```

只有做到这些，模块化才真正成立，后续 SPM 管理、多团队协作、Swift 重构和持续演进才会轻松。

