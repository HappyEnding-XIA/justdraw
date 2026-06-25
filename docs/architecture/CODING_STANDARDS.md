# KidCanvas 代码规范

## 1. 目标

本规范用于统一 KidCanvas 项目的代码组织、命名、分层、模块依赖、UI 编写方式和协作约束。

本规范服务于以下架构目标：

- Swift-first
- SPM 模块化
- 分级分层
- UIKit/Core Graphics 负责画布核心
- SwiftUI 负责外围面板和大部分声明式 UI

本规范不是通用 Swift 风格手册，而是针对当前项目架构的工程规范。

## 2. 总体原则

### 2.1 先模块边界，后功能实现

新增能力时，先判断它属于哪个模块，再开始写代码。不要把功能先塞进页面或控制器里，后面再考虑归类。

### 2.2 单一职责

一个类型只承担一类主要职责：

- 页面类型负责页面展示和交互编排
- service 负责能力调用
- repository/store 负责数据读写
- engine 负责底层绘图或算法
- model 负责业务数据表达

### 2.3 单向依赖

依赖必须遵循架构层级：

```text
App -> Feature -> Core/Infra -> Domain -> Common
```

禁止：

- Domain 依赖 UIKit / SwiftUI
- Core 依赖 Feature
- Feature 互相直接引用实现细节
- App 层直接操作底层文件和图像算法

### 2.4 可测试优先

可抽离为纯 Swift 逻辑的部分，应优先从 UIKit / SwiftUI 中抽离，方便单元测试。

## 3. 模块规范

### 3.1 模块命名

SPM target 统一采用前缀 `KC`：

- `KCCommon`
- `KCDomain`
- `KCDesignSystem`
- `KCDrawingEngine`
- `KCSessionPersistence`
- `KCPhotoLibrary`
- `KCContentCatalog`
- `KCEditorPanelsFeature`
- `KCHistoryFeature`
- `KCCanvasFeature`

App 壳层保留业务名：

- `KidCanvasApp`

### 3.2 一个模块一个职责中心

模块职责必须清晰，禁止“杂物间模块”。

例如：

- `KCDrawingEngine` 只负责画布能力
- `KCSessionPersistence` 只负责会话存储
- `KCContentCatalog` 只负责贴纸/线稿/调色板目录

不要把：

- UI 组件塞进 Persistence
- 存储逻辑塞进 Feature
- 业务模型塞进 Common

### 3.3 模块公开边界

每个模块只暴露必要的 public API。

规则：

- 默认使用 `internal`
- 只有跨模块使用的类型和方法才标记为 `public`
- 不要为了方便调试扩大可见性

## 4. 目录规范

### 4.1 App 目录

```text
App/
  KidCanvasApp.swift
  AppDelegate.swift
  SceneDelegate.swift
  CompositionRoot/
```

### 4.2 SPM 目录

```text
Packages/KidCanvasModules/
  Package.swift
  Sources/
  Tests/
```

### 4.3 模块内部目录建议

每个模块按职责分子目录，不按文件后缀粗暴分类。

推荐形式：

```text
KCCanvasFeature/
  Screens/
  ViewModels/
  Coordinators/
  Mappers/
```

```text
KCDrawingEngine/
  Views/
  Models/
  Algorithms/
  Services/
```

```text
KCSessionPersistence/
  Stores/
  DTOs/
  Migrations/
```

## 5. 命名规范

### 5.1 类型命名

- 类型名使用 PascalCase
- 名称应表达职责，而不是技术细节

推荐：

- `DrawingCanvasView`
- `SessionStore`
- `PhotoLibraryService`
- `EditorToolState`
- `LineArtCatalog`

避免：

- `Manager`
- `Helper`
- `Util`
- `DataProcessor`

除非职责真的非常清晰，否则不要使用含糊大词。

### 5.2 协议命名

协议名优先表达能力，而不是机械加 `Protocol`。

推荐：

- `SessionRepository`
- `PhotoImporting`
- `CanvasSnapshotProviding`

不推荐：

- `SessionRepositoryProtocol`
- `PhotoServiceProtocol`

### 5.3 变量与方法命名

- 变量使用 lowerCamelCase
- 方法名使用动词开头
- 布尔值使用可读前缀

推荐：

- `saveDraftIfNeeded()`
- `loadHistorySessions()`
- `isDirty`
- `hasVisibleContent`
- `canUndo`

### 5.4 SwiftUI View 命名

界面名称统一以职责结尾：

- `CanvasScreen`
- `HistoryPanelView`
- `ColorPaletteView`
- `StickerPickerView`

不要大量使用泛名：

- `ContentView`
- `MainView`
- `CustomView`

## 6. Swift 代码风格

### 6.1 类型长度控制

建议控制：

- 单个 type 不超过 300-500 行
- 单个 SwiftUI view 不超过 200-300 行
- 单个文件超过 500 行时必须考虑拆分

画布引擎这种例外模块允许更大，但算法与视图逻辑必须继续拆分。

### 6.2 扩展使用规则

使用 `extension` 按职责拆分实现，例如：

- lifecycle
- actions
- layout
- delegate
- private helpers

不要把所有实现堆在主类型体内。

### 6.3 注释规范

注释只写必要信息：

- 为什么这样做
- 非显而易见的约束
- 算法或边界条件

不要写显而易见的注释。

推荐：

```swift
// Flood fill must cap pixel allocation to avoid oversized imported image crashes.
```

不推荐：

```swift
// Set value to width
width = value
```

### 6.4 错误处理

- 预期失败使用 `throws` 或显式 `Result`
- 不要静默吞错误
- 用户可见失败要映射成明确的 UI 反馈

禁止：

- 大量 `try?` 直接忽略错误
- 无说明地 `catch {}` 空处理

## 7. SwiftUI 规范

### 7.1 SwiftUI 适用范围

SwiftUI 优先用于：

- 工具面板
- 历史面板
- 贴纸面板
- 颜色选择
- 空状态
- 提示浮层
- 配置驱动 UI

### 7.2 SwiftUI 不负责画布核心

以下内容不应作为纯 SwiftUI 直接实现：

- 主绘图画布
- flood fill 核心逻辑
- 贴纸底层多手势编辑引擎
- 像素级取色
- 位图撤销重做

这部分必须留在 UIKit/Core Graphics 模块中。

### 7.3 View 拆分规则

SwiftUI 页面拆分标准：

- 一个 screen 负责整体编排
- panel/view 负责局部展示
- 复杂状态逻辑下沉到 view model / state holder

不要把：

- 业务逻辑
- 文件 IO
- 图像处理

直接写进 `body` 或 view action 闭包中。

## 8. UIKit / Core Graphics 规范

### 8.1 画布内核规则

`KCDrawingEngine` 中：

- UIKit view 负责事件接收与渲染触发
- 算法逻辑尽量拆到独立类型
- 贴纸、stroke、canvas state 要使用清晰模型表达

### 8.2 图形算法规则

以下能力应独立为算法或 service：

- flood fill
- color sampler
- snapshot rendering
- thumbnail generation
- undo/redo state transform

原因：

- 更易测试
- 更易复用
- 降低 view 复杂度

### 8.3 性能规则

- 避免在主线程做重型遍历和大位图分配
- 对导入大图、填色、缩略图生成等逻辑进行尺寸校验
- 大型算法必须考虑边界保护和内存上限

## 9. 状态管理规范

### 9.1 单一事实来源

同一类状态只能有一个主来源。

例如：

- 当前工具：`EditorToolState`
- 历史会话列表：`SessionStore` / history state holder
- 当前选中贴纸：canvas state

不要在多个 View 和 Engine 中各自维护一份等价状态。

### 9.2 状态分层

- Domain state：纯业务语义
- Feature state：页面状态
- View local state：仅本地视觉状态

不要把短暂 UI 状态写进 Domain，也不要把业务状态只藏在 View 私有变量中。

## 10. 资源管理规范

### 10.1 资源归属

资源必须归模块所有：

- 贴纸、线稿、调色板 -> `KCContentCatalog`
- 通用图标、样式资源 -> `KCDesignSystem`
- App 图标、启动相关资源 -> App 壳工程

### 10.2 禁止硬编码内容目录

禁止长期保留：

- 大量贴纸列表硬编码在页面里
- 大量线稿 drawing block 塞在控制器里
- 调色板直接散落在多个文件里

应改为：

- JSON
- package resources
- asset catalog

### 10.3 资源命名

统一使用语义化名称：

- `sticker.star.yellow`
- `lineart.animal.cat`
- `palette.default.24`

不要使用：

- `img1`
- `test_asset`
- `new_final_v2`

## 11. 测试规范

### 11.1 单元测试优先级

优先为以下模块建立测试：

- `KCDomain`
- `KCDrawingEngine` 的算法部分
- `KCSessionPersistence`
- `KCContentCatalog`

### 11.2 测试命名

测试方法应描述行为和结果：

- `test_saveSession_writesMetadataAndThumbnail()`
- `test_floodFill_rejectsOversizedBitmap()`
- `test_restoreDraft_returnsNilWhenMissingFile()`

### 11.3 回归关注点

每次重构后至少关注：

- 画布绘制
- 撤销重做
- 填色
- 取色
- 贴纸交互
- 历史恢复
- 相册导入导出

## 12. 文档规范

### 12.1 文档归类

项目文档统一放在：

- `docs/architecture`
- `docs/product`
- `docs/release`

AI 协作文档放在：

- `ai-docs/`

### 12.2 正式文档命名

建议：

- `TECHNICAL_ARCHITECTURE.md`
- `MODULAR_ARCHITECTURE_DESIGN.md`
- `CODING_STANDARDS.md`

避免：

- `new-doc.md`
- `temp.md`
- `架构最终版2.md`

## 13. Git 与协作规范

### 13.1 提交边界

- 一个提交只做一类事
- 架构调整和功能修改尽量分开
- 机械移动文件与行为修改尽量分开

### 13.2 高风险操作

以下操作必须人工确认：

- 签名与构建配置变更
- 大规模删除
- 依赖大版本升级
- Git 历史改写

### 13.3 AI 协作

遵循 `ai-docs/AI_COLLAB_PROTOCOL.md`：

- 先登记任务
- 再开始修改
- 有文件占用时不得并发改同一范围

## 14. 禁止事项

以下做法在本项目中禁止：

- 新增 Objective-C 主线代码
- 把画布核心直接改成纯 SwiftUI
- 在 Feature 中直接做文件读写
- 在 Domain 中引用 UIKit / SwiftUI / Photos
- 将无关能力塞进 `Common`
- 大量硬编码贴纸、线稿、调色板
- 使用含糊命名如 `Manager`、`Helper`、`Util`
- 把大型业务逻辑直接塞进单个 ViewController 或 SwiftUI Screen

## 15. 执行建议

规范落地顺序建议：

1. 先建立 SPM 模块骨架
2. 迁移 Domain / Persistence / Catalog
3. 迁移 DrawingEngine
4. 迁移 Feature 层
5. 最后收缩 App 壳层

在迁移过程中，这份规范优先级高于临时个人习惯。

