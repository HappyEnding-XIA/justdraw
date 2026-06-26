//
//  KCStickerItem.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import CoreGraphics
import KCCommon

/// 以六个 Core Graphics 矩阵分量形式存储的仿射变换，使贴纸状态保持
/// 可 `Codable` 且不依赖 `UIKit`，同时仍可与 `CGAffineTransform` 互转。
public struct KCStickerTransform: Codable, Equatable, Sendable {
    public var a: Double
    public var b: Double
    public var c: Double
    public var d: Double
    public var tx: Double
    public var ty: Double

    public init(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    /// 恒等变换。
    public static let identity = KCStickerTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    public init(cgAffineTransform transform: CGAffineTransform) {
        self.init(
            a: transform.a,
            b: transform.b,
            c: transform.c,
            d: transform.d,
            tx: transform.tx,
            ty: transform.ty
        )
    }

    public var cgAffineTransform: CGAffineTransform {
        CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }

    /// 从矩阵中提取的均匀缩放，与原型在钳制贴纸尺寸时的读取方式相同：
    /// `hypot(a, c)`。
    public var scale: Double {
        let value = hypot(a, c)
        return value > 0 ? value : 1.0
    }

    /// 返回按 `factor` 缩放后的副本（应用方式同 `CGAffineTransformScale`）。
    public func scaled(by factor: Double) -> KCStickerTransform {
        let scaled = cgAffineTransform.scaledBy(x: factor, y: factor)
        return KCStickerTransform(cgAffineTransform: scaled)
    }

    /// 返回按 `angle` 弧度旋转后的副本。
    public func rotated(by angle: Double) -> KCStickerTransform {
        let rotated = cgAffineTransform.rotated(by: angle)
        return KCStickerTransform(cgAffineTransform: rotated)
    }
}

/// 放置在画布上的贴纸，以 Objective-C 的 `KDStickerState` 为蓝本。
///
/// 位置以画布坐标系下的绝对 `center` 加上完整的仿射 `transform`（承载缩放与
/// 旋转）表示。SF Symbol 标识符与着色定义了贴纸的外观。
public struct KCStickerItem: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var symbolName: String
    public var color: KCHexColor
    public var center: CGPoint
    public var transform: KCStickerTransform

    public init(
        id: UUID = UUID(),
        symbolName: String,
        color: KCHexColor,
        center: CGPoint = .zero,
        transform: KCStickerTransform = .identity
    ) {
        self.id = id
        self.symbolName = symbolName
        self.color = color
        self.center = center
        self.transform = transform
    }
}
