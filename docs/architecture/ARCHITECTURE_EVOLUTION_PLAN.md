# KidCanvas 技术架构演进方案

## 1. 目标

本文记录 KidCanvas 当前到中长期的技术演进路线，用于指导 Swift 化、模块化、业务模块扩展和依赖解耦。

核心目标：

- 彻底弃用 Objective-C 业务代码。
- 保持 iPhone + iPad 支持，横屏优先。
- 使用 Swift-first 架构推进模块化。
- 保留 UIKit/Core Graphics 作为画布核心技术路线。
- 支持后续用户、会员、素材、同步等业务模块持续扩展。
- 在依赖关系清晰之前，不用容器隐藏复杂度。

## 2. 架构决策

### 2.1 模块化方向

当前采用：

```text
App target + 一个本地 SPM package + 多个 library target
```

即：

```text
KidCanvas.xcodeproj
  KidCanvas

Packages/KidCanvasModules
  KCCommon
  KCDomain
  KCDrawingEngine
  KCContentCatalog
  KCSessionPersistence
```

后续继续在 `KidCanvasModules` 中增加 target，而不是立即拆成多个 package。

当前真实状态（2026-07-06）：

- 当前 App target 已无业务 Objective-C `.m` 源码。
- 当前工程已无 `KidCanvas-Bridging-Header.h`。
- 当前 SPM 落地形态是 1 个本地 package、5 个基础 library target。
- App Feature 暂在 App target 内渐进拆分。
- 继续支持 iPhone + iPad，横屏优先。
- 禁止一个模块一个 package。
- 禁止把画布核心重写为纯 SwiftUI Canvas。

### 2.2 为什么暂不一个模块一个 package

当前项目仍处于 Feature 边界收敛期：

- `KCMainViewController` 已拆出多组 App 层 Feature，但仍承担保存、历史、相册、草稿等强协调流程。
- `KCDrawingCanvasView` 已迁为 Swift UIKit/Core Graphics 画布，绘制算法已逐步下沉到 `KCDrawingEngine`。
- `KCAppCompositionRoot` 已建立，但后续用户、会员、素材、同步等业务模块尚未落地。
- 业务模块之间的真实依赖关系还需要多轮迭代验证。

如果此时一个模块一个 package，会导致每次调整边界都牵涉 package 依赖、路径、版本和 Xcode 配置，迁移成本会被放大。

结论：

```text
先 target 模块化，后 package 独立化。
```

### 2.3 何时升级为独立 package

满足以下条件时，某个 target 可以升级为独立 package：

- 模块边界稳定，三轮以上功能迭代没有频繁调整 public API。
- 模块有独立复用、独立版本管理或独立发布需求。
- 模块测试可以独立运行，不依赖 App target。
- 模块资源、依赖、mock 和示例已经完整。
- 拆出后不会造成大量反向依赖或循环依赖。

优先可独立化候选：

- `KCUserInterface`
- `KCUserFeature`
- `KCMembershipInterface`
- `KCCloudSyncInterface`
- `KCContentCatalog`
- `KCDrawingEngine`

## 3. 分阶段路线

### 阶段 0：工程卫生与基础模块

状态：已基本完成。

内容：

- 建立 `Packages/KidCanvasModules`。
- 接入 `KCCommon`、`KCDomain`、`KCDrawingEngine`、`KCContentCatalog`、`KCSessionPersistence`。
- 通过 `swift test`、`validate_project.py`、iPhone/iPad 构建。
- 清理 AppIcon / Info.plist warning。

验收标准：

- 所有已落地 SPM target 可单独测试。
- App target 能链接全部基础模块。
- iPhone + iPad 构建稳定。

### 阶段 1：Objective-C 清零

状态：已完成，对应任务 `T014`。

已完成目标：

- App target 不再编译业务 `.m` 文件。
- 删除历史 Objective-C 主线文件。
- 删除迁移期 bridge header 和 `KidCanvas-Bridging-Header.h`。
- 旧 `sessions.archive` 兼容能力迁到 Swift。

约束：

- 不把画布核心重写成 SwiftUI。
- 不破坏旧会话迁移。
- 不改变 Bundle ID、Team、签名证书、发布配置。

验收标准：

- `KidCanvas.xcodeproj` App target Sources 不再包含业务 `.m`。
- `scripts/validate_project.py` 能校验 OC 清零。
- `swift test`、validator、iPhone/iPad build 全部通过。

### 阶段 2：建立 CompositionRoot

目标：

- 在 App target 建立 `KCAppCompositionRoot`。
- 所有核心依赖由 App 统一创建和注入。
- Feature 不直接 new Infra/Core 具体实现。

建议装配对象：

- `KCSessionRepository`
- `KCLegacySessionMigrator`
- `KCBundledContentCatalog`
- `KCPhotoLibraryServicing`
- `KCDrawingEngineFacade`
- `KCCanvasCommandHandling`

推荐方式：

```swift
struct KCAppCompositionRoot {
    let sessionRepository: KCSessionRepository
    let contentCatalog: KCBundledContentCatalog

    func makeCanvasFeature() -> KCCanvasFeature {
        KCCanvasFeature(
            sessionRepository: sessionRepository,
            contentCatalog: contentCatalog
        )
    }
}
```

当前阶段不引入 Swinject，也不照搬全局 Service Locator。

### 阶段 3：Feature 层落地

对应任务：`T013`。

目标：

- 将主控制器职责拆为 Feature 边界。
- 将页面编排、历史、工具面板、画布协调从单个控制器中拆出。

建议模块：

```text
KCCanvasFeature
KCEditorPanelsFeature
KCHistoryFeature
```

依赖方式：

- Feature 接收协议和 model。
- Feature 之间通过 action、view data、facade 通信。
- 不跨 Feature 直接访问内部 ViewModel、store 或 view。

### 阶段 4：业务模块扩展

后续用户、会员、素材商店、云同步等模块应按业务边界扩展，而不是继续堆进 App target。

建议模块：

```text
KCUserInterface
KCUserFeature
KCMembershipInterface
KCMembershipFeature
KCStoreInterface
KCStoreFeature
KCCloudSyncInterface
KCCloudSyncFeature
```

核心规则：

- 其他模块依赖 `Interface` target，不直接依赖 `Feature` 实现。
- 实现由对应 Feature 或 Infra target 提供。
- App CompositionRoot 负责把实现注入给使用方。

示例：

```text
KCCanvasFeature -> KCUserInterface
KCStoreFeature -> KCUserInterface
KCHistoryFeature -> KCUserInterface
KCUserFeature -> KCUserInterface
KidCanvasApp -> KCUserFeature
```

避免：

```text
KCCanvasFeature -> KCUserFeature
KCStoreFeature -> KCUserFeature
KCHistoryFeature -> KCUserFeature
```

### 阶段 5：评估 DI 容器

当前不引入 Swinject。

可以重新评估的条件：

- Feature target 超过 8 个。
- 依赖装配重复明显增加。
- 测试中手写 mock 装配成本明显上升。
- 需要模块级 Assembly 管理。
- 依赖生命周期已经明确，存在大量 singleton、graph、transient 管理需求。

如果引入，优先使用 Swinject 的 `Assembly / Assembler` 思路，而不是在业务代码中到处 `resolve`。

禁止：

- 在 View、ViewModel、Feature 内部随处访问全局 container。
- 用 DI 容器掩盖循环依赖。
- 用属性包装器隐藏关键依赖来源。

## 4. 依赖解耦策略

### 4.1 协议放在哪里

早期公共协议可以放在 `KCDomain`。

当某个业务域变大时，应拆出独立 Interface target：

```text
KCUserInterface
KCMembershipInterface
KCCloudSyncInterface
```

Interface target 放：

- 业务协议
- DTO
- 轻量 domain model
- 错误类型
- 事件/action 定义

Interface target 不放：

- UIKit 页面
- SwiftUI 页面
- 文件存储实现
- 网络实现
- 数据库实现

### 4.2 实现放在哪里

实现放在 Feature 或 Infra target：

- `KCSessionStore` 放 `KCSessionPersistence`
- 相册实现放 `KCPhotoLibrary`
- 用户登录实现放 `KCUserFeature` 或 `KCUserInfra`
- 云同步实现放 `KCCloudSyncFeature` 或 `KCCloudSyncInfra`

### 4.3 谁负责创建实例

实例由 App 壳层或 CompositionRoot 创建。

不要让 Feature 自己创建下层实现：

```swift
// 不推荐
let store = KCSessionStore()
```

推荐：

```swift
final class KCHistoryViewModel {
    private let repository: KCSessionRepository

    init(repository: KCSessionRepository) {
        self.repository = repository
    }
}
```

## 5. 核心部位

### 5.1 架构核心

架构核心是稳定接口和装配边界：

- `KCDomain`
- 未来的 `KC*Interface`
- `KCAppCompositionRoot`

这些决定模块之间如何协作。

### 5.2 产品核心

产品核心是画布体验：

- `KCDrawingEngine`
- `KCCanvasFeature`
- UIKit/Core Graphics 画布实现
- 贴纸、填色、取色、橡皮、撤销/重做、保存快照

画布核心不应为了架构形式被改成纯 SwiftUI。

## 6. 当前优先级

近期优先级：

1. 继续把 `KCMainViewController` 中低风险表现层逻辑拆成 App Feature。
2. 用 `scripts/validate_project.py` 固化 SPM 模块治理、文档同步和工程卫生检查。
3. 保存、草稿、历史删除、相册导入导出等高风险流程暂不下沉，先补协议边界和验收覆盖。
4. 后续新增用户、会员、素材、云同步等业务时，先建 `KC*Interface`，由 `KCAppCompositionRoot` 统一注入实现。
5. 仅当模块边界稳定、测试独立且复用需求明确时，再评估独立 package 或 Swinject。

## 7. 结论

KidCanvas 的演进方向不是“现在就上重型框架”，也不是“只做文档上的模块划分”。

当前最稳妥的路线是：

```text
一个本地 SPM package 多 target
+ Swift-first
+ Objective-C 清零
+ Feature 层落地
+ CompositionRoot 显式装配
+ Interface target 支撑未来业务模块
+ 边界稳定后再考虑独立 package 或 Swinject
```

这样既能支撑当前绘画 App 的低延迟核心体验，也能为未来用户、会员、素材、同步等业务模块留下清晰演进空间。
