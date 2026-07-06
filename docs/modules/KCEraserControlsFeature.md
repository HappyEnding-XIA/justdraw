# KCEraserControlsFeature

App 层橡皮擦控件 Feature：集中橡皮擦尺寸预览路径和 circle/cloud/star 形状按钮选中态样式。位于 `KidCanvas/KCEraserControlsFeature.swift`，不是独立 SPM target。

## 1. 职责

- 生成尺寸面板里的橡皮擦预览路径，保持现有 circle/cloud/star 预览几何。
- 判断某个橡皮擦形状是否为当前选中形状。
- 统一应用橡皮擦形状按钮的选中/未选中外观。

## 2. 边界

- 只负责控件预览与按钮状态外观，不负责真实画布擦除逻辑。
- 真实橡皮擦印章绘制仍由 `KCDrawingEngine` / `KCDrawingEngineAdapter` 提供。
- 控制器仍负责按钮集合、点击事件、更新 `canvasView.currentEraserShape` 和刷新尺寸预览。

## 3. 当前接入

- `KCMainViewController.eraserControlsFeature` 持有 `KCEraserControlsFeature` 实例。
- `refreshSizePreview()` 通过 `eraserControlsFeature.previewPath(...)` 获取橡皮擦预览路径。
- `refreshEraserShapeButtons()` 通过 `isShape(...)` 与 `applyShapeButtonAppearance(...)` 处理按钮选中态。
- `scripts/validate_project.py` 校验新文件已进入 App target Sources，并防止预览路径和按钮选中态回流主控制器。

## 4. 验收规则

- 不允许在 `KCMainViewController` 重新声明 `previewPathForEraserShape(...)`。
- 不允许在控制器内按按钮数组 index 判断橡皮擦形状选中态。
- iPhone 与 iPad build、runtime smoke 必须通过。
