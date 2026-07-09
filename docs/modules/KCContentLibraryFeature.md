# KCContentLibraryFeature

App 层内容库 Feature（T098 建立，T102 收口）：按需展开的内容库浮层面板，统一承载官方线稿、我的线稿、历史作品三个主分区（顺序固定：官方线稿 → 我的线稿 → 历史作品）；导入结果为预留分区（T100/T101 接入），不进入可见主分区顺序。源文件位于 `KidCanvas/Features/ContentLibrary/KCContentLibraryFeature.swift`（决策门面）与 `KCContentLibraryPanelView.swift`（浮层面板）；不是独立 SPM target。主控制器 `KCMainViewController` 负责数据装配（官方线稿来自 `KCLineArtFeature`、历史来自内存 `sessions`）、视图迁移与打开/删除事件协调。

## 1. 职责

- 持有内容库浮层的轻量 UI 状态：`isPanelVisible`（是否展开）与 `currentPartition`（当前分区）。
- 暴露分区能力与展示决策：`partitions()`、`sectionState(for:itemCount:)`、`canDelete(in:itemCount:)`、`isEmpty(partition:itemCount:)`，纯逻辑委托 KCDomain `KCContentLibraryPartition` / `KCContentLibrarySectionState`。
- 提供状态变更方法：`show()` / `hide()` / `toggleVisibility()` / `selectPartition(_:)`，均返回是否发生变化，便于控制器避免冗余刷新。
- `KCContentLibraryPanelView` 负责面板外观（半透明背景 + 卡片）、分段控件（官方线稿 / 我的线稿 / 历史作品）与三个分区容器的显隐切换、背景点按与关闭按钮关闭。
- T102 收口：
  - 分区顺序固定为 官方线稿 → 我的线稿 → 历史作品（`KCContentLibraryPartition.defaultOrder`）；导入结果 `.imports` 为预留分区，不在 `defaultOrder` 内、`isMainPartition == false`，不得打乱三个主分区。
  - 每个分区空态走本地化：我的线稿“还没有我的线稿”、历史作品“还没有历史作品”（无已保存会话且无草稿时显示并隐藏 `historyPanel` 栅格）、导入结果“还没有导入内容”（预留）。空态可见性由数据驱动，经 `KCContentLibraryFeature` / KCDomain 决策口径。
  - 历史作品默认按最近修改时间倒序展示（由 `KCSessionStore.loadSessions()` 落实）。
  - iPhone / iPad 均采用可关闭覆盖层浮层（不长期压缩画布）；画布“恢复视图”按钮独立约束，内容库开关不影响其位置稳定性。

## 2. 边界

- 不读取 `KCSessionService` / `KCSessionStore` 磁盘格式，不生成线稿，不持有系统 picker（与 `KCHistoryFeature` 一致）。
- 不创建线稿缩略图按钮、不创建历史缩略图；这些视图由控制器构建并装入对应容器。
- 不决定“打开/删除”的具体执行；控制器协调 `loadLineArtItem`、`openSession`、`deleteSavedHistorySession` 等。
- 我的线稿与导入结果分区本轮为预留空态：真实数据源（`KCCustomLineArtStore` / `KCImageImportService`）在 T099/T100/T101 接入；本 Feature 不应在本任务写成已落地能力。
- 历史数量上限 / 清理策略口径（T102）：MVP 不实现自动清理；建议软上限约 200 个历史作品，超出后应提示用户手动清理；自动清理列为后续任务，不在本 Feature 强制执行。
- 内容库内“从相册导入 / 拍照导入”入口与顶部导入保持同一行为口径（均走 `didTapImportImage` 链路，真实拍照/统一导入服务在 T100 接入）；不在 UIKit view 内硬编码第二套导入状态。
- 不下沉为 SPM target；待边界稳定后再评估（遵守“单本地 package、多 target”原则）。

## 3. 对外 API / 接入路径

- `KCContentLibraryFeature`：`show()` / `hide()` / `toggleVisibility()` / `selectPartition(_:)` / `canDelete(in:itemCount:)` / `isEmpty(partition:itemCount:)` / `partitions()` / `defaultPartition`。
- `KCContentLibraryPanelView`：`officialLineArtContainer` / `myLineArtContainer` / `historyContainer`（控制器装配内容）；`setSegmentTitle(_:forPartitionAt:)` / `setMyLineArtEmptyText(_:)` / `setHistoryEmptyVisible(_:text:)` / `isHistoryEmptyVisible` / `showPartition(index:)`；`onPartitionChange` / `onClose` 回调。
- `KCMainViewController.refreshContentLibraryHistoryEmpty(hasDraft:)`：由 `refreshHistoryUI` 在计算出 `hasDraft` 后调用，按 `sessions.isEmpty && !hasDraft` 切换历史分区空态与 `historyPanelView` 显隐。
- 当前接入：`KCMainViewController` 顶栏右入口 `contentLibraryButton` → `didTapContentLibrary` → `setContentLibraryPanelVisible(_:)`；`setupContentLibraryPanel(historyPanel:)` 装配浮层：把 `historyPanel` 装入 `historyContainer`（从原右侧 `rightStack` 迁出），内嵌 `KCLineArtPickerViewController` 到 `officialLineArtContainer`（线稿弹窗并入官方线稿分区），分段标题来自 `contentLibrarySegmentTitle(for:)`，我的线稿/历史分区为空态文案。

## 4. 禁止回流规则

- 禁止把 UIKit 类型下沉到 `KCContentLibraryPartition` / `KCContentLibrarySectionState`；状态模型必须 UIKit-free。
- 禁止重新引入独立的线稿弹窗入口（`didTapLineArtPicker` popover）；官方线稿只能通过内容库分区浏览（validator 守护主控制器不含 `func didTapLineArtPicker()`）。
- 禁止把 `historyPanel` 重新塞回右侧常驻 `rightStack`；历史作品只能通过内容库历史分区浏览（validator 守护 `rightStack.addArrangedSubview(historyPanel)` 不回归）。
- 禁止让官方线稿分区出现删除入口；官方线稿 `allowsDelete == false` 由 KCDomain 与单测守护。
- 禁止把内容库写成多页面跳转；内容库必须在当前页面内按需展开（PRD §6.3）。
- 禁止把“我的线稿 / 导入结果”预留分区写成已落地数据源；真实存储在 T099/T100/T101 接入。
- 禁止让内容库浮层遮挡时仍允许其下层工具面板误触；浮层显示时置顶并带半透明背景。
- 禁止在内容库 Feature 里复制 `KCSessionService` / `KCLineArtFeature` 的数据读取逻辑；只做编排与决策。
- T102：禁止改变主分区固定顺序（官方线稿 → 我的线稿 → 历史作品），禁止把预留 `.imports` 加入 `defaultOrder`（validator + 单测守护）。
- T102：禁止把分区空态文案硬编码在 UIKit view 内或漏掉本地化；空态必须经 `KCContentLibrarySectionState.emptyStateLocalizationKey` + `KCL10n`。
- T102：禁止让历史作品改回非倒序展示；`KCSessionStore.loadSessions()` 必须按 `modifiedAt` 倒序（validator 守护）。
- T102：禁止在内容库内引入与顶部导入冲突的第二套导入视觉/状态口径；导入入口行为必须一致。
