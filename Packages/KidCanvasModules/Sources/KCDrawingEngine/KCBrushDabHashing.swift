//
//  KCBrushDabHashing.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/07/08.
//

import Foundation

/// dab 引擎使用的确定性哈希工具。
///
/// 故意不使用 `Swift.Hasher`（其种子每进程随机，跨运行不稳定，会破坏 undo/redo
/// 重绘的纹理一致性），也不使用 `Date` / `random`。这里用纯 `UInt64` 算术实现
/// splitmix64 风格的混合，保证相同的 `(seed, index)` 永远得到相同结果。

/// 将 preset 纹理种子与 dab 序号混合成稳定的 per-dab 种子。
func kcBrushDabMix(seed: UInt64, index: UInt64) -> UInt64 {
    var z = seed &+ index &+ 0x9E37_79B9_7F4A_7C15
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
}

/// 把哈希值映射成两个 [-1, 1] 的抖动分量，供 dab 位置抖动使用。
func kcBrushDabJitter(hash: UInt64) -> (dx: Double, dy: Double) {
    let half: Double = 2_147_483_648.0 // 0x80000000
    let lo = hash & 0xFFFF_FFFF
    let hi = (hash >> 32) & 0xFFFF_FFFF
    let dx = (Double(lo) / half) - 1.0
    let dy = (Double(hi) / half) - 1.0
    return (dx, dy)
}
