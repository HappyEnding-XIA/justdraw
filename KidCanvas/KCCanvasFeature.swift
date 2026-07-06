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

    struct ActionState: Equatable {
        let canUndo: Bool
        let canRedo: Bool
        let canSave: Bool
    }

    func makeCanvasView(delegate: KDDrawingCanvasViewDelegate) -> KCDrawingCanvasView {
        let canvasView = KCDrawingCanvasView()
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.delegate = delegate
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
