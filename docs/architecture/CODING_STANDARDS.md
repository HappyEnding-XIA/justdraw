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

允许边界：

- `KCDomain` / `KCCommon` 可以使用 CoreGraphics 的基础几何类型，例如 `CGPoint`、`CGSize`、`CGRect`、`CGAffineTransform`
- `CGImage`、位图 buffer、颜色采样、渲染上下文等图像处理类型应放在 `KCDrawingEngine` 或明确的 Infra/Core 模块中
- `UIColor`、`UIImage`、`UIView`、`UIViewController` 不得进入 `KCDomain` / `KCCommon`

### 2.4 可测试优先

可抽离为纯 Swift 逻辑的部分，应优先从 UIKit / SwiftUI 中抽离，方便单元测试。

## 3. 模块规范

### 3.1 模块命名

SPM target 统一采用前缀 `KC`。模块列表必须区分当前已实现模块和规划中模块。

| 模块 | 状态 | 说明 |
|:---|:---|:---|
| `KCCommon` | 已实现 | 公共工具、错误、日志等基础能力 |
| `KCDomain` | 已实现 | 业务模型、状态、协议 |
| `KCDrawingEngine` | 已实现 | 画布算法、位图处理、笔刷计算 |
| `KCSessionPersistence` | 已实现 | 会话、草稿、缩略图持久化 |
| `KCContentCatalog` | 已实现 | 贴纸、线稿、调色板目录 |
| `KCDesignSystem` | 规划中 | 设计系统与通用 UI 样式 |
| `KCPhotoLibrary` | 规划中 | 相册导入导出与权限适配 |
| `KCEditorPanelsFeature` | 已实现（App 最小边界） | 工具、颜色、贴纸、线稿等编辑面板 |
| `KCHistoryFeature` | 已实现（App 最小边界） | 历史作品与草稿入口 |
| `KCCanvasFeature` | 已实现（App 最小边界） | 主画布业务编排 |
| `KCLineArtFeature` | 已实现（App 最小边界） | 线稿列表、缩略图与画布线稿渲染编排 |
| `KCDeviceLayoutMetrics` | 已实现（App 最小边界） | iPhone/iPad 布局指标与尺寸决策 |

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
- `Packages/KidCanvasModules` 内的跨模块 `public` / `open` 类型必须使用 `KC` 前缀
- 一个文件如果以某个跨模块主类型为中心，文件名必须与该主类型一致，也必须使用 `KC` 前缀

推荐：

- `KCDrawingCanvasView`
- `KCSessionStore`
- `KCPhotoLibraryService`
- `KCEditorToolState`
- `KCLineArtCatalog`

避免：

- `DrawingCanvasView`
- `SessionStore`
- `PhotoLibraryService`
- `Manager`
- `Helper`
- `Util`
- `DataProcessor`

除非职责真的非常清晰，否则不要使用含糊大词。

### 5.1.1 SPM 模块内文件命名

`Packages/KidCanvasModules` 是项目正式模块化承载，命名要体现项目归属。

强制规则：

- `Sources/` 下的主源码文件必须使用 `KC` 前缀
- 文件名应与文件内主类型一致，例如 `KCSessionStore.swift` 内定义 `KCSessionStore`
- `public` / `open` 的 struct、class、enum、protocol、actor 必须使用 `KC` 前缀
- 测试文件应跟随被测类型，例如 `KCSessionStoreTests.swift`
- 新增 bridge、facade、repository、service、engine、catalog 类型时同样必须使用 `KC` 前缀

允许例外：

- `Package.swift`
- Swift 标准入口或系统约定文件
- 仅在单文件内部使用的 `private` / `fileprivate` helper
- Apple 协议扩展、系统类型 extension，例如 `extension UIColor`

当前已经存在的非 `KC` 文件和类型，应作为命名收敛任务处理，不要在功能迁移中顺手零散改名。

### 5.2 协议命名

协议名优先表达能力，而不是机械加 `Protocol`。

推荐：

- `KCSessionRepository`
- `KCPhotoImporting`
- `KCCanvasSnapshotProviding`

不推荐：

- `SessionRepository`
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

注释语言：

- 代码注释统一使用中文
- 文件头中的 Xcode 固定字段可保留英文，例如 `Created by`
- API 名称、系统类型、协议名、错误原文、第三方库名称等必要技术名词可保留英文
- 面向用户展示的 UI 文案不因本规则改变，仍按产品多语言策略处理

不要写显而易见的注释。

推荐：

```swift
// 限制 flood fill 的像素分配，避免导入超大图片时崩溃。
```

不推荐：

```swift
// 将 value 设置给 width
width = value
```

### 6.4 文件头规范

AI 或人工新建源码文件时，必须在文件顶部保留 Xcode 风格文件头。

适用范围：

- Swift 源文件：`.swift`
- Objective-C 头文件：`.h`
- Objective-C 实现文件：`.m`
- 后续新增的同类源码文件

文件头必须包含：

- 文件名
- 所属 target、package 或工程名
- 创建人：`小大`
- 创建日期：使用 `YYYY/MM/DD` 零填充格式

Swift 文件示例：

```swift
//
//  SessionStoreBridge.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/25.
//
```

Objective-C 文件示例：

```objc
//
//  KDMainViewController.m
//  KidCanvas
//
//  Created by 小大 on 2026/06/25.
//
```

约束：

- Codex、Claude 或其他 AI 新建文件时必须主动补齐文件头
- 迁移 Objective-C 到 Swift 时，新 Swift 文件也必须补齐文件头
- 修改旧文件时，如文件头缺失，且本次修改涉及该文件，应顺手补齐
- 文件头只记录基础归属信息，不写任务说明、迁移说明或实现细节

### 6.5 错误处理

- 预期失败使用 `throws` 或显式 `Result`
- 不要静默吞错误
- 用户可见失败要映射成明确的 UI 反馈
- 产品主逻辑不得用 `try?` 隐藏失败原因
- 临时桥接层、适配层允许使用 `try?` 做降级，但必须在方法注释或方法命名中说明降级行为，并在上层提供可恢复路径

禁止：

- 大量 `try?` 直接忽略错误
- 无说明地 `catch {}` 空处理

### 6.6 Swift / Objective-C 桥接规范

迁移期允许保留薄桥接层，但桥接层只能做语言边界转换，不承载业务规则。

命名规则：

- Swift bridge 使用 `KCXxxBridge.swift`
- Objective-C 手写头使用 `KCXxxBridge.h`
- App target 内临时 bridge 也必须遵守文件头规范

边界规则：

- SPM 模块内优先保持纯 Swift API
- Objective-C 兼容逻辑放在 App target bridge 中
- bridge 可以引用 UIKit 做 `UIImage` / `UIColor` / `UIBezierPath` 转换，但不得把 UIKit 类型下沉到 `KCDomain` / `KCCommon`
- bridge 方法应尽量薄，只做参数转换、结果包装、错误降级和向 Swift 模块转发
- 长期不应使用 `[String: Any]` 作为跨语言数据模型；迁移稳定后应收敛为明确的 `@objc NSObject` DTO 或 Swift typed model

头文件规则：

- 当前工程迁移期不要依赖自动生成的 `KidCanvas-Swift.h`
- 如 `KidCanvas-Swift.h` 生成为空或不稳定，必须手写 Objective-C bridge header
- 手写 header 的 selector 必须与 Swift `@objc` 暴露的方法一致
- 更新 bridge 后，应通过构建产物或编译验证确认 selector 可用，例如使用 `strings` / `nm` 检查 `.o` 或最终二进制

禁止：

- 在 bridge 中实现画布算法、存储算法或 UI 编排逻辑
- 为了 Objective-C 调用方便扩大 SPM 模块 public API
- 在多个 bridge 中重复包装同一能力

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

资源主路径：

- `KCContentCatalog` 的色盘、贴纸、线稿元数据必须优先来自 JSON / package resources
- 硬编码内容只允许作为资源缺失、为空或解码失败时的集中 fallback
- fallback 必须集中在 Catalog 模块内，不得散落到 ViewController、Feature 或 App 层
- 新增内容字段时必须同步 JSON schema、解析测试和模块文档

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

测试方法使用 XCTest 常见 camelCase 风格，并描述行为和结果：

- `testSaveSessionWritesMetadataAndThumbnail()`
- `testFloodFillRejectsOversizedBitmap()`
- `testRestoreDraftReturnsNilWhenMissingFile()`

每迁移一个 Objective-C 算法到 Swift，都必须同步补行为锚点测试，避免只移动代码、不建立回归保护。

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
