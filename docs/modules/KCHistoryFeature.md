# KCHistoryFeature

App 层历史 Feature：集中历史缩略图槽位状态推导、边框色映射和删除按钮可用性判定。位于 `KidCanvas/Features/History/KCHistoryFeature.swift`，不是独立 SPM target。

## 1. 职责

- 根据会话 id 列表、页码、当前活动会话、选中会话和脏态推导每个历史缩略图槽位状态。
- 委托 `KCDomain.KCHistoryPaging` 处理分页索引。
- 委托 `KCDomain.KCHistoryThumbStatus` 处理 active / selected / dirtyActive / empty 等状态优先级。
- 将槽位状态映射成 UIKit 边框色。
- 判定“删除历史”按钮在选中会话、历史会话或草稿存在时是否可用。

## 2. 边界

- 不读取磁盘、不访问 `KCSessionService` 或 `KCSessionStore`。
- 不创建历史缩略图按钮，不设置缩略图背景图。
- 不执行打开历史、删除历史、草稿恢复或脏态保存流程。
- 不改变历史排序、session id、草稿策略或文件格式。

## 3. 对外 API / 接入路径

- `thumbStatus(sessionIds:pageIndex:pageSize:activeSessionId:selectedSessionId:isDirtyActive:thumbIndex:)`：返回槽位状态和绝对会话索引。
- `borderColor(for:)`：把 `KCHistoryThumbStatus` 映射为显示边框色。
- `canDeleteHistory(hasSelectedSession:sessionCount:hasDraft:)`：判定删除按钮可用性。
- 当前接入：`KCMainViewController.refreshHistoryUI()` 读取会话与草稿，再委托 `KCHistoryFeature` 计算按钮状态；真正打开/删除仍由主控制器协调。

## 4. 禁止回流规则

- 禁止把会话存储、草稿读写、打开历史或删除历史流程下沉到 `KCHistoryFeature`。
- 禁止在 `KCMainViewController` 重新复制历史槽位状态优先级；状态推导应继续委托本 Feature / KCDomain。
- 禁止改变分页、脏态保护或删除优先级而不补充对应测试和 validator。
- 禁止让历史 Feature 依赖具体视图控制器或 App Composition Root。
