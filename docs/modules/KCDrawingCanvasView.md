# KCDrawingCanvasView

App 层 UIKit/Core Graphics 画布视图：承接触摸绘制、画布状态快照、撤销/重做、印章视图手势接入和画布内容渲染。位于 `KidCanvas/KCDrawingCanvasView.swift`，不是独立 SPM target。

## 1. 职责

- 维护当前画布内容：背景图片、笔触、印章视图和 undo/redo 状态栈。
- 接收触摸事件，协调画笔、橡皮、填色、取色和印章插入。
- 创建印章视图，并接入 tap、pan、pinch、rotation 手势。
- 根据 `KCDomain.KCStickerSymbolDisplayMetrics` 生成带安全边距的印章图片，避免兔子、乌龟等外轮廓较大的 SF Symbol 在容器内被裁切。
- 在印章插入、选中、取消选中时应用明确的视觉反馈；选中态边框复用 `KCEditorVisualStyle.saveActionColor`。
- 在印章拖动、缩放和旋转开始前保存快照，结束后提交 undo 状态。

## 2. 边界

- 不负责右侧印章面板按钮创建、素材分类或本地化文案；这些由 `KCBrushStickerPanelView` / `KCContentPickerFeature` / `KCL10n` 承担。
- 不直接持有会话存储、历史列表、相册导入或保存到相册流程。
- 不把可测试的印章缩放、位置约束和符号显示指标写在视图里；缩放 clamp 和中心点 clamp 通过注入的 `KCDrawingEngineProviding` 委托执行，符号显示指标来自 `KCStickerSymbolDisplayMetrics`。
- 不把真实产品文案从内部 `sticker` 模型推导出来；用户可见文案仍走本地化。

## 3. 当前接入

- `KCCanvasFeature.makeCanvasView(delegate:)` 创建并注入 `KCDrawingEngineProviding`。
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
- iPhone 与 iPad build、runtime smoke 必须通过；交付前还需人工点验真实手势。
