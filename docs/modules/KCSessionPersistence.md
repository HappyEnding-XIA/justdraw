# KCSessionPersistence

本地会话持久化模块：实现作品、缩略图、草稿和元数据的文件系统存储。位于 `Packages/KidCanvasModules/Sources/KCSessionPersistence`，依赖 `KCDomain` 和 `KCCommon`。

## 1. 职责

- 实现 `KCSessionRepository`，提供历史会话加载、保存、删除、草稿保存/加载/清理能力。
- 维护与旧 Objective-C 原型一致的磁盘布局：`KidCanvasSessions`、`<uuid>.png`、`<uuid>-thumb.jpg`、`draft.png`。
- 使用 `sessions.json` 保存元数据，并保留 `sessions.archive` 旧格式迁移接口。
- 在保存失败时回滚 artwork / thumbnail 文件，避免元数据指向缺失文件。
- 提供 `KCLegacySessionMigrator` 协议，由 App 层在需要时注入旧 archive 解码能力。

## 2. 边界

- 不依赖 UIKit，不生成 `UIImage`，只处理 PNG / JPEG `Data`。
- 不负责相册导入导出，不处理权限。
- 不负责缩略图绘制尺寸决策；App 层服务生成缩略图数据后交给 repository。
- 不知道 `KCMainViewController`、画布视图、历史按钮或草稿提示 UI。

## 3. 对外 API / 接入路径

- `KCSessionStore()`：默认以 Documents 下的 `KidCanvasSessions` 作为根目录。
- `KCSessionStore(directoryURL:legacyMigrator:now:makeID:fileManager:)`：测试或定制目录时使用。
- `loadSessions()`：返回按 `modifiedAt` 新到旧排序的 `KCArtworkSession`。
- `saveArtwork(pngData:thumbnailJPEGData:existing:)`：创建或更新作品会话。
- `artworkData(for:)` / `thumbnailData(for:)`：读取作品与缩略图载荷。
- `delete(_:)`：删除会话及其关联文件。
- `saveDraft(pngData:)` / `loadDraft()` / `clearDraft()`：草稿生命周期。
- App 接入路径：`KCAppCompositionRoot` 构造 `KCSessionService`，再由 `KCMainViewController` 调用服务层方法。

## 4. 禁止回流规则

- 禁止把 UIKit 图片对象、按钮状态、历史面板状态或保存 Toast 逻辑放入 `KCSessionPersistence`。
- 禁止改变既有磁盘布局、文件名或 `sessions.json` schema，而不单独立迁移任务和测试。
- 禁止绕过 `KCSessionRepository` 在 App 层直接复制一套会话文件读写。
- 禁止在保存失败路径放弃回滚策略。
