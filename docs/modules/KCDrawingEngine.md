# KCDrawingEngine

绘制引擎模块：承载无 UIKit 依赖的画布算法与几何生成。位于 `Packages/KidCanvasModules/Sources/KCDrawingEngine`，依赖 `KCCommon` 与 `KCDomain`。

## 1. 职责

- 位图处理：`KCBitmapBuffer`、`KCFloodFillEngine`、`KCColorSampler`。
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

## 3. 测试与验收

- `KCLineArtDrawingTests` 覆盖支持 id 顺序、每个模板的 stroke 数量、路径非空与未知 id 返回 nil。
- 双端验收仍以 iPhone + iPad 构建、validator 和 runtime smoke 为准。
- 如后续调整线稿视觉，需要补截图、像素对比或明确的人工视觉验收记录。
