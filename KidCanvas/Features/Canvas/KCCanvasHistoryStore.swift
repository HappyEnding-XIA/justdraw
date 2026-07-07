//
//  KCCanvasHistoryStore.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/07.
//

import Foundation

/// 画布撤销/重做历史栈，集中管理栈容量、redo 清理和状态弹出顺序。
final class KCCanvasHistoryStore {
    private let maximumStates: Int
    private var undoStates: [KDCanvasState] = []
    private var redoStates: [KDCanvasState] = []

    init(maximumStates: Int = 48) {
        self.maximumStates = maximumStates
    }

    var canUndo: Bool {
        !undoStates.isEmpty
    }

    var canRedo: Bool {
        !redoStates.isEmpty
    }

    func recordUndoState(_ state: KDCanvasState?) {
        guard let state else { return }
        undoStates.append(state)
        trimHistoryStack(&undoStates)
        redoStates.removeAll()
    }

    func undoState(afterRecordingRedo currentState: KDCanvasState) -> KDCanvasState? {
        guard canUndo else { return nil }
        redoStates.append(currentState)
        trimHistoryStack(&redoStates)
        return undoStates.removeLast()
    }

    func redoState(afterRecordingUndo currentState: KDCanvasState) -> KDCanvasState? {
        guard canRedo else { return nil }
        undoStates.append(currentState)
        trimHistoryStack(&undoStates)
        return redoStates.removeLast()
    }

    func clear() {
        undoStates.removeAll()
        redoStates.removeAll()
    }

    private func trimHistoryStack(_ stack: inout [KDCanvasState]) {
        while stack.count > maximumStates {
            stack.removeFirst()
        }
    }
}
