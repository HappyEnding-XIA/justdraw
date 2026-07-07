//
//  KCTransientToolModeMemory.swift
//  KCDomain
//
//  Created by 小大 on 2026/07/07.
//

import Foundation

/// 记录进入一次性工具前的工具模式，完成动作后用于恢复用户原本的创作上下文。
public struct KCTransientToolModeMemory: Equatable, Sendable {
    private let transientToolModes: Set<KCToolMode>
    private var lastPersistentToolMode: KCToolMode

    public init(
        defaultToolMode: KCToolMode = .brush,
        transientToolModes: Set<KCToolMode> = [.picker, .sticker]
    ) {
        self.transientToolModes = transientToolModes
        self.lastPersistentToolMode = transientToolModes.contains(defaultToolMode) ? .brush : defaultToolMode
    }

    public mutating func recordSelection(_ toolMode: KCToolMode) {
        guard !self.transientToolModes.contains(toolMode) else { return }
        self.lastPersistentToolMode = toolMode
    }

    public func toolModeAfterCompletingTransientTool() -> KCToolMode {
        self.lastPersistentToolMode
    }
}
