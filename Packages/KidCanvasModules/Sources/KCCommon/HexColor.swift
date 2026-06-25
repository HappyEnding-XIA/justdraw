import Foundation
import CoreGraphics

/// A UIKit-free, Codable color value stored as normalized 0...1 RGBA components.
///
/// `HexColor` keeps the domain and engine layers decoupled from `UIKit/UIColor`.
/// It round-trips through a hex string (`#RRGGBB` or `#RRGGBBAA`) for storage,
/// matching the hex representation already used by the Objective-C prototype's
/// strokes and stickers.
public struct HexColor: Equatable, Hashable, Sendable {
    /// Red component in `0...1`.
    public var red: Double
    /// Green component in `0...1`.
    public var green: Double
    /// Blue component in `0...1`.
    public var blue: Double
    /// Alpha component in `0...1`.
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
        self.alpha = min(1, max(0, alpha))
    }

    /// Black (`#000000`).
    public static let black = HexColor(red: 0, green: 0, blue: 0)
    /// White (`#FFFFFF`).
    public static let white = HexColor(red: 1, green: 1, blue: 1)
    /// Fully transparent.
    public static let clear = HexColor(red: 0, green: 0, blue: 0, alpha: 0)

    /// 8-bit per channel components, computed the same way the prototype rasterizes
    /// colors (`lrint(component * 255)`), so flood-fill and sampling stay faithful.
    public var rgba8: (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        (
            UInt8(max(0, min(255, lrint(red * 255)))),
            UInt8(max(0, min(255, lrint(green * 255)))),
            UInt8(max(0, min(255, lrint(blue * 255)))),
            UInt8(max(0, min(255, lrint(alpha * 255))))
        )
    }

    /// Parses a hex color string.
    ///
    /// Accepted forms (leading `#` optional): `RGB`, `RRGGBB`, `RRGGBBAA`.
    /// Returns `nil` for malformed input.
    public init?(hex: String) {
        var trimmed = hex
        if trimmed.hasPrefix("#") {
            trimmed.removeFirst()
        }
        guard trimmed.count == 3 || trimmed.count == 6 || trimmed.count == 8 else { return nil }
        guard trimmed.allSatisfy({ $0.isHexDigit }) else { return nil }

        if trimmed.count == 3 {
            let chars = Array(trimmed)
            trimmed = "\(chars[0])\(chars[0])\(chars[1])\(chars[1])\(chars[2])\(chars[2])"
        }

        var value: UInt64 = 0
        guard Scanner(string: trimmed).scanHexInt64(&value) else { return nil }

        // Format is `#RRGGBB` or `#RRGGBBAA` (alpha in the low byte). Shifts are
        // arranged so the alpha position never aliases into an RGB channel.
        if trimmed.count == 8 {
            let r = Double((value >> 24) & 0xFF) / 255.0
            let g = Double((value >> 16) & 0xFF) / 255.0
            let b = Double((value >> 8) & 0xFF) / 255.0
            let a = Double(value & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
        } else {
            let r = Double((value >> 16) & 0xFF) / 255.0
            let g = Double((value >> 8) & 0xFF) / 255.0
            let b = Double(value & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        }
    }

    /// Compact hex representation: `#RRGGBB` when fully opaque, otherwise `#RRGGBBAA`.
    public var hex: String {
        let (r, g, b, a) = rgba8
        let prefix = String(format: "#%02X%02X%02X", r, g, b)
        if a == 255 {
            return prefix
        }
        return prefix + String(format: "%02X", a)
    }
}

extension HexColor: Codable {
    private enum CodingKeys: String, CodingKey {
        case hex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hexString = try container.decode(String.self)
        guard let parsed = HexColor(hex: hexString) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid hex color: \(hexString)"
            )
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}
