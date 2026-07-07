# KCHistoryFeature

App 层历史 Feature：集中历史缩略图槽位状态推导、边框色映射和删除按钮可用性判定。位于 `KidCanvas/Features/History/KCHistoryFeature.swift`，不是独立 SPM target。

## 1. 职责

- 根据会话 id 列表、页码、当前活动会话、选中会话和脏态推导每个历史缩略图槽位状态。
- 委托 `KCDomain.KCHistoryPaging` 处理分页索引。
- 委托 `KCDomain.KCHistoryThumbStatus` 处理 active / selected / dirtyActive / empty 等状态优先级。
- 将槽位状态映射成 UIKit 边框色。
- 判定“删除历史”按钮在选中会话、历史会话或草稿存在时是否可用。
- `KCMainViewController.refreshHistoryUI()` 在应用草稿/历史缩略图时维护图片身份缓存；当同一槽位仍指向同一张草稿缩略图或同一会话缩略图时，跳过重复 `setBackgroundImage`，减少频繁刷新时的 UIKit 图片重设成本。
- `KCMainViewController.refreshHistoryUI()` 草稿槽位必须走 `KCSessionService.draftThumbnailImage()`；用户真正点击草稿时由 `draftPersistenceQueue + loadDraftData()` 后台读取和解码全尺寸图，避免历史刷新或草稿打开阻塞主线程。
- 启动首帧前 `refreshHistoryUI(..., loadSessions: false)` 不得读取 `sessions.json`；首帧后由 `refreshHistorySessionsAsync(...)` 通过 `KCSessionService.loadAllSessionsAsync(completion:)` 后台加载 metadata。
- `KCMainViewController.refreshHistoryUI()` 已保存缩略图只允许读取 `KCSessionService.cachedThumbnailImage(forSessionId:)` 的内存缓存；当前页缓存 miss 时必须隐藏默认 photo 占位图，仅保留稳定槽位背景，再通过 `preloadVisibleHistoryThumbnailsIfNeeded(_:)` 后台解码并回主线程以 `loadDraftThumbnail: false / preloadThumbnails: false / loadSessions: false` 刷新，避免翻到未缓存页面或点选时阻塞/闪烁，并避免预热回调再次触发同步草稿缩略图或 metadata 读取。
- 历史缩略图背景图必须同时应用到 normal / highlighted / selected / disabled 状态；用户按下或选中缩略图时不得回退到默认图片占位。
- `KCMainViewController.refreshHistoryUI()` 当前页刷新完成后，通过 `KCHistoryPaging.adjacentPageSessionIndexes()` 计算上一页/下一页候选，并交给 `KCSessionService.preloadThumbnailImages(forSessionIds:completion:)` 后台预热缩略图缓存，降低翻页时的主线程读盘/解码抖动。

## 2. 边界

- 不读取磁盘、不访问 `KCSessionService` 或 `KCSessionStore`。
- 不创建历史缩略图按钮，不设置缩略图背景图。
- 不执行打开历史、删除历史、草稿恢复或脏态保存流程。
- 不改变历史排序、session id、草稿策略或文件格式。
- 不决定“当前画布替换前是否要保留草稿”；该判断仍由 `KCMainViewController.preserveUnsavedActiveSessionDraftIfNeeded()` 结合活动会话、脏态和画布可见内容统一协调。

## 3. 对外 API / 接入路径

- `thumbStatus(sessionIds:pageIndex:pageSize:activeSessionId:selectedSessionId:isDirtyActive:thumbIndex:)`：返回槽位状态和绝对会话索引。
- `borderColor(for:)`：把 `KCHistoryThumbStatus` 映射为显示边框色。
- `canDeleteHistory(hasSelectedSession:sessionCount:hasDraft:)`：判定删除按钮可用性。
- 当前接入：`KCMainViewController.refreshHistoryUI()` 读取会话与草稿，再委托 `KCHistoryFeature` 计算按钮状态；真正打开/删除仍由主控制器协调。删除入口只需要判断草稿是否存在时，应走 `KCSessionService.hasDraft()`，避免为弹出删除确认框同步读取并解码整张草稿图。
- 当前接入：缩略图图片仍由 `KCSessionService` 提供缓存，控制器只用图片身份决定是否需要重新应用到按钮；状态判定继续委托 `KCHistoryFeature`。历史刷新不得为了当前页 miss 调用同步解码入口，应记录缺失 id 并投递后台预热；已保存槽位在 miss 期间必须显式关闭默认占位图。
- 当前接入：相邻页预热只计算 id 并投递后台任务，不直接修改按钮图片；真实 UI 更新仍由下一次 `refreshHistoryUI()` 读取缓存后统一完成。

## 4. 禁止回流规则

- 禁止把会话存储、草稿读写、打开历史或删除历史流程下沉到 `KCHistoryFeature`。
- 禁止在 `KCMainViewController` 重新复制历史槽位状态优先级；状态推导应继续委托本 Feature / KCDomain。
- 禁止改变分页、脏态保护或删除优先级而不补充对应测试和 validator。
- 禁止让历史 Feature 依赖具体视图控制器或 App Composition Root。
- 禁止只保护已保存会话的脏改动而跳过新画布草稿；历史打开、线稿加载和相册导入前都必须保留当前可见草稿。
- 禁止在 `refreshHistoryUI()` 中绕过图片身份缓存，对所有历史按钮无差别重复 `setBackgroundImage`。
- 禁止在 `refreshHistoryUI()` 中直接调用 `loadDraftImage()`；草稿槽位只能使用草稿缩略图入口。
- 禁止在 `refreshHistoryUI()` 中直接调用 `thumbnailImage(forSessionId:)`；已保存缩略图必须先走 cache-only 入口，缺失时后台预热后再刷新。
- 禁止已保存缩略图在 loading / highlighted / selected 状态露出默认 photo 占位图；只有空槽位和无草稿槽位可以展示占位符。
- 禁止在 `viewDidLoad` 或启动首帧前的历史刷新路径调用 `loadAllSessions()`；启动 metadata 加载必须通过 `loadAllSessionsAsync(completion:)`。
- 禁止把相邻页预热索引算法写在控制器循环里；分页/预热索引必须继续走 `KCHistoryPaging` 并有单测覆盖。
