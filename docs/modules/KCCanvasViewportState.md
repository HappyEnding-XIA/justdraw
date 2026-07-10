# KCCanvasViewportState

KCDomain 层画布视口（viewport）纯逻辑模型：描述画布内容如何从“内容坐标空间”投射到“屏幕坐标空间”，是画布导航能力（T097：安全创作区默认居中、双指缩放、双指平移、一键恢复视图）的几何与坐标转换边界。源文件位于 `Packages/KidCanvasModules/Sources/KCDomain/KCCanvasViewportState.swift`，不依赖 UIKit，可独立单测。

## 1. 职责

- 持有视口状态：`scale`（钳制到 `[minimumScale=0.5, maximumScale=3.0]`，对应 PRD 建议 50%–300%）、`translation`（屏幕点）、`contentSize`（内容坐标空间尺寸，等于画布 view 的 `bounds.size`）、`viewportRect`（屏幕坐标下的安全创作区矩形）。
- 定义内容↔屏幕坐标转换：`屏幕点 = scale × 内容点 + translation`，并提供 `canvasPoint(forViewPoint:)` / `viewPoint(forCanvasPoint:)` / `affineTransform`。
- 计算默认视图：把内容中心对齐到安全创作区中心（`defaultState` / `resettingToDefault()`），而不是整屏几何中心。
- 计算钳制平移 `clampedTranslation`：缩放后内容大于等于创作区时保证内容始终覆盖创作区（不留空隙）；缩小态（内容小于创作区）时画纸完全留在创作区内、可在区内任意滑动但不移出创作区/不压到工具轨（范围 `[viewportMin, viewportMax - 内容尺寸]`，T107）。默认居中由 `defaultState` / `resettingToDefault()` 显式给出，不依赖该钳制分支。
- 提供围绕屏幕焦点缩放（`applyingScale(_:aroundViewPoint:)`，焦点下内容点保持不动）和平移（`translating(by:)`）的纯函数式变更，结果均自动钳制。
- 暴露 `isDefault`，供 App 层判断是否需要显示“恢复视图”按钮。
- T106 后，`KCDrawingCanvasView` 的双指 pan 和运行时验收共用同一个平移入口，避免测试绕过真实手势逻辑；验收会在 200% 缩放下施加平移增量，并断言 `translation` 与同屏幕点对应的内容坐标都发生变化。T107 后，验收额外在 50% 缩放下施加平移增量，断言缩小态平移同样会改变 `translation` 且不被强制吸回默认居中（旧实现会把缩小态平移吸回中心）。

## 2. 边界

- 不依赖 UIKit / SwiftUI / Photos，只用 `Foundation` + `CoreGraphics`；可在 SPM `KCDomainTests` 下脱离 App 单测。
- 不持有 `UIView`、不调用 `setNeedsDisplay`、不识别手势；这些 UIKit 行为由 App/Canvas 层（`KCDrawingCanvasView`、`KCMainViewController`）在拿到本模型结果后执行。
- 不持久化视口；viewport 仅当前会话内保留，新建/打开历史/清空/线稿载入时由画布层重置为默认（PRD：打开历史作品 MVP 可先恢复默认安全创作区）。
- 不改变画布内容（笔画、底图、印章）的存储坐标，也不参与保存/历史/草稿的磁盘 schema。
- 不决定“安全创作区”具体几何；该矩形由 `KCMainViewController.canvasCreationRect()` 按面板布局计算后注入。
- 不决定画布纸张/工作台的视觉样式；T105 的纸张边界、投影和工作台背景属于 `KCDrawingCanvasView.draw(_:)` 的屏幕呈现层，保存、历史缩略图和草稿快照仍在内容坐标空间渲染纯作品数据。

## 3. 对外 API / 接入路径

- `init(contentSize:viewportRect:scale:translation:)`：构造视口；`scale` 自动钳制。
- `affineTransform` / `canvasPoint(forViewPoint:)` / `viewPoint(forCanvasPoint:)`：坐标转换。`KCDrawingCanvasView.draw(_:)` 用 `affineTransform` 投射内容；触摸/填色/取色/印章命中统一用 `canvasPoint(forViewPoint:)` 把屏幕点转成内容点。
- `applyingScale(_:aroundViewPoint:)` / `translating(by:)` / `resettingToDefault()` / `clamped`：纯函数式变更，返回新状态。
- `defaultState` / `isDefault` / `currentScale`（通过 `scale`）：默认视图与状态判定。
- 当前接入：`KCDrawingCanvasView` 持有 `viewportState`，在 `layoutSubviews` 与 `applyViewportRect(_:)` 中同步 `contentSize` 与 `viewportRect`；`UIPinchGestureRecognizer` / 双指 `UIPanGestureRecognizer` 调用上述变更函数后重绘并 `applyViewport(to:)` 重定位印章。`KCMainViewController` 在 `viewDidLayoutSubviews` 注入 `canvasCreationRect()`，并通过 `drawingCanvasViewportDidChange(_:)` 显隐右下角“恢复视图”按钮。
- T106 接入：`handleCanvasTwoFingerPan(_:)` 调用画布层私有 `applyCanvasViewportTranslation(_:)`；Debug 下 `runtimeAcceptanceApplyViewportTranslation(_:)` 复用同一入口。`canvas-viewport` 探针会记录 `translationBeforePan` / `translationAfterPan`、`contentPointBeforePan` / `contentPointAfterPan` 和方向匹配结果。T107 接入：Debug 下新增 `runtimeAcceptanceDefaultTranslation(forScale:)`，供缩小态断言读取默认居中平移量；`canvas-viewport` 探针额外记录 `scaledDownScaleAfterSet` / `scaledDownViewportTranslationChanged` / `scaledDownContentPointChangedAfterPan` / `scaledDownNotCentered`。

## 4. 禁止回流规则

- 禁止把 UIKit 类型（`UIView`、`UIGestureRecognizer`、`UIImage` 等）下沉到 `KCCanvasViewportState`；本类型必须保持 UIKit-free。
- 禁止在该模型里调用 `setNeedsDisplay` / 触发重绘或手势识别；渲染与交互归 App/Canvas 层。
- 禁止把画布整体塞进 `UIScrollView` 来实现导航；必须用本视口状态 + 坐标转换（validator 守护 `KCDrawingCanvasView` 不引用 `UIScrollView`）。
- 禁止把画布核心重写为 SwiftUI `Canvas`（validator 守护 `KCDrawingCanvasView` 不 `import SwiftUI`）。
- 禁止新增“缩放模式 / 平移模式”按钮；画布导航只通过双指手势 + 状态化“恢复视图”按钮完成（validator 守护主控制器不含 `缩放模式` / `平移模式` 文案）。
- 禁止让绘制、填色、取色、印章命中各自重复换算坐标；必须统一经 `canvasPoint(forViewPoint:)` 转到内容坐标。
- 禁止在保存/快照/填色采样路径叠加 viewport 变换；这些路径在内容坐标空间渲染，保证导出与历史作品尺寸不受缩放/平移影响。
- 禁止持久化 viewport 或改变保存/历史/草稿磁盘 schema；viewport 仅会话内保留。
- 禁止缩小默认视图的缩放钳制范围而不补单测与 validator；默认下限 0.5、上限 3.0 由测试与 PRD 建议共同守护。
- 禁止在缩小态（内容小于创作区）把用户主动平移强制吸回中心（T107 防回流）；必须保留用户平移，并把画纸钳制到完全留在创作区内的范围 `[viewportMin, viewportMax - 内容尺寸]`（不允许移出创作区/压到工具轨），由 `完全留在创作区内` 注释标记与 `testScaledDownPanNotForcedToCenter` / `testPanKeepsContentFullyInsideViewportWhenSmaller` / `canvas-viewport` 缩小态断言共同守护。默认居中只允许经 `defaultState` / `resettingToDefault()` 显式触发。
- 禁止把 T105 的纸张投影、描边、工作台背景写入 `snapshotImage()` / 历史缩略图 / 草稿文件；这些视觉分层只用于屏幕呈现。
