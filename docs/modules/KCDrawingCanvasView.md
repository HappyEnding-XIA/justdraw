# KCDrawingCanvasView

App 层 UIKit/Core Graphics 画布视图：承接触摸绘制、画布状态快照、撤销/重做、印章视图手势接入和画布内容渲染。位于 `KidCanvas/Features/Canvas/KCDrawingCanvasView.swift`，配套模型位于 `KidCanvas/Features/Canvas/KCDrawingCanvasModels.swift`，历史栈存储位于 `KidCanvas/Features/Canvas/KCCanvasHistoryStore.swift`，印章呈现位于 `KidCanvas/Features/Canvas/KCStickerViewPresenter.swift`，不是独立 SPM target。

## 1. 职责

- 维护当前画布内容：背景图片、笔触、印章视图，并把 undo/redo 状态栈委托给 `KCCanvasHistoryStore`。
- `KCDrawingCanvasModels.swift` 承载 `KDToolMode`、`KDBrushStyle`、`KDEraserShape`、`KDStroke`、`KDCanvasState`、`KDStickerView` 等画布模型，避免主视图文件继续膨胀。
- `KCCanvasHistoryStore.swift` 集中管理 undo/redo 栈容量、redo 清理和撤销/重做弹出顺序，避免主视图继续膨胀。
- `KCStickerViewPresenter.swift` 集中生成并缓存印章 SF Symbol 图片、设置默认容器大小、空闲态和选中态外观。
- 接收触摸事件，协调画笔、橡皮、填色、取色和印章插入。
- 创建印章视图，并接入 tap、pan、pinch、rotation 手势。
- 屏幕呈现层绘制低干扰工作台背景、白色纸张留边、轻投影与暖色氛围光；这些视觉层不进入 `snapshotImage()`、历史缩略图、草稿或导出图片。
- 根据 `KCDomain.KCStickerSymbolDisplayMetrics` 生成带安全边距的印章图片，避免兔子、乌龟等外轮廓较大的 SF Symbol 在容器内被裁切。
- 按 symbol、颜色 RGBA 和显示指标缓存最终印章 raster 图片，避免反复插入/恢复同款印章时在主线程重复 `UIGraphicsImageRenderer` 绘制。
- 在印章插入、选中、取消选中时应用明确的视觉反馈；选中态边框复用 `KCEditorVisualStyle.saveActionColor`。
- 在印章拖动、缩放和旋转开始前保存快照，结束后提交 undo 状态。
- 填色工具使用串行后台队列执行像素 flood-fill 计算；主线程只负责生成输入快照和应用最终结果，避免大画布 BFS 阻塞触摸响应。
- 填色输入图使用非印章 raster 缓存；画布内容和尺寸未变化时，连续填色不再在主线程重复重绘背景和全部历史笔画。
- 保存/草稿快照通过 `snapshotImage()` 复用非印章 raster 缓存，再逐个合成印章视图；不得为了保存整棵画布 layer 树，避免保存、退后台草稿和替换画布前保护出现长帧。
- 填色触摸入口在创建 undo 快照和整画布 raster 前，先用 `pixelImageExcludingStickers(at:)` 采样 1 像素非印章画布；点击处已是目标填充色时直接返回，避免无效填色造成主线程卡顿。
- 单点取色/填色预检的 1 像素非印章采样只重绘覆盖采样点的笔画；当采样点没有命中印章时，取色器复用该轻量路径，不再为了单点取色走整层 `layer.render`。
- 渲染笔触时按 UIKit 传入的 dirty rect 跳过无关笔画；触摸绘制增量只刷新旧/新笔画边界并集，降低长画布历史下的重绘成本。
- `KDStroke` 缓存保守的渲染边界，`draw(_:)` 和局部刷新判断优先复用缓存，避免历史笔画越多时反复解析 `CGPath.boundingBoxOfPath`。
- undo/redo 快照中的已提交笔画按 append-only 语义共享引用，恢复状态时再深拷贝，避免每次开始新笔画都复制全部历史 `UIBezierPath`。
- 承担画笔光栅化质感：通过 `KCDrawingEngineProviding.brushRenderProfile(...)` 获取画笔视觉配置，铅笔使用更低透明度基础、柔边和强断续石墨草稿纹理，钢笔使用更利落的无纹理实线端点，蜡笔使用更低透明度基础、平直断面的宽蜡痕、偏移断续蜡痕、高颗粒纹理和浅色纸纹留白。
- 高频绘制路径不得为了筛选画笔质感层创建 `filter` 临时数组；应单次遍历 profile 的 `textureLayers` 并按阶段绘制。
- 蜡笔颗粒路径必须批量绘制：dash 点阵可缓存，但 UIKit 光栅化时应把短线追加到批量 `UIBezierPath` 后一次 `stroke()`；纸纹留白可以复用同一批 dash 点再生成多条较稀疏的留白 path，避免宽蜡笔每次重绘产生大量短生命周期 path 对象，同时强化蜡笔压纸面的粗糙感。

## 2. 边界

- 不负责右侧印章面板按钮创建、素材分类或本地化文案；这些由 `KCBrushStickerPanelView` / `KCContentPickerFeature` / `KCL10n` 承担。
- 不直接持有会话存储、历史列表、相册导入或保存到相册流程。
- 不把可测试的印章缩放、位置约束和符号显示指标写在视图里；缩放 clamp 和中心点 clamp 通过注入的 `KCDrawingEngineProviding` 委托执行，符号显示指标来自 `KCStickerSymbolDisplayMetrics`。
- 不把真实产品文案从内部 `sticker` 模型推导出来；用户可见文案仍走本地化。
- 不把画布模型类型重新写回 `KCDrawingCanvasView.swift`；模型类型统一留在 `KCDrawingCanvasModels.swift`。
- 不把 `undoStates` / `redoStates` 数组重新写回 `KCDrawingCanvasView.swift`；历史栈统一留在 `KCCanvasHistoryStore.swift`。
- 不把印章图片渲染、缓存、aspect-fit 计算和选中态样式重新写回 `KCDrawingCanvasView.swift`；呈现细节统一留在 `KCStickerViewPresenter.swift`。
- 不把耗时 flood-fill 像素计算重新放回触摸回调主线程；触摸入口必须走 `beginFloodFill(at:color:)`。
- 不允许每次有效填色都无条件重绘整张非印章画布；`rasterImageExcludingStickers()` 必须先复用 bounds/scale 匹配的缓存，内容变更或尺寸变更时再失效。
- 不允许保存、草稿保存或运行时验收快照回退到整棵画布 `layer.render(in:)`；`snapshotImage()` 必须复用非印章 raster 并只合成印章层。
- 不允许同色填色继续创建 undo 快照、整画布 raster 或后台 BFS；无效填色必须通过 1 像素非印章采样提前短路。
- 不允许单点非印章采样为了 1 个像素重绘所有历史笔画；必须先用 `strokeRenderBounds(_:)` 跳过未覆盖采样点的笔画。
- 未命中印章时，取色器不得回退到整层 `layer.render`；应复用非印章 1 像素采样路径。
- 不允许把高频触摸绘制退回全量 `setNeedsDisplay()`；只有清空、换图、撤销/重做、填色、印章等大状态切换保留全量刷新。
- 不允许在 `draw(_:)` 里对所有历史笔画重复计算路径 bounds；已提交笔画必须复用 `cachedRenderBounds`，活跃笔画路径变更后必须显式失效缓存。
- 不允许在 `canvasStateSnapshot()` 中恢复 `strokes.map { copyOfStroke($0) }` 这类全量笔画深拷贝；已提交笔画不再修改，历史快照应共享引用，状态恢复时再复制。
- 不允许把画笔质感退化为只调整默认线宽；同一宽度和压力下，铅笔、钢笔、蜡笔必须有可感知的透明度、端点、断续石墨线、宽蜡痕、颗粒纹理或纸纹留白差异，且铅笔/蜡笔的基础实线不能成为主视觉。铅笔基础 alpha 应控制在 0.30 以内，蜡笔默认基础 alpha 应控制在 0.038 以内，真实观感由纹理层主导。

## 3. 当前接入

- `KCCanvasFeature.makeCanvasView(delegate:)` 创建并注入 `KCDrawingEngineProviding`。
- `KCDrawingCanvasView.swift` 只使用模型类型，不再声明模型类型；Xcode target Sources 必须同时包含 `KCDrawingCanvasModels.swift`。
- `KCDrawingCanvasView.swift` 通过 `historyStore` 记录、撤销、重做和清空历史，主文件不再直接裁剪历史数组。
- `KCDrawingCanvasView.swift` 通过 `stickerPresenter` 创建印章视图并切换选中/空闲外观，手势和 undo/redo 时机仍由画布视图协调。
- `KCStickerViewPresenter` 使用有上限的 `NSCache` 复用已渲染印章图；缓存 key 必须包含 symbol、颜色和尺寸指标，避免不同颜色或大外轮廓印章串图。
- `draw(_:)` 通过 `strokeRenderBounds(_:)` 与 dirty rect 相交判断跳过无关 `KDStroke`，`touchesMoved` / `touchesEnded` 使用旧/新 stroke bounds 并集局部刷新。
- `strokeRenderBounds(_:)` 会优先返回 `KDStroke.cachedRenderBounds`；只有缓存为空时才计算 `CGPath.boundingBoxOfPath` 并写回缓存。
- `drawStroke(_:)` 通过 `KCDrawingEngineProviding` 获取 `KCStrokeRenderMath.RenderProfile`，并在 UIKit 层消费 profile 的基础线宽、透明度、端点、纹理层、dash 蜡痕和蜡笔颗粒参数；蜡笔蜡痕 dash 使用 `.butt` 断面和更长 gap 强化蜡块断续感，颗粒绘制会再叠多层浅色纸纹留白，橡皮擦不套用画笔质感。
- T094 起铅笔/蜡笔走 dab 渲染（引擎见 `docs/modules/KCDrawingEngine.md` 第 4 节）：`touchesBegan/Moved/Ended` 对 coalesced touch 采集 `KCBrushInputSample`；T116 起活动笔画通过 `KCBrushDabGenerationState` 和 `appendIncrementalDabs` 只追加新增 dab，`KDStroke.cachedDabs` 与累计 bounds 复用，undo/redo 复制 samples 与 cached dabs。**T111 起 `brushDabs` 传入 `stroke.lineWidth`**（`resolvedDabs(for:)`），引擎 preset 经 `scaledForLineWidth` 据此缩放 dab 半径；尺寸变化只影响新 stroke。brush-tip mask 缓存在 `NSCache`，每种风格/颜色/seed 预热 8 个确定性变体，`drawDabs` 按 `dab.seed % 8` 选择，移动阶段不创建 UIImage。钢笔仍走 path smoothing，橡皮/填色/取色/贴纸不变；无 `samples` 的旧 stroke 回落 path 渲染。dirty rect 只刷新新增 dab 局部范围。
- T095 起 `#if DEBUG` 暴露 `renderBrushSampleSheet()`：固定颜色/尺寸/seed 生成铅笔/钢笔/蜡笔的横线、曲线、快速线、压力渐变样张，供 `runtime_acceptance_test.sh brush-samples` 落盘 PNG 做人工视觉对比；`brush-perf` 探针记录 100/300 条 dab stroke 的生成耗时基线，防止画笔引擎拖慢触摸。
- `beginFloodFill(at:color:)` 先调用 `fillColorAlreadyMatchesCanvas(at:fillColor:)` 做同色预检，预检只渲染目标点 1 像素并排除印章视图，保持与实际填色输入图一致。
- `rasterImageExcludingStickers()` 命中 `nonStickerRasterCacheImage` 时直接返回缓存；miss 时才通过 `UIGraphicsImageRenderer(bounds:format:)` 生成输入图并写入缓存。新增笔画在缓存有效时通过 `appendCommittedStrokeToRasterCache` 增量合成；reset、bounds 变化和大状态替换才使缓存失效，填色结果会直接成为下一次填色的非印章缓存。
- T116 起 `draw(_:)` 不再逐帧遍历已提交 `strokes`：工作台底色/氛围光和纸张阴影使用独立 full cache；viewport 手势期间工作台使用 1x preview，纸张阴影与完成内容预合成为一张 1x 复合 preview，手势结束恢复 screen-scale full cache，活动笔画单独叠加。复合 preview 默认后台生成并用 generation guard 防止过期回写；手势开始前排空已开始的任务，缺失时同步补齐。Debug `brush-interaction` 验证 300 条历史笔画 viewport 帧不增加 replay/rebuild 计数，并记录每帧 P95/最大耗时与 preview 预热。
- `snapshotImage()` 使用 `rasterImageExcludingStickers(includeActiveStroke:)` 生成/复用底图，然后通过 `drawStickerViewsForSnapshot(in:)` 合成印章，避免保存路径触发整棵 canvas layer 渲染。
- `pixelImageExcludingStickers(at:)` 的单点渲染会根据 `strokeRenderBounds(_:)` 跳过未覆盖采样点的历史笔画；`pixelImage(at:)` 在采样点未命中印章时直接复用该路径，只有命中印章视图时才需要 `layer.render` 保留印章取色语义。
- `KCMainViewController` 通过 `canvasView.currentStickerSymbol` 设置当前印章素材。
- 点击画布时，`insertStickerSymbol(_:atNormalizedPoint:)` 添加印章并自动选中。
- `deleteSelectedSticker()` / `bringSelectedStickerToFront()` 由右侧印章编辑按钮触发。
- `handleStickerPinch(_:)`、`handleStickerRotation(_:)`、`handleStickerPan(_:)` 负责实际视图变换，并在结束时提交 undo 快照。
- `scripts/validate_project.py` 校验印章缩放/中心约束、选中态反馈、选中/取消选中恢复和 undo/redo 关键路径。

## 5. T116 性能边界与验收

- 活动笔画追加必须保持增量状态，不得在 `touchesMoved` 清空 `cachedDabs` 或对整条 samples 重新生成 dab；`drawDabs` 还必须按当前 CGContext clip bounds 剔除脏区外 dab，避免局部刷新仍提交整条活动笔画。
- 完成内容和静态表面只保留有界 full/preview raster cache；viewport 变化不能逐帧重放历史笔画。内存警告、bounds、内容尺寸、屏幕 scale 或界面样式变化必须清理相应缓存。
- 目标阈值：600 采样增量/旧全量比例 `<= 0.35`，追加批次 P95 `<= 8ms`，最大批次 `< 50ms`，viewport 平均 FPS `>= 30` 且最大帧 `< 50ms`，300 条历史笔画 viewport 不新增 replay/rebuild，蜡笔偏移比 `<= 0.060001`、aspect ratio `<= 1.35`、几何全为有限值。
- 当前自动化证据（2026-07-21 当前代码重跑）：iPhone 17 Pro 增量比例 `0.02176`、追加 P95 `0.01407ms`、最大 `0.01693ms`、平均 `121.47 FPS`、帧 P95 `11.17ms`、最大帧 `11.34ms`、preview 生成 `21.74ms`；iPad Pro 11 M4 增量比例 `0.03118`、追加 P95 `0.02098ms`、最大 `0.04005ms`、平均 `52.45 FPS`、帧 P95 `23.30ms`、最大帧 `24.04ms`、preview 生成 `32.81ms`。双端均通过探针。
- iPad Pro 11 M4 模拟器在 300 条历史笔画的 Debug 合成观测已达到 30 FPS 阈值，但不替代老款实体 iPad 的最终结论；目标 iPad7,11 当前 unavailable，仍需确认最低 `30 FPS` 和无 `>=50ms` 主线程停顿。

## 4. 验收规则

- 插入印章后必须有清晰选中反馈，并触发编辑按钮可用态刷新。
- 小兔子、小乌龟等外轮廓较大的印章必须完整显示在默认容器内，不允许被容器或画布边缘裁切。
- 拖动、捏合缩放、旋转、前移、删除都必须保持 undo/redo 可恢复。
- 不允许把印章按钮样式或素材分类逻辑回流到 `KCDrawingCanvasView`。
- 不允许把缩放边界常量复制到视图层；继续通过 `KCDrawingEngineProviding` / `KCDomain` 约束。
- 不允许把 `KDStroke` / `KDCanvasState` / `KDStickerView` 等模型声明回流到主 View 文件。
- 不允许把 `undoStates` / `redoStates` / `trimHistoryStack` 回流到 `KCDrawingCanvasView`；撤销/重做栈容量与清理规则由 `KCCanvasHistoryStore` 承担。
- 不允许把 `stickerImage` / `aspectFitRect` / 印章图片缓存 / 印章 layer 外观设置回流到 `KCDrawingCanvasView`；印章呈现由 `KCStickerViewPresenter` 承担。
- `hasVisibleContent()` 必须保持 O(1) 字段判断，不允许为了判断空画布而调用 `canvasStateSnapshot()` 复制所有笔画路径。
- `canvasStateSnapshot()` 不得对已提交笔画做全量深拷贝；`applyCanvasState(_:)` 恢复到活跃画布时必须继续复制笔画对象。
- flood-fill 必须保留串行队列、generation 防乱序和主线程结果应用；重复点击填色时不允许并发写回画布。
- flood-fill 的非印章输入图必须有 bounds/scale 保护的缓存；有效填色结果必须刷新缓存，新增笔画、reset、layout bounds 变化必须让缓存失效。
- `snapshotImage()` 必须复用非印章 raster 缓存并手动合成印章视图，保存/草稿路径不得重新整层渲染画布 layer。
- flood-fill 同色 no-op 必须在 `canvasStateSnapshot()` 和 `rasterImageExcludingStickers()` 之前返回，且采样图不得包含印章视图。
- 单点取色和 flood-fill 同色预检必须继续保持 1 像素渲染；非印章路径必须按采样点过滤笔画，避免长画作下每次取色/预检遍历绘制全部历史笔画。
- 高频触摸绘制必须保留局部刷新：`draw(_:)` 跳过 dirty rect 外的历史笔画，移动/结束笔画只刷新旧/新笔画边界并集。
- 高频触摸绘制必须保留笔画边界缓存：历史笔画不重复计算 bounds，活跃笔画追加点或切换点笔画路径后必须调用缓存失效逻辑。
- 高频笔刷质感绘制不得退回 `textureLayers.filter` 这类每笔画分配临时数组的实现。
- 蜡笔颗粒绘制不得退回“每个 dash 创建一个 `UIBezierPath` 并单独 stroke”的实现；必须保留批量 path 绘制，并保留多层纸纹留白路径以强化蜡笔观感。
- 大状态切换必须保留全量刷新，避免背景、填色、撤销/重做、印章层级变化留下视觉残影。
- 铅笔、钢笔、蜡笔的视觉差异必须同时体现在基础渲染参数和 UIKit 光栅化质感上；手感验收不能只看默认粗细，代码验收必须守住 `brushRenderProfile`、`drawTextureLayers`、`setLineDash`、铅笔断续石墨线、蜡笔宽蜡痕、窄碎边缘、`.butt` 蜡痕断面、`drawCrayonGrain` 多层纸纹路径，以及 `testPencilAndCrayonTextureDominatesBaseStroke`、`testUserVisibleBrushSignaturesAreNotWidthOnly`、`testCrayonDefaultStrokeUsesObviousWaxInsteadOfTintedWideLine`、`testCrayonDefaultStrokeHasRoughEdgeAndPaperTooth`、`testCrayonWideWaxLayersLeaveVisiblePaperGaps`。
- iPhone 与 iPad build、runtime smoke 必须通过；交付前还需人工点验真实手势。
