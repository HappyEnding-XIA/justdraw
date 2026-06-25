import Foundation
import CoreGraphics
import KCCommon

/// An affine transform stored as its six Core Graphics matrix components, so
/// sticker state stays `Codable` and `UIKit`-free while remaining convertible
/// to/from `CGAffineTransform`.
public struct StickerTransform: Codable, Equatable, Sendable {
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

    /// The identity transform.
    public static let identity = StickerTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

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

    /// Uniform scale extracted from the matrix, the same way the prototype reads
    /// it when clamping sticker size: `hypot(a, c)`.
    public var scale: Double {
        let value = hypot(a, c)
        return value > 0 ? value : 1.0
    }

    /// Returns a copy scaled by `factor` (applied like `CGAffineTransformScale`).
    public func scaled(by factor: Double) -> StickerTransform {
        let scaled = cgAffineTransform.scaledBy(x: factor, y: factor)
        return StickerTransform(cgAffineTransform: scaled)
    }

    /// Returns a copy rotated by `angle` radians.
    public func rotated(by angle: Double) -> StickerTransform {
        let rotated = cgAffineTransform.rotated(by: angle)
        return StickerTransform(cgAffineTransform: rotated)
    }
}

/// A sticker placed on the canvas, modeled on the Objective-C `KDStickerState`.
///
/// Position is the absolute `center` in canvas coordinates plus a full affine
/// `transform` (carrying scale and rotation). The SF Symbol identifier and tint
/// color define the sticker's appearance.
public struct StickerItem: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var symbolName: String
    public var color: HexColor
    public var center: CGPoint
    public var transform: StickerTransform

    public init(
        id: UUID = UUID(),
        symbolName: String,
        color: HexColor,
        center: CGPoint = .zero,
        transform: StickerTransform = .identity
    ) {
        self.id = id
        self.symbolName = symbolName
        self.color = color
        self.center = center
        self.transform = transform
    }
}
