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
    /// 保存按钮在空画布时保持可点击，用于触发“无法保存”的本地化反馈。
    func applyActionButtonAppearance(
        state: ActionState,
        undoButton: UIButton,
        redoButton: UIButton,
        saveButton: UIButton
    ) {
        undoButton.isEnabled = state.canUndo
        redoButton.isEnabled = state.canRedo
        saveButton.isEnabled = state.canSave

        KCEditorVisualStyle.applyActionButtonAvailability(to: undoButton, enabled: state.canUndo)
        KCEditorVisualStyle.applyActionButtonAvailability(to: redoButton, enabled: state.canRedo)
        KCEditorVisualStyle.applyActionButtonAvailability(
            to: saveButton,
            enabled: state.canSave,
            accentWhenEnabled: KCEditorVisualStyle.saveActionColor
        )
        saveButton.isEnabled = true
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
