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

- `KCStrokeRenderMath` 负责三种画笔的基础宽度/透明度差异：铅笔更轻更淡、钢笔完全不透明且宽度稳定、蜡笔更厚但基础笔画保持低透明度，避免退化成平滑粗马克笔。
- `KCStrokeRenderMath.RenderProfile` 负责输出完整画笔视觉配置：基础度量、端点风格、质感层和颗粒参数。
- `KCStrokeRenderMath.TextureLayer` 以数据方式描述铅笔柔边、断续石墨草稿线、蜡笔偏移涂抹层和 dash 断续蜡痕，避免把魔法数散落在 UIKit 视图中。
- `KCDrawingCanvasView` 只消费 `KCDrawingEngineProviding.brushRenderProfile(...)` 并负责 UIKit 光栅化：铅笔柔边与草稿纹理、钢笔利落端点、蜡笔偏移断续蜡痕与颗粒纹理。
- 画笔质感不得只靠底部 Dock 默认宽度区分；同一宽度和压力下，`KCStrokeRenderMathTests.testBrushStylesAreVisuallySeparatedAtSameWidthAndPressure`、`testBrushRenderProfilesEncodeDifferentTextures` 与 `testPencilAndCrayonTextureDominatesBaseStroke` 必须证明三者基础度量、质感配置和主视觉来源不同。
- T080 后，铅笔草稿线必须带 dash 断续纹理，蜡笔 profile 必须包含宽蜡痕层和较强颗粒参数；铅笔/蜡笔的基础实线不能盖过纹理，否则真实画布会只剩粗细差异。
- T081 后，三种画笔按“用户可见笔触签名”验收：铅笔基础 alpha 控制在 0.30 以内并由多层断续石墨线主导；钢笔保持无纹理的高不透明实线；蜡笔基础 alpha 控制在 0.30 以内，并由宽蜡痕、偏移断续蜡痕和高颗粒 alpha 主导。`testUserVisibleBrushSignaturesAreNotWidthOnly` 必须守住这些阈值。
- 橡皮擦使用独立配置宽度，不能套用铅笔/钢笔/蜡笔质感公式；同一橡皮宽度在三种当前画笔状态下必须得到一致渲染结果。

## 4. 取色器采样边界

取色器属于高频交互路径，App 层不得为了单点取色把整张 `CGImage` 解码为 `KCBitmapBuffer`。

- `KCColorSampler` 只负责已经存在的 `KCBitmapBuffer` 内部采样，适合泛洪填充等已经持有完整缓冲区的算法。
- `KCImagePixelSampler` 负责从 `CGImage` 裁剪并渲染目标 1×1 像素，供 `KCDrawingEngineAdapter.sampleColorFromImage(...)` 使用。
- `KCDrawingCanvasView` 的取色路径必须先通过 `pixelImage(at:)` 渲染目标点的 1 像素画布图片，再交给 `KCDrawingEngineProviding.sampleColorFromImage(...)`；不得为了单点取色调用整画布 `snapshotImage()`。
- `KCDrawingCanvasView` 继续只依赖 `KCDrawingEngineProviding.sampleColorFromImage(...)` 做最终像素解析，不直接接触具体采样实现。
- 如果后续要优化为异步取色或批量取色，应在 adapter 协议下新增能力，不把 UIKit 取色细节回流到画布视图。

## 5. 填色性能边界

- `KCFloodFillEngine.fill(...)` 必须先校验尺寸乘法溢出，再计算 `pixelCount`。
- 当种子色已经等于目标填充色时，必须在分配 `visited` 和 `queue` 前直接返回，避免无效填色触发整图 BFS。
- App 层 `KCDrawingCanvasView.beginFloodFill(at:color:)` 还必须在生成 undo 快照和整画布 raster 前做 1 像素非印章画布预检；seed 已经等于目标色时不进入引擎层。
- App 层仍负责把 UIKit 画布渲染为 `CGImage`，引擎层只处理 `KCBitmapBuffer` 内的纯算法。

## 6. 测试与验收

- `KCStrokeRenderMathTests` 覆盖铅笔、钢笔、蜡笔基础度量、纹理强度和用户可见笔触签名，避免三种画笔退化为“只差粗细”。
- `KCLineArtDrawingTests` 覆盖支持 id 顺序、每个模板的 stroke 数量、路径非空与未知 id 返回 nil。
- `KCImagePixelSamplerTests` 覆盖 `CGImage` 单点采样与越界保护，防止取色器退回整图解码路径。
- `KCFloodFillEngineTests.testReturnsZeroWhenSeedEqualsFill` 覆盖同色填充返回 0 的行为，validator 额外守住短路位置。
- `scripts/validate_project.py` 额外守住 App 层填色同色预检：必须使用 `pixelImageExcludingStickers(at:)`，且短路发生在 `canvasStateSnapshot()` / `rasterImageExcludingStickers()` 前。
- 双端验收仍以 iPhone + iPad 构建、validator 和 runtime smoke 为准。
- 如后续调整线稿视觉，需要补截图、像素对比或明确的人工视觉验收记录。
