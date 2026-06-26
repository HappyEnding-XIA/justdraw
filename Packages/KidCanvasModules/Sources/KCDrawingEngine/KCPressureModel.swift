//
//  KCPressureModel.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCDomain

/// 纯压力归一化逻辑，移植自 `-[KDDrawingCanvasView normalizedPressureForTouch:]`。
///
/// 将数学运算从触摸处理中拆分出来，使其可单元测试，并让最终的 UIKit 画布视图
/// 保持为对该模型的轻量适配层。
public enum KCPressureModel {
    /// 手指（非 Pencil）归一化：
    /// `min(1.18, max(0.92, 0.96 + normalizedForce * 0.28))`。
    public static func finger(normalizedForce: Double) -> Double {
        min(1.18, max(0.92, 0.96 + normalizedForce * 0.28))
    }

    /// Apple Pencil 归一化：
    /// `min(1.45, max(0.65, 0.72 + normalizedForce * 0.95))`。
    public static func pencil(normalizedForce: Double) -> Double {
        min(1.45, max(0.65, 0.72 + normalizedForce * 0.95))
    }

    /// 从原始压力值进行完整归一化。
    ///
    /// `normalizedForce` 即 `force / maximumPossibleForce`。当设备不报告压力
    /// （`maximumPossibleForce <= 0`）时返回 `1.0`，与原型的提前返回逻辑一致。
    public static func normalized(
        force: Double,
        maximumPossibleForce: Double,
        isPencil: Bool
    ) -> Double {
        guard maximumPossibleForce > 0 else { return 1.0 }
        let normalizedForce = force / maximumPossibleForce
        return isPencil
            ? pencil(normalizedForce: normalizedForce)
            : finger(normalizedForce: normalizedForce)
    }
}
