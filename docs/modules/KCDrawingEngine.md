# KCDrawingEngine

绘制引擎模块：承载无 UIKit 依赖的画布算法与几何生成。位于 `Packages/KidCanvasModules/Sources/KCDrawingEngine`，依赖 `KCCommon` 与 `KCDomain`。

## 1. 职责

- 位图处理：`KCBitmapBuffer`、`KCFloodFillEngine`、`KCColorSampler`、`KCImagePixelSampler`。
- 压力与笔触：`KCPressureModel`、`KCStrokeRenderMath`。
- 橡皮擦与蜡笔纹理：`KCEraserStampPath`、`KCCrayonGrain`。
- 贴纸几何约束相关的纯计算仍放在 `KCDomain`，由 App adapter 转发使用。
- 线稿几何：`KCLineArtDrawing` 生成内置线稿的 `CGPath` + line width 指令。

## 2. 线稿绘制边界

T038 后，内置线稿的程序化几何不再放在 `KCMainViewController`。

- `KCContentCatalog` 负责线稿 id、标题、分类和展示顺序。
- `KCLineArtDrawing.supportedTemplateIds` 负责声明 DrawingEngine 支持的线稿 id。
- `KCLineArtDrawing.strokes(forTemplateId:in:)` 输出 `[KCLineArtStroke]`，每条包含 `CGPath` 和原型线宽。
- `KCDrawingEngineAdapter.lineArtDrawingBlock(templateId:stroke:)` 在 App 层把 `CGPath` 包装为 `UIBezierPath`，并交给调用方提供的描边闭包。
- `KCLineArtFeature` 只按 catalog 顺序组装 item，并负责缩略图与画布线稿图片渲染；`KCMainViewController` 不再持有每个线稿的几何闭包或缩略图渲染逻辑。

## 3. 画笔质感边界

- `KCStrokeRenderMath` 负责三种画笔的基础宽度/透明度差异：铅笔更轻更淡、钢笔完全不透明且宽度稳定、蜡笔保持偏宽但不再只靠粗细区分，默认压力下基础笔画 alpha 控制在 0.038 以内，主视觉由断续蜡痕、窄碎边缘层和颗粒层承担。
- `KCStrokeRenderMath.RenderProfile` 负责输出完整画笔视觉配置：基础度量、端点风格、质感层和颗粒参数。
- `KCStrokeRenderMath.TextureLayer` 以数据方式描述铅笔柔边、断续石墨草稿线、蜡笔偏移涂抹层和 dash 断续蜡痕，避免把魔法数散落在 UIKit 视图中。
- `KCDrawingCanvasView` 只消费 `KCDrawingEngineProviding.brushRenderProfile(...)` 并负责 UIKit 光栅化：铅笔柔边与草稿纹理、钢笔利落端点、蜡笔偏移断续蜡痕与颗粒纹理。
- 画笔质感不得只靠底部 Dock 默认宽度区分；同一宽度和压力下，`KCStrokeRenderMathTests.testBrushStylesAreVisuallySeparatedAtSameWidthAndPressure`、`testBrushRenderProfilesEncodeDifferentTextures` 与 `testPencilAndCrayonTextureDominatesBaseStroke` 必须证明三者基础度量、质感配置和主视觉来源不同。
- T080 后，铅笔草稿线必须带 dash 断续纹理，蜡笔 profile 必须包含宽蜡痕层和较强颗粒参数；铅笔/蜡笔的基础实线不能盖过纹理，否则真实画布会只剩粗细差异。
- T081 后，三种画笔按“用户可见笔触签名”验收：铅笔基础 alpha 控制在 0.30 以内并由多层断续石墨线主导；钢笔保持无纹理的高不透明实线；蜡笔基础 alpha 控制在 0.038 以内，并由宽蜡痕、偏移断续蜡痕、窄碎边缘层和更粗颗粒主导。`testUserVisibleBrushSignaturesAreNotWidthOnly`、`testCrayonTextureIsDenseEnoughToReadAsWaxInsteadOfWideMarker`、`testCrayonTextureIsRoughEnoughForKidDrawing`、`testCrayonBaseStrokeStaysBehindChunkyWaxTexture`、`testCrayonDefaultStrokeUsesObviousWaxInsteadOfTintedWideLine`、`testCrayonDefaultStrokeHasRoughEdgeAndPaperTooth`、`testCrayonWideWaxLayersLeaveVisiblePaperGaps` 与 `testCrayonBaseAlphaStaysFarBehindPencil` 必须守住这些阈值。
- 蜡笔颗粒间距必须以 `KCCrayonGrain` 的 `max(3.4, lineWidth * 0.25)` 为单一口径，颗粒短线宽度必须以 `max(1.6, lineWidth * 0.28)` 为单一口径；App adapter 的 `crayonGrainDashWidth(lineWidth:)` 不得使用更细的旧公式，否则真实画布会比引擎测试更平滑。宽蜡痕 dash 的 gap 应长于 mark，避免多层叠加后变成平滑马克笔。
- 橡皮擦使用独立配置宽度，不能套用铅笔/钢笔/蜡笔质感公式；同一橡皮宽度在三种当前画笔状态下必须得到一致渲染结果。

## 4. 画笔 dab 引擎（T093）

T093 引入纯 Swift、UIKit-free 的画笔采样与 dab 引擎，作为专业画笔质感的基础；UIKit/CoreGraphics 光栅化接入在 T094，本节类型不接触 UIKit。

- `KCBrushInputSample`：单次高保真输入采样（`point`、`timestamp`、`pressure`、`velocity`、`altitude`、`azimuth`、`isPencil`）；`pressure` 已由 `KCPressureModel.normalized(...)` 上游归一化。
- `KCBrushPreset`：按 `KCBrushStyle` 描述间距、半径曲线、不透明度、流量、硬度、抖动、纸纹强度、纹理种子、倾角行为与速度影响；`KCBrushPreset.preset(for:)` 提供铅笔/钢笔/蜡笔三种产品化预设。**T111 起**新增 `referenceLineWidth`（铅笔 12 / 钢笔 9 / 蜡笔 18，对应 App `clampedBrushWidth` 默认 slider 值）与 `scaledForLineWidth(_:)`：按 `lineWidth / referenceLineWidth`（钳到 `[0.2, 3.0]`、半径下限 0.15）缩放 `radiusMin`/`radiusMax`，让铅笔/蜡笔的尺寸 slider 真正生效（其余间距/流量/纹理/曲线不变）。
- `KCBrushDab`：单个绘制单元输出（中心、半径、alpha、flow、旋转、纵横比、硬度、纸纹强度、确定性 `seed`）。
- `KCBrushDabGenerator`：把连续采样变成稳定 dab 序列——逐采样压力按曲线算半径（不再是整条 `averagePressure`），速度参与间距与流量，Pencil 倾角参与椭圆侧锋，手指输入回退为垂直正圆。**T111 起**：上层 App adapter `brushDabs(for:canvasScale:brushStyle:lineWidth:)` 传入用户 `lineWidth`，preset 先经 `scaledForLineWidth(lineWidth)` 再生成 dab，故半径与间距随用户尺寸缩放；样张/性能基线探针按各风格 `referenceLineWidth` 渲染（1.0 倍）。

确定性约束（T094 undo/redo 重绘不闪烁的前提）：

- dab 的抖动与纹理种子由 `KCBrushDabHashing` 的纯 `UInt64` splitmix 混合生成；**禁止** `Swift.Hasher`/`Date()`/`random()`（`Hasher` 每进程随机种子会破坏跨运行一致性）。`scripts/validate_project.py` 守住这一约束。
- `kcBrushDabMix`/`kcBrushDabJitter` 为 `public`，供 T094 的 UIKit brush-tip mask 复用同一确定性哈希生成颗粒纹理。`KCBrushDab.bounds(inset:)` 给出旋转椭圆的保守包围盒，供画布 dirty rect。
- 同一 `(preset.textureSeed, samples)` 必须产出逐 dab 完全一致的序列，`KCBrushDabGeneratorTests.testIdenticalInputsProduceIdenticalDabs` 锁定该行为。

与 `KCStrokeRenderMath`（texture-layer 整条 stroke 模型）并存：T093 不删旧模型与 `KCStrokeRenderMathTests`，待 T094 接入 dab 渲染后再决定替代关系。`KCStroke` 在 T093 不新增 sample/dab 字段，保持保存 schema 兼容；运行时 samples/dabs 的接入是 T094。

## 5. 取色器采样边界

取色器属于高频交互路径，App 层不得为了单点取色把整张 `CGImage` 解码为 `KCBitmapBuffer`。

- `KCColorSampler` 只负责已经存在的 `KCBitmapBuffer` 内部采样，适合泛洪填充等已经持有完整缓冲区的算法。
- `KCImagePixelSampler` 负责从 `CGImage` 裁剪并渲染目标 1×1 像素，供 `KCDrawingEngineAdapter.sampleColorFromImage(...)` 使用。
- `KCDrawingCanvasView` 的取色路径必须先通过 `pixelImage(at:)` 渲染目标点的 1 像素画布图片，再交给 `KCDrawingEngineProviding.sampleColorFromImage(...)`；不得为了单点取色调用整画布 `snapshotImage()`。采样点未命中印章时应复用 `pixelImageExcludingStickers(at:)`，并按 `strokeRenderBounds(_:)` 跳过未覆盖采样点的历史笔画，避免长画作下单点取色仍重绘所有 stroke。
- `KCDrawingCanvasView` 继续只依赖 `KCDrawingEngineProviding.sampleColorFromImage(...)` 做最终像素解析，不直接接触具体采样实现。
- 如果后续要优化为异步取色或批量取色，应在 adapter 协议下新增能力，不把 UIKit 取色细节回流到画布视图。

## 6. 填色性能边界

- `KCFloodFillEngine.fill(...)` 必须先校验尺寸乘法溢出，再计算 `pixelCount`。
- 当种子色已经等于目标填充色时，必须在分配 `visited` 和 `queue` 前直接返回，避免无效填色触发整图 BFS。
- App 层 `KCDrawingCanvasView.beginFloodFill(at:color:)` 还必须在生成 undo 快照和整画布 raster 前做 1 像素非印章画布预检；seed 已经等于目标色时不进入引擎层。
- App 层仍负责把 UIKit 画布渲染为 `CGImage`，引擎层只处理 `KCBitmapBuffer` 内的纯算法。

## 7. 测试与验收

- `KCStrokeRenderMathTests` 覆盖铅笔、钢笔、蜡笔基础度量、纹理强度、宽蜡痕留白和用户可见笔触签名，避免三种画笔退化为“只差粗细”；`KCCrayonGrainTests` 同时约束蜡笔颗粒密度、纸纹空隙和宽线颗粒线宽，防止蜡笔退回平滑粗线或糊成马克笔；validator 额外守住 App adapter 使用同一颗粒宽度公式。
- `KCLineArtDrawingTests` 覆盖支持 id 顺序、每个模板的 stroke 数量、路径非空与未知 id 返回 nil。
- `KCImagePixelSamplerTests` 覆盖 `CGImage` 单点采样与越界保护，防止取色器退回整图解码路径。
- `KCFloodFillEngineTests.testReturnsZeroWhenSeedEqualsFill` 覆盖同色填充返回 0 的行为，validator 额外守住短路位置。
- `scripts/validate_project.py` 额外守住 App 层填色同色预检：必须使用 `pixelImageExcludingStickers(at:)`，且短路发生在 `canvasStateSnapshot()` / `rasterImageExcludingStickers()` 前；同时守住单点非印章采样按采样点过滤笔画、取色未命中印章时复用非印章轻量路径。
- 双端验收仍以 iPhone + iPad 构建、validator 和 runtime smoke 为准。
- 如后续调整线稿视觉，需要补截图、像素对比或明确的人工视觉验收记录。

## 8. T116 画笔性能与蜡笔稳定

- `KCBrushDabGenerationState` 保存上一采样、跨 segment 的 residual distance 和下一个 dab index；`appendDabs(for:state:)` 只处理新增采样，`dabs(for:)` 复用同一核心以保证全量/增量结果逐项一致。
- 蜡笔 `jitter` 固定为 `0.06`，随机向量归一化到单位圆后再乘半径，保证任意 dab 的中心偏移不超过 `0.06 × radius`；蜡笔倾角纵横比上限为 `1.35`。
- 输入边界会把非有限坐标、压力、速度、时间和倾角收敛为稳定值；非法倾角回退为正圆，禁止 NaN/Infinity 进入绘制几何。
- 性能优化不改变历史保存格式：增量状态、samples 和 cached dabs 都是运行时字段；磁盘仍保存既有 raster/session 数据。
- `KCBrushDabGeneratorTests` 覆盖不规则批次、重复采样、全量/增量等价、所有 dab 的 jitter 上限和非有限输入；`brush-interaction` Debug 探针覆盖 600 个采样、300 条历史笔画和 viewport cache 计数。
