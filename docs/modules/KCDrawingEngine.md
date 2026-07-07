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

## 3. 取色器采样边界

取色器属于高频交互路径，App 层不得为了单点取色把整张 `CGImage` 解码为 `KCBitmapBuffer`。

- `KCColorSampler` 只负责已经存在的 `KCBitmapBuffer` 内部采样，适合泛洪填充等已经持有完整缓冲区的算法。
- `KCImagePixelSampler` 负责从 `CGImage` 裁剪并渲染目标 1×1 像素，供 `KCDrawingEngineAdapter.sampleColorFromImage(...)` 使用。
- `KCDrawingCanvasView` 继续只依赖 `KCDrawingEngineProviding.sampleColorFromImage(...)`，不直接接触具体采样实现。
- 如果后续要优化为异步取色或批量取色，应在 adapter 协议下新增能力，不把 UIKit 取色细节回流到画布视图。

## 4. 填色性能边界

- `KCFloodFillEngine.fill(...)` 必须先校验尺寸乘法溢出，再计算 `pixelCount`。
- 当种子色已经等于目标填充色时，必须在分配 `visited` 和 `queue` 前直接返回，避免无效填色触发整图 BFS。
- App 层仍负责把 UIKit 画布渲染为 `CGImage`，引擎层只处理 `KCBitmapBuffer` 内的纯算法。

## 5. 测试与验收

- `KCLineArtDrawingTests` 覆盖支持 id 顺序、每个模板的 stroke 数量、路径非空与未知 id 返回 nil。
- `KCImagePixelSamplerTests` 覆盖 `CGImage` 单点采样与越界保护，防止取色器退回整图解码路径。
- `KCFloodFillEngineTests.testReturnsZeroWhenSeedEqualsFill` 覆盖同色填充返回 0 的行为，validator 额外守住短路位置。
- 双端验收仍以 iPhone + iPad 构建、validator 和 runtime smoke 为准。
- 如后续调整线稿视觉，需要补截图、像素对比或明确的人工视觉验收记录。
