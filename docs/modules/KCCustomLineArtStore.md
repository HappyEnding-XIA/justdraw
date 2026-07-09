# KCCustomLineArtStore

“我的线稿”本地持久化（T099）：位图线稿（不做矢量化）的保存、读取、删除与数量上限。源文件 `Packages/KidCanvasModules/Sources/KCDomain/KCCustomLineArt.swift`（UIKit-free 模型 + `KCCustomLineArtRepository` 协议）与 `Packages/KidCanvasModules/Sources/KCSessionPersistence/KCCustomLineArtStore.swift`（文件实现）。App 适配层为 `KidCanvas/Infrastructure/KCCustomLineArtService.swift`，内容库“我的线稿”分区网格为 `KidCanvas/Features/ContentLibrary/KCMyLineArtGridView.swift`。

## 1. 职责

- 持久化我的线稿元数据（`KCCustomLineArt`：id、`sequenceNumber`、lineArt/thumbnail 文件名、createdAt、sourceKind、可选 sourceSessionId）+ 位图 PNG + 缩略图 JPEG。
- 磁盘布局独立于历史会话：`Documents/KidCanvasCustomLineArt/`、`custom-line-arts.json`（Codable，schema 版本化）、`<id>.png`、`<id>-thumb.jpg`。
- 自动命名：`sequenceNumber` 取现有最大编号 + 1（无则 1），保证删除后不重号、稳定可读；展示文案“我的线稿 N”由 App 层本地化格式化（不在 store 写中文字面量）。
- 数量上限 `maxItemCount = 50`：达到上限时 `save` 返回 `nil`，由 App 层提示清理。
- 保存中途失败回滚图像文件，避免元数据指向缺失线稿；`@unchecked Sendable` + `NSLock` 保证并发安全。
- 历史默认按 `createdAt` 倒序加载（最新在前）。

## 2. 边界

- 删除一条我的线稿只删线稿库条目本身（独立目录），**不影响**基于该线稿保存过的历史作品（`KCSessionStore` 独立）。
- 不做矢量化、不生成线稿（位图来自 App 层 `KCDrawingCanvasView.lineArtImage()`）、不依赖 UIKit（协议与模型在 KCDomain；图像载荷以 `Data` 交换）。
- 不持有缩略图缓存、不做主线程解码；这些在 App 适配层 `KCCustomLineArtService`。
- 不与照片生成线稿（T101）耦合：`sourceKind = .photoExtraction` 为预留枚举值，T099 仅产出 `.canvasSave`。

## 3. 对外 API / 接入路径

- `KCCustomLineArtRepository`（KCDomain）：`loadAll() / save(lineArtPNG:thumbnailJPEG:sourceKind:sourceSessionId:) / lineArtData(for:) / thumbnailData(for:) / delete(_:) / count()`。
- `KCCustomLineArtStore`（KCSessionPersistence）：`init()`（Documents 根）与 `init(directoryURL:now:makeID:...)`（测试）。
- App 适配 `KCCustomLineArtService`：`loadAll() / saveLineArt(image:sourceKind:sourceSessionId:completion:) / lineArtImage(forId:) / thumbnailImage(forId:) / cachedThumbnailImage(forId:) / preloadThumbnailImages(forIds:completion:) / deleteLineArt(withIdentifier:) / count() / hasReachedCap() / maxItemCount`；DTO `KCCustomLineArtMetadata`（title 经 `KCL10n.customLineArtTitle(n)`）。
- 当前接入：`KCAppCompositionRoot` 装配 `KCCustomLineArtService` 并构造注入 `KCMainViewController`；内容库“我的线稿”分区由 `KCMyLineArtGridView` 展示，`KCMainViewController` 负责 `refreshCustomLineArt / didTapSaveAsLineArt（strokeCount 校验 + 上限 + `lineArtImage` 线稿化）/ loadCustomLineArt（`canvasView.loadLineArtImage` + `.fill`）/ confirmDeleteCustomLineArt（二次确认）`。

## 4. 禁止回流规则

- 禁止把 UIKit 类型下沉到 `KCCustomLineArt` / `KCCustomLineArtRepository`；模型与协议必须 UIKit-free。
- 禁止在 store/模型里硬编码中文标题（如“我的线稿”）；命名必须经 `sequenceNumber` + App 层 `KCL10n`（validator 守护 store 不含“我的线稿”）。
- 禁止删除我的线稿影响历史作品；两者必须独立目录、独立元数据（`KidCanvasCustomLineArt/` ≠ `KidCanvasSessions/`）。
- 禁止把我的线稿改回非倒序展示；`loadAll()` 必须按 `createdAt` 倒序。
- 禁止绕过软上限 `maxItemCount = 50`；达到上限必须拒绝新增并由 App 层提示（validator + 单测守护）。
- 禁止在保存为线稿时跳过最小笔画校验直接入库；必须先经 `strokeCount` 门与 `lineArtImage()` 线稿化，避免完整彩色画面直接入库（PM §5.6）。
- 禁止删除我的线稿不二次确认（PM §5.10）。
- 禁止把照片生成线稿（T101）的 pipeline 混入本 store；T099 只产出 `.canvasSave`。
