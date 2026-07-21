# T116 画笔性能与蜡笔形态稳定设计

## 1. 状态

- 日期：2026-07-21
- 状态：代码与自动化验收已完成，待老款实体 iPad 性能/手势验收
- 执行者：Codex
- 适用范围：iPhone 与 iPad，横屏优先
- 明确不包含：T108 AI 增强线稿、Metal 重写、保存格式或历史 schema 变更

## 2. 问题与复现

实际使用反馈包含两个相互关联的问题：

1. 铅笔和蜡笔持续绘制时出现卡顿，画布缩放、平移和页面操作不够流畅。
2. 画布放大或缩小后继续使用蜡笔绘制，笔画会向四周分叉，呈现“爆炸形态”。

已确认最稳定的视觉复现路径为：先改变 viewport 缩放，再继续创建新的蜡笔笔画。

现有 `brush-perf` 探针只测试纯 dab 生成：iPad Pro 11 M4 模拟器上，126 个采样的代表性铅笔笔画生成 100 次约 49 ms、300 次约 162 ms。该探针没有覆盖触摸移动期间的重复生成、Core Graphics 光栅化、历史笔画重放和 viewport 重绘，因此不能证明实际交互流畅。

## 3. 根因

### 3.1 活动笔画重复全量生成

`touchesMoved` 每次追加采样后都会调用 `invalidateStrokeRenderBounds(_:)`，同时清空 `cachedDabs`。随后 `strokeRenderBounds(_:)` 立即对当前笔画的全部 `samples` 重新生成 dab，并再次遍历全部 dab 计算包围盒。

因此一条包含 n 个采样的长笔画会重复处理 `1 + 2 + ... + n` 个采样，实际复杂度接近 O(n²)。旧边界与新边界又都是整条活动笔画的累计边界，脏区会随笔画增长，导致每帧重绘面积不断扩大。

### 3.2 viewport 变化重放全部历史笔画

`draw(_:)` 在每次 viewport 缩放和平移刷新时遍历 `strokes`，重新绘制所有历史 path 或 dab。蜡笔包含大量半透明 stamp；历史越长，单帧工作量越大。

工作台背景、纸张阴影和径向氛围光也位于同一高频 `draw(_:)` 路径，进一步占用触摸帧预算。

### 3.3 蜡笔使用宏观几何抖动制造纹理

蜡笔 preset 当前 `jitter = 0.18`，dab 中心偏移为 `jitter × radius`。该偏移位于内容坐标空间，最终还会经过 viewport 变换。缩放后继续绘制时，中心偏移在屏幕上被同步放大，容易从粗糙边缘变成可见分叉。

蜡笔粗糙度应主要来自局部颗粒和纸纹，不应依赖大幅中心位移。

### 3.4 UIKit 渲染忽略每个 dab 的纹理种子

`KCBrushDabGenerator` 已为每个 dab 生成独立 `seed`，但 `drawDabs` 当前只按 preset 的固定 `textureSeed` 取得一张 brush-tip 图片。所有 dab 重复相同纹理，在高倍率下会显露为重复的放射状 stamp，并放大分叉观感。

### 3.5 状态恢复丢失 dab 数据

`copyOfStroke(_:)` 没有复制 `samples` 和 `cachedDabs`。撤销、重做或状态恢复后的铅笔/蜡笔会退回旧 path 渲染，导致同一笔画在操作前后形态不一致。该问题不是本次 B 路径的首要触发点，但必须一并修复，否则性能缓存和视觉稳定无法形成闭环。

## 4. 目标

1. 缩放到 50%、100%、200%、300% 后继续绘制蜡笔，笔画保持连续，不出现向外分叉或爆裂形态。
2. 活动笔画追加采样时只处理新增段，不重新生成整条 dab 序列。
3. viewport 缩放和平移不再逐帧重放所有已完成笔画。
4. 撤销、重做和状态恢复前后，铅笔/蜡笔的 dab 形态保持一致。
5. 保持画笔尺寸为内容坐标语义，不因缩放改成屏幕固定尺寸。
6. 不回退填色、取色、橡皮、印章、保存、草稿和历史恢复能力。

## 5. 方案选择

### 方案 A：仅降低蜡笔 jitter

优点是改动小，能够缓解分叉。缺点是长笔画 O(n²) 和缩放时全历史重放仍然存在，无法解决页面不流畅。

### 方案 B：增量 dab + 纹理变体 + 完成笔画缓存

同时解决活动笔画重复计算、蜡笔宏观分叉、纹理重复和 viewport 全历史重放。改动集中在 `KCDrawingEngine` 和 `KCDrawingCanvasView`，不改变保存 schema。该方案为本次选定方案。

### 方案 C：Metal 绘制后端

性能上限最高，但需要重做绘制、橡皮、填色、取色、快照和历史协作，不适合当前阶段。

## 6. 详细设计

### 6.1 增量 dab 生成状态

在 `KCDrawingEngine` 增加 UIKit-free 的增量生成状态，保存：

- 上一个输入采样；
- 跨 segment 保留的 residual distance；
- 下一个 dab index；
- 当前 preset 与 canvas scale 的稳定配置。

保留现有 `dabs(for:)` 全量 API 作为兼容入口，并让它复用同一增量核心。新增 API 接收一批新采样和旧状态，只返回新增 dab 与新状态。

`KDStroke` 在活动期间保存该状态。`touchesBegan` 初始化首个 dab；`touchesMoved` 只追加 coalesced touches 对应的新 dab；`touchesEnded` 处理末尾采样并封存。已完成笔画保留完整 `samples` 与完整 `cachedDabs`，不再需要增量状态。

### 6.2 局部脏区

活动笔画维护累计 `cachedRenderBounds`，但每次刷新只使用：

`上一批新增 dab 边界 ∪ 本批新增 dab 边界`

不再用整条活动笔画边界作为每帧脏区。累计边界仅用于历史命中、最终缓存和完整重绘。

### 6.3 完成笔画 raster 缓存

复用并明确 `nonStickerRasterCacheImage` 为“背景图 + 已完成笔画”的内容坐标缓存：

- `draw(_:)` 在 viewport 变换后只绘制缓存图和当前活动笔画；
- 活动笔画抬笔后合成进缓存；
- 新建、换图、填色、清空、undo/redo、bounds 改变时使缓存失效；
- 缓存失效后的第一次绘制允许完整重建一次，后续 viewport 帧只变换位图；
- 印章继续作为 UIKit 子视图，不进入该缓存；
- 保存、草稿和取色继续复用同一非印章内容语义。

缓存按设备屏幕 scale 生成，不跟随 viewport scale 重建，避免捏合过程中反复分配大图。viewport 只负责显示变换；后续如确认 300% 下需要更高分辨率，单独评估松手后的异步高分辨率重建，不纳入 T116。

### 6.4 静态工作台层与视口预览

工作台底色和氛围光缓存为独立背景位图，缓存键由 view bounds、设备 scale 和 trait collection 构成；纸张阴影缓存键由内容尺寸和 scale 构成。viewport 手势期间工作台使用 1x preview，纸张阴影与完成内容预先合成为一张 1x 复合 preview，避免每帧重复合成两张大图；手势结束恢复 screen-scale full cache。只有 bounds、内容尺寸、屏幕 scale、trait 或内存警告发生变化时才清理对应缓存。

完成内容在 raster cache 更新后异步生成 1x 复合 preview；viewport 手势期间通过 generation guard 丢弃过期结果。进入手势前先取消并排空已开始的后台 preview 任务；若用户刚抬笔就立即捏合、preview 尚未回写，则在首帧前同步补齐，避免连续帧期间发生 CPU 争抢或退回双大图合成。

该优化只影响屏幕呈现，不进入作品快照。

### 6.5 蜡笔形态稳定

- 将蜡笔宏观 `jitter` 从 0.18 收敛到 0.06，并用几何测试锁定。
- 保持 `textureStrength` 和局部颗粒强度，避免蜡笔退化为宽马克笔。
- `drawDabs` 使用 `dab.seed` 映射到 8 个固定 brush-tip 变体，全部进入现有缓存，绘制期间不创建新图片。
- 每个变体只改变内部颗粒分布，不改变 dab 半径、中心、alpha、flow 或内容坐标。
- 蜡笔倾角继续使用 `.mild`，aspect ratio 上限保持 1.35；非法或非有限输入回退为正圆稳定值。

### 6.6 状态恢复

`copyOfStroke(_:)` 必须复制 `samples` 和 `cachedDabs`。复制后 dab 序列应与恢复前相等；恢复完成后无需因 viewport 改变重新生成 dab。

历史存储仍保存最终 raster，不新增磁盘字段，不迁移 schema。

## 7. 性能与内存边界

- iPad 1210×834 @2x 的单张 RGBA 缓存约 15.4 MiB；iPhone 874×402 @3x 约 12.1 MiB。
- 同时只保留必要的完成笔画缓存、活动笔画数据和有限 brush-tip 变体；不建立无限 tile 或每个 stroke 独立大图缓存。
- brush-tip 缓存继续设置数量上限，缓存键包含风格、颜色和变体编号。
- 活动笔画处理应随新增采样数量线性增长，不随整条历史采样数量增长。

## 8. 测试与验收

### 8.1 单元测试

1. 全量生成与分批增量生成产生完全相同的 dab 序列。
2. 增量状态跨 segment 保留 residual，不能产生接缝或重复 dab。
3. 蜡笔每个 dab 的中心偏移不超过 `0.06 × radius`，aspect ratio 不超过 1.35。
4. 0.5x、1x、2x、3x viewport 只影响显示变换，不改变内容坐标中的 dab 几何。
5. 相同输入和 seed 仍确定性重放；不同 dab seed 能选择不同纹理变体。
6. copy 后的 samples 与 cachedDabs 保持一致。

### 8.2 运行时探针

扩展 `brush-perf` 或新增 `brush-interaction`：

- 记录 100、300、600 个活动采样按批追加的总耗时和最慢批次；
- 记录 100、300 条已完成笔画下 viewport 变换前后的绘制耗时；
- 记录 viewport preview 生成、工作台/纸张 preview 预热、每帧 P95/最大耗时和平均 FPS；
- 生成 0.5x、1x、2x、3x 下继续绘制的蜡笔样张；
- 输出 dab 数、最大中心偏移、最大 aspect ratio 和是否存在非有限值。

### 8.3 双端人工验收

iPhone 17 Pro 与 iPad Pro 11 M4 横屏分别验证：

1. 100% 连续绘制长铅笔和长蜡笔；
2. 放大到 200% 和 300% 后继续绘制蜡笔；
3. 缩小到 50% 后继续绘制；
4. 缩放过程中观察已完成笔画是否卡顿或闪烁；
5. 撤销、重做后笔画形态不变；
6. 保存、打开历史后内容一致；
7. 填色、取色、橡皮和印章无回归。

## 9. 文件范围

预计修改：

- `Packages/KidCanvasModules/Sources/KCDrawingEngine/KCBrushDabGenerator.swift`
- `Packages/KidCanvasModules/Sources/KCDrawingEngine/KCBrushPreset.swift`
- `Packages/KidCanvasModules/Tests/KCDrawingEngineTests/KCBrushDabGeneratorTests.swift`
- `KidCanvas/Features/Canvas/KCDrawingCanvasModels.swift`
- `KidCanvas/Features/Canvas/KCDrawingCanvasView.swift`
- `KidCanvas/Features/Editor/KCMainViewController+RuntimeAcceptance.swift`
- `scripts/runtime_acceptance_test.sh`
- `scripts/validate_project.py`
- `docs/modules/KCDrawingEngine.md`
- `docs/modules/KCDrawingCanvasView.md`
- `docs/testing/DELIVERY_ACCEPTANCE_CHECKLIST.md`

## 10. 完成定义

只有同时满足以下条件，T116 才能关闭：

- 缩放后继续画蜡笔不再向外分叉；
- 活动笔画改为增量 dab，完成笔画使用 raster 缓存；
- undo/redo 不丢失 dab 数据；
- 新增单元测试、性能探针、validator 和模块文档；viewport 探针明确要求平均 FPS `>= 30` 且最大帧 `< 50ms`。
- 全量 Swift 测试、项目校验、iPhone/iPad build 与相关 runtime acceptance 通过；
- 用户完成双端实际绘制确认。

## 11. 当前交付证据（2026-07-21）

- 提交链：`19cab33`（增量 dab）、`14b4841`（蜡笔几何）、`d613674`（活动画笔接入）、`e3fc2eb`（8 个确定性纹理变体）、`8865806`（完成内容与工作台缓存）、`395bbd7`（交互性能探针）。
- `swift test --package-path Packages/KidCanvasModules`：277 tests，0 failures。
- `scripts/validate_project.py`：Validation passed；完整 iOS Simulator Debug build 通过。
- `drawing-tools`、`canvas-viewport`、`save-history-restore`：iPhone 17 Pro 与 iPad Pro 11 M4 双端通过。
- `brush-interaction`（2026-07-21，最终代码测量）：iPhone 17 Pro 增量/全量约 `0.02930`、追加 P95 `0.01204ms`、最大 `0.01609ms`、viewport 平均 `189.75 FPS`、P95 `6.38ms`、最大帧 `7.00ms`、preview 预热 `6.31ms`；iPad Pro 11 M4 增量/全量约 `0.02770`、追加 P95 `0.01299ms`、最大 `0.03397ms`、viewport 平均 `82.28 FPS`、P95 `14.10ms`、最大帧 `15.10ms`、preview 预热 `16.27ms`。双端均为 `passed: true`，300 条历史 viewport 均无新增 replay/rebuild，蜡笔偏移比约 `0.060000000000003`，aspect ratio `1.35`，几何有限。
- iPad Pro 11 M4 模拟器的 300 条历史 viewport 合成观测已达到 30 FPS 阈值，但不能替代老款实体 iPad 的最终结论。2026-07-21 检查时目标 iPad7,11 在 CoreDevice 中为 `unavailable`，且不在 Xcode destination 列表；该项仍保持人工真机待验收。
