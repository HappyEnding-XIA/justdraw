# KCSessionPersistence

本地会话持久化模块：实现作品、缩略图、草稿和元数据的文件系统存储。位于 `Packages/KidCanvasModules/Sources/KCSessionPersistence`，依赖 `KCDomain` 和 `KCCommon`。

## 1. 职责

- 实现 `KCSessionRepository`，提供历史会话加载、保存、删除、草稿保存/加载/清理能力。
- 维护与旧 Objective-C 原型一致的磁盘布局：`KidCanvasSessions`、`<uuid>.png`、`<uuid>-thumb.jpg`、`draft.png`。
- 使用 `sessions.json` 保存元数据，并保留 `sessions.archive` 旧格式迁移接口。
- 在保存失败时通过同目录临时回滚文件恢复 artwork / thumbnail，避免元数据指向缺失文件，也避免为了回滚把旧大图读入内存；恢复旧文件使用 replace/move，不先删除当前文件，恢复失败时保留 `.rollback` 备份以便排查。
- 删除会话时先更新 `sessions.json`，成功后再清理 PNG/JPEG 文件；metadata 写失败时不能先删作品文件，避免历史元数据指向缺失图片。
- 提供 `KCLegacySessionMigrator` 协议，由 App 层在需要时注入旧 archive 解码能力。

## 2. 边界

- 不依赖 UIKit，不生成 `UIImage`，只处理 PNG / JPEG `Data`。
- 不负责相册导入导出，不处理权限。
- 不负责缩略图绘制尺寸决策；App 层服务生成缩略图数据后交给 repository。
- 不知道 `KCMainViewController`、画布视图、历史按钮或草稿提示 UI。
- App 层 `KCSessionService` 可缓存已解码的历史缩略图 `UIImage`、草稿 `UIImage` 与已加载的会话元数据列表，但缓存只属于服务适配层；草稿缓存和 metadata 缓存必须加锁以支撑后台读写，底层 `KCSessionPersistence` 仍只暴露稳定的 Domain / PNG / JPEG `Data` 读写能力。

## 3. 对外 API / 接入路径

- `KCSessionStore()`：默认以 Documents 下的 `KidCanvasSessions` 作为根目录。
- `KCSessionStore(directoryURL:legacyMigrator:now:makeID:fileManager:)`：测试或定制目录时使用。
- `loadSessions()`：返回按 `modifiedAt` 新到旧排序的 `KCArtworkSession`。
- `saveArtwork(pngData:thumbnailJPEGData:existing:)`：创建或更新作品会话。
- `artworkData(for:)` / `thumbnailData(for:)`：读取作品与缩略图载荷。
- `delete(_:)`：删除会话及其关联文件。
- `saveDraft(pngData:)` / `loadDraft()` / `hasDraft()` / `clearDraft()`：草稿生命周期；`hasDraft()` 只能做文件存在性判断，不得读取或解码 `draft.png`。
- App 接入路径：`KCAppCompositionRoot` 构造 `KCSessionService`，再由 `KCMainViewController` 调用服务层方法。
- `KCSessionService.encodedArtworkData(from:)`：集中生成正式保存所需的 PNG 与 240×180 JPEG 缩略图数据；该入口不读写磁盘和缓存，可由 `KCMainViewController` 放到后台队列执行。
- `KCSessionService.thumbnailImage(forSessionId:)`：面向 UIKit 历史栏的便捷入口，会先确认会话仍存在，再优先返回内存缓存；`saveArtwork` 成功后刷新对应缩略图缓存，`deleteSession` 调用后会移除对应缓存。
- `KCSessionService.cachedThumbnailImage(forSessionId:)`：只读取内存缓存，不触发磁盘读取或图片解码；`KCMainViewController.refreshHistoryUI()` 必须使用该入口刷新当前页已保存缩略图，缓存 miss 时先显示占位。
- `KCSessionService.preloadThumbnailImages(forSessionIds:completion:)`：在 utility 后台队列预热历史缩略图缓存；已缓存或正在预热的 id 不得重复排队，避免历史面板频繁刷新时造成重复读盘/解码；completion 回主线程执行，用于当前页 miss 解码完成后刷新 UI。
- `KCSessionService.loadAllSessions()` / `sessionCount()` / `hasSavedSessions()` / `findSession(id:)`：共享服务层会话元数据缓存，避免历史栏刷新和缩略图读取反复解码 `sessions.json`；服务层 cache 必须加锁，保存成功后替换缓存中的最新会话，删除成功后移除对应会话。
- `KCSessionService.loadAllSessionsAsync(completion:)`：启动后的历史栏首次 metadata 加载必须走后台 `sessionMetadataQueue`，完成后回主线程刷新 UI，避免主线程首次读取 `sessions.json`。
- `KCSessionService.artworkData(forSession:)`：用于用户点开已保存作品时按已加载的 `KCSessionMetadata` 读取原图 Data；UI 层必须在 `KCMainViewController.artworkLoadingQueue` 后台调用并在后台完成 `UIImage(data:)` 解码，主线程只应用已解码图片。
- `KCSessionService.saveArtwork(pngData:thumbnailJPEGData:existingSessionId:)`：更新已有会话时必须通过 `findSession(id:)` 复用服务层 metadata cache，不再为了解析 existing session 额外读取 `sessions.json`。
- `KCSessionService.loadDraftImage()`：仅保留为低频同步兼容入口，不作为编辑器打开草稿的主路径；`KCMainViewController.didTapDraftThumb()` 和启动期 `restoreDraftIfNeeded()` 必须在 `draftPersistenceQueue` 后台读取 `loadDraftData()` 并后台执行 `UIImage(data:)`。
- `KCSessionService.draftThumbnailImage()`：面向历史面板的轻量入口，优先返回加锁保护的 `draftThumbnailCache`；自动保存或替换前草稿保护成功时用快照刷新缩略图缓存，历史面板不得为了显示 240×180 草稿槽位直接调用 `loadDraftImage()`。
- `KCSessionService.hasDraft()`：用于删除按钮可用性和删除流程的轻量草稿存在性判断；当只需要知道草稿是否存在时，不得调用 `loadDraftImage()` 触发同步读盘和图片解码。
- 正式保存流程先由 `KCMainViewController` 在主线程生成画布快照，再把 PNG/JPEG 编码放入 `sessionEncodingQueue`；回主线程确认 `sessionSaveGeneration` 仍有效后，才调用 `saveArtwork(pngData:thumbnailJPEGData:existingSessionId:)` 更新磁盘、缓存、历史和相册输出。
- App 层自动草稿保存先由 `KCMainViewController` 在主线程生成画布快照，再把 PNG 编码合并到后台队列；正式写入前必须通过 generation guard 确认任务仍有效，避免旧后台任务在清空/替换画布后复活旧草稿，同时用当前快照刷新草稿缩略图缓存，不长期持有全尺寸自动保存图。
- 历史栏当前页缩略图 miss 时，`KCMainViewController` 只能记录缺失 session id 并调用 `preloadVisibleHistoryThumbnailsIfNeeded(_:)`；后台预热完成后再统一刷新 UI，禁止在刷新循环中同步读盘/解码。
- 启动首帧前不得同步读取会话 metadata；`viewDidLoad` 只能用当前内存 `sessions` 渲染空历史槽位，首帧后由 `refreshHistorySessionsAsync(loadDraftThumbnail:preloadThumbnails:)` 后台加载 metadata，再回主线程调用 `refreshHistoryUI(..., loadSessions: false)`。
- 用户真正打开已保存作品或草稿时，也不得在主线程读取完整 PNG 或执行 `UIImage(data:)`；历史作品走 `artworkLoadingQueue + artworkData(forSession:)`，草稿走 `draftPersistenceQueue + loadDraftData()`，并统一通过 `artworkLoadGeneration` 丢弃过期后台结果。
- 线稿、历史和相册导入替换当前画布前，App 层必须调用草稿保护逻辑；新画布草稿和已保存作品的脏改动都应保留下来。若 `activeDraftMatchesCanvas` 表明当前画布已被最近一次草稿保存覆盖，则直接复用现有草稿；否则主线程只允许截图，PNG 编码和 `saveDraftData(pngData:cachedImage:)` 必须通过 `draftPersistenceQueue` 后台执行。
- 替换前草稿保护使用独立 `draftProtectionGeneration`，清草稿时必须让待完成的保护任务失效；保护任务完成后只刷新历史草稿缩略图，不得把已经被新画布替换的当前画布重新标记为 `activeDraftMatchesCanvas = true`。
- App 层所有清草稿入口必须通过 `KCMainViewController.clearDraftAndInvalidateCurrentDraftMarker()`，由该 helper 同时让待完成的草稿保护失效、调用 `KCSessionService.clearDraft()` 并把 `activeDraftMatchesCanvas` 置回 `false`；禁止业务路径直接调用 `sessionStore.clearDraft()` 后遗漏状态失效。

## 4. 禁止回流规则

- 禁止把 UIKit 图片对象、按钮状态、历史面板状态或保存 Toast 逻辑放入 `KCSessionPersistence`。
- 禁止改变既有磁盘布局、文件名或 `sessions.json` schema，而不单独立迁移任务和测试。
- 禁止绕过 `KCSessionRepository` 在 App 层直接复制一套会话文件读写。
- 禁止在保存失败路径放弃回滚策略。
- 禁止在 `saveArtwork` 中为了失败回滚使用 `Data(contentsOf:)` 读取旧 artwork / thumbnail；旧文件必须走文件级备份与 replace/move 恢复，降低大图更新时的内存峰值，并避免恢复失败时先删除当前文件造成二次数据丢失。
- 禁止删除会话时先删 PNG/JPEG 再写 metadata；必须先写入不含该 session 的 `sessions.json`，成功后再尽力清理文件。
- 禁止历史栏刷新当前页时调用会触发磁盘读取/解码的 `thumbnailImage(forSessionId:)`；该入口只留给明确需要同步取得图片的低频路径。
- 禁止让 `KCSessionPersistence` 感知编辑器 generation、自动保存 timer 或画布替换时机；这些属于 App 层协调职责。
- 禁止把正式保存的 PNG/JPEG 编码重新塞回 `didTapSaveSession()` 主线程同步路径；编码必须复用 `KCSessionService.encodedArtworkData(from:)` 并通过 generation guard 回主线程提交。
- 禁止在 `KCMainViewController` 业务路径直接调用 `sessionStore.clearDraft()`；统一走 `clearDraftAndInvalidateCurrentDraftMarker()`，保证磁盘草稿和 `activeDraftMatchesCanvas` 状态不会分叉。
- 禁止在 `preserveUnsavedActiveSessionDraftIfNeeded()` 中调用 `saveDraftImage(_:)` 或在主线程执行 PNG 编码/草稿写盘；替换画布前的草稿保护必须返回“已安排保护”并由后台队列落盘。
