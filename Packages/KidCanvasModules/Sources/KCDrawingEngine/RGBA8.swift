import Foundation
import CoreGraphics
import KCCommon

/// An 8-bit-per-channel RGBA color, the working representation for raster
/// operations. Byte layout matches the prototype's premultiplied-last,
/// 32-bit-big-endian bitmap context (R, G, B, A in memory order).
public struct RGBA8: Equatable, Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(_ color: HexColor) {
        let c = color.rgba8
        self.init(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
    }

    public static let black = RGBA8(red: 0, green: 0, blue: 0)
    public static let white = RGBA8(red: 255, green: 255, blue: 255)
    public static let zero = RGBA8(red: 0, green: 0, blue: 0, alpha: 0)

    /// Sum of absolute per-channel differences (Manhattan distance), the exact
    /// metric the prototype uses to decide flood-fill boundaries.
    public func delta(from other: RGBA8) -> Int {
        abs(Int(red) - Int(other.red))
        + abs(Int(green) - Int(other.green))
        + abs(Int(blue) - Int(other.blue))
        + abs(Int(alpha) - Int(other.alpha))
    }
}
