//
//  KCCanvasFeature.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit

/// 主画布 Feature 的最小边界。
///
/// 当前阶段只承接画布视图创建与画布动作状态判断，不迁移触摸绘制、
/// 撤销栈、贴纸手势或 Core Graphics 绘制逻辑。这样可以先让
/// `KCMainViewController` 从直接创建/判断画布细节中退一步，同时保持行为稳定。
final class KCCanvasFeature {
    private let drawingEngine: KCDrawingEngineProviding

    struct ActionState: Equatable {
        let canUndo: Bool
        let canRedo: Bool
        let canSave: Bool
    }

    init(drawingEngine: KCDrawingEngineProviding) {
        self.drawingEngine = drawingEngine
    }

    func makeCanvasView(delegate: KDDrawingCanvasViewDelegate) -> KCDrawingCanvasView {
        let canvasView = KCDrawingCanvasView()
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.delegate = delegate
        canvasView.drawingEngine = drawingEngine
        canvasView.clipsToBounds = true
        return canvasView
    }

    func actionState(for canvasView: KCDrawingCanvasView) -> ActionState {
        ActionState(
            canUndo: canvasView.canUndo(),
            canRedo: canvasView.canRedo(),
            canSave: canvasView.hasVisibleContent()
        )
    }

    /// 应用 undo / redo / save 动作按钮外观。控制器只负责传入状态和按钮实例。
    func applyActionButtonAppearance(
        state: ActionState,
        undoButton: UIButton,
        redoButton: UIButton,
        saveButton: UIButton
    ) {
        undoButton.isEnabled = state.canUndo
        redoButton.isEnabled = state.canRedo
        saveButton.isEnabled = state.canSave

        undoButton.alpha = undoButton.isEnabled ? 1.0 : 0.55
        redoButton.alpha = redoButton.isEnabled ? 1.0 : 0.55
        saveButton.alpha = saveButton.isEnabled ? 1.0 : 0.6
        undoButton.backgroundColor = undoButton.isEnabled
            ? UIColor(white: 1.0, alpha: 0.76)
            : UIColor(white: 1.0, alpha: 0.62)
        redoButton.backgroundColor = redoButton.isEnabled
            ? UIColor(white: 1.0, alpha: 0.76)
            : UIColor(white: 1.0, alpha: 0.62)
        saveButton.backgroundColor = saveButton.isEnabled
            ? UIColor(red: 0.54, green: 0.80, blue: 0.98, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 0.72)
        saveButton.tintColor = saveButton.isEnabled
            ? UIColor(red: 0.19, green: 0.26, blue: 0.33, alpha: 1.0)
            : UIColor(red: 0.55, green: 0.60, blue: 0.67, alpha: 0.7)
    }

    func hasVisibleContent(_ canvasView: KCDrawingCanvasView) -> Bool {
        actionState(for: canvasView).canSave
    }

    func currentFillColor(for canvasView: KCDrawingCanvasView) -> UIColor {
        canvasView.currentColor
    }

    func resolvedStickerSymbol(currentSymbol: String, availableSymbols: [String]) -> String {
        currentSymbol.isEmpty ? (availableSymbols.first ?? "") : currentSymbol
    }
}
