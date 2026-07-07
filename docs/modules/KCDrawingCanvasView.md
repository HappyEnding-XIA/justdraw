# KCDrawingCanvasView

App 层 UIKit/Core Graphics 画布视图：承接触摸绘制、画布状态快照、撤销/重做、印章视图手势接入和画布内容渲染。位于 `KidCanvas/Features/Canvas/KCDrawingCanvasView.swift`，配套模型位于 `KidCanvas/Features/Canvas/KCDrawingCanvasModels.swift`，历史栈存储位于 `KidCanvas/Features/Canvas/KCCanvasHistoryStore.swift`，印章呈现位于 `KidCanvas/Features/Canvas/KCStickerViewPresenter.swift`，不是独立 SPM target。

## 1. 职责

- 维护当前画布内容：背景图片、笔触、印章视图，并把 undo/redo 状态栈委托给 `KCCanvasHistoryStore`。
- `KCDrawingCanvasModels.swift` 承载 `KDToolMode`、`KDBrushStyle`、`KDEraserShape`、`KDStroke`、`KDCanvasState`、`KDStickerView` 等画布模型，避免主视图文件继续膨胀。
- `KCCanvasHistoryStore.swift` 集中管理 undo/redo 栈容量、redo 清理和撤销/重做弹出顺序，避免主视图继续膨胀。
- `KCStickerViewPresenter.swift` 集中生成印章 SF Symbol 图片、设置默认容器大小、空闲态和选中态外观。
- 接收触摸事件，协调画笔、橡皮、填色、取色和印章插入。
- 创建印章视图，并接入 tap、pan、pinch、rotation 手势。
- 根据 `KCDomain.KCStickerSymbolDisplayMetrics` 生成带安全边距的印章图片，避免兔子、乌龟等外轮廓较大的 SF Symbol 在容器内被裁切。
- 在印章插入、选中、取消选中时应用明确的视觉反馈；选中态边框复用 `KCEditorVisualStyle.saveActionColor`。
- 在印章拖动、缩放和旋转开始前保存快照，结束后提交 undo 状态。
- 填色工具使用串行后台队列执行像素 flood-fill 计算；主线程只负责生成输入快照和应用最终结果，避免大画布 BFS 阻塞触摸响应。

## 2. 边界

- 不负责右侧印章面板按钮创建、素材分类或本地化文案；这些由 `KCBrushStickerPanelView` / `KCContentPickerFeature` / `KCL10n` 承担。
- 不直接持有会话存储、历史列表、相册导入或保存到相册流程。
- 不把可测试的印章缩放、位置约束和符号显示指标写在视图里；缩放 clamp 和中心点 clamp 通过注入的 `KCDrawingEngineProviding` 委托执行，符号显示指标来自 `KCStickerSymbolDisplayMetrics`。
- 不把真实产品文案从内部 `sticker` 模型推导出来；用户可见文案仍走本地化。
- 不把画布模型类型重新写回 `KCDrawingCanvasView.swift`；模型类型统一留在 `KCDrawingCanvasModels.swift`。
- 不把 `undoStates` / `redoStates` 数组重新写回 `KCDrawingCanvasView.swift`；历史栈统一留在 `KCCanvasHistoryStore.swift`。
- 不把印章图片渲染、aspect-fit 计算和选中态样式重新写回 `KCDrawingCanvasView.swift`；呈现细节统一留在 `KCStickerViewPresenter.swift`。
- 不把耗时 flood-fill 像素计算重新放回触摸回调主线程；触摸入口必须走 `beginFloodFill(at:color:)`。

## 3. 当前接入

- `KCCanvasFeature.makeCanvasView(delegate:)` 创建并注入 `KCDrawingEngineProviding`。
- `KCDrawingCanvasView.swift` 只使用模型类型，不再声明模型类型；Xcode target Sources 必须同时包含 `KCDrawingCanvasModels.swift`。
- `KCDrawingCanvasView.swift` 通过 `historyStore` 记录、撤销、重做和清空历史，主文件不再直接裁剪历史数组。
- `KCDrawingCanvasView.swift` 通过 `stickerPresenter` 创建印章视图并切换选中/空闲外观，手势和 undo/redo 时机仍由画布视图协调。
- `KCMainViewController` 通过 `canvasView.currentStickerSymbol` 设置当前印章素材。
- 点击画布时，`insertStickerSymbol(_:atNormalizedPoint:)` 添加印章并自动选中。
- `deleteSelectedSticker()` / `bringSelectedStickerToFront()` 由右侧印章编辑按钮触发。
- `handleStickerPinch(_:)`、`handleStickerRotation(_:)`、`handleStickerPan(_:)` 负责实际视图变换，并在结束时提交 undo 快照。
- `scripts/validate_project.py` 校验印章缩放/中心约束、选中态反馈、选中/取消选中恢复和 undo/redo 关键路径。

## 4. 验收规则

- 插入印章后必须有清晰选中反馈，并触发编辑按钮可用态刷新。
- 小兔子、小乌龟等外轮廓较大的印章必须完整显示在默认容器内，不允许被容器或画布边缘裁切。
- 拖动、捏合缩放、旋转、前移、删除都必须保持 undo/redo 可恢复。
- 不允许把印章按钮样式或素材分类逻辑回流到 `KCDrawingCanvasView`。
- 不允许把缩放边界常量复制到视图层；继续通过 `KCDrawingEngineProviding` / `KCDomain` 约束。
- 不允许把 `KDStroke` / `KDCanvasState` / `KDStickerView` 等模型声明回流到主 View 文件。
- 不允许把 `undoStates` / `redoStates` / `trimHistoryStack` 回流到 `KCDrawingCanvasView`；撤销/重做栈容量与清理规则由 `KCCanvasHistoryStore` 承担。
- 不允许把 `stickerImage` / `aspectFitRect` / 印章 layer 外观设置回流到 `KCDrawingCanvasView`；印章呈现由 `KCStickerViewPresenter` 承担。
- `hasVisibleContent()` 必须保持 O(1) 字段判断，不允许为了判断空画布而调用 `canvasStateSnapshot()` 复制所有笔画路径。
- flood-fill 必须保留串行队列、generation 防乱序和主线程结果应用；重复点击填色时不允许并发写回画布。
- iPhone 与 iPad build、runtime smoke 必须通过；交付前还需人工点验真实手势。
