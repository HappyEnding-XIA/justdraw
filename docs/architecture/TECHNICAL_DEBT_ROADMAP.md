# KidCanvas 技术债治理路线图

## 1. 目标

本文把当前已识别的技术债拆成可执行阶段，作为后续看板任务和验收记录的来源。

治理原则：

- 不为架构洁癖重写核心链路。
- 不在同一任务中混合性能、架构和产品行为变更。
- 高风险流程先补验收，再动实现。
- 每个技术债任务完成后，同步更新模块文档或架构文档。

## 2. 当前优先级

### P0：交付人工验收

范围：

- iPhone / iPad 双端 F01-F12 人工点验。
- 系统相册权限弹窗、选图、保存到相册。
- 系统取色器真实弹窗与颜色回填。
- 印章真实捏合、旋转、删除、撤销、重做。

原因：

自动验收已经覆盖主要代码路径，但系统弹窗、真实触控和视觉观感仍需要人工确认。

验收口径：

- 回填 `docs/testing/MANUAL_ACCEPTANCE_RUNBOOK_2026-07-06.md`。
- 若发现问题，先记录缺陷和设备，再拆成单独任务。

### P1：继续拆薄 `KCMainViewController`

已完成：

- 工具辅助类型。
- 设备布局指标代理。
- 面板收起协调。
- 工具、画笔、颜色、橡皮和印章选择协调。
- 历史 UI 刷新、分页、缩略图占位与预热协调。
- 相册导入入口、picker 配置、后台图片归一化和导入完成回调协调。
- 草稿自动保存、启动草稿恢复、替换前草稿保护和打开草稿协调。
- Debug 运行时验收探针。
- 正式保存、保存 generation guard 和相册 best-effort 导出协调。

后续顺序：

1. `KCMainViewController+LineArtLoading.swift`
2. `KCMainViewController+HistoryDeletion.swift`

验收口径：

- 只搬代码位置时必须保持行为不变。
- 每刀都跑 `validate_project.py`、双端构建、`swift test --package-path Packages/KidCanvasModules`。
- 涉及保存、草稿、历史、相册时必须补运行时验收或人工验收记录。

### P2：flood fill 主线程卡顿

现状：

- 填色算法已经下沉到 `KCDrawingEngine`。
- App 仍在用户触发路径同步执行填色。

治理方案：

1. 先补大画布填色性能基线测试，记录耗时阈值。
2. 再将 App 层填色触发改为可取消的异步任务。
3. UI 层补忙碌态与重复点击保护。

不做：

- 不直接把整个画布重写为 SwiftUI Canvas。
- 不把性能优化和 UI 重构混在一个提交里。

验收口径：

- `KCDrawingEngine` 性能测试有明确阈值。
- iPhone / iPad 填色运行时验收通过。
- 用户连续点填色不会造成状态错乱。

### P3：undo 快照内存增长

现状：

- 当前 undo/redo 以画布快照为主，行为稳定但内存增长风险较高。

治理方案：

1. 先增加 undo/redo 内存与容量基线记录。
2. 评估 command log + checkpoint 混合模型。
3. 先在 `KCDomain` 定义可测试的历史策略模型，再接入 App。

验收口径：

- 多次绘制、印章、填色、导入后撤销重做行为不回退。
- 内存增长有可观测指标。
- 历史格式兼容旧会话。

### P4：内容素材继续配置化

现状：

- 色盘、印章、线稿元数据已进入 `KCContentCatalog`。
- 部分视觉资源和运行时演示内容仍由 App 代码组合。

治理方案：

1. 扩展 content JSON schema，给素材增加版本、分组、展示尺寸和本地化 key。
2. 将更多内置素材迁入 package resource 或 asset catalog。
3. 保持 App 只消费 `KCContentCatalog` 提供的 DTO。

验收口径：

- JSON schema 单测覆盖异常数据。
- 新增素材不需要修改 `KCMainViewController`。
- 中英文文案 key 对齐。

### P5：真机签名与发布准备

现状：

- 当前以模拟器自动验收为主。
- 证书和描述文件仍需人工配置。

治理方案：

1. 配置 Development Team、Bundle ID、开发证书和描述文件。
2. 首轮只开启必要能力：相册读取 / 写入权限通过 Info.plist 文案声明，不需要额外 Capabilities。
3. 真机跑启动、绘制、保存、相册、取色、Apple Pencil。

验收口径：

- 真机安装成功。
- 相册读写权限文案正确。
- iPad 横屏默认行为符合产品要求。

## 3. 执行规则

- 技术债任务必须小步提交。
- 每个任务的 commit message 使用中文描述，并保留 `【xiaoda】` 前缀。
- 如需修改模块边界，先更新 `docs/architecture/MODULAR_ARCHITECTURE_DESIGN.md`。
- 如新增 App Feature 或 SPM target，必须同步 `docs/modules/` 文档。
- 提交前清理 `._*` 元数据文件。
