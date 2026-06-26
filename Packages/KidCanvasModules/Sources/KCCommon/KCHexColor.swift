//
//  KCHexColor.swift
//  KCCommon
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import CoreGraphics

/// 不依赖 UIKit 的可编码颜色值，以归一化的 0...1 RGBA 分量存储。
///
/// `KCHexColor` 让 domain 与 engine 层与 `UIKit/UIColor` 解耦。
/// 它通过十六进制字符串（`#RRGGBB` 或 `#RRGGBBAA`）进行往返存储，
/// 与 Objective-C 原型中笔画和贴纸已采用的十六进制表示保持一致。
public struct KCHexColor: Equatable, Hashable, Sendable {
    /// 红色分量，取值范围 `0...1`。
    public var red: Double
    /// 绿色分量，取值范围 `0...1`。
    public var green: Double
    /// 蓝色分量，取值范围 `0...1`。
    public var blue: Double
    /// 透明度分量，取值范围 `0...1`。
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
        self.alpha = min(1, max(0, alpha))
    }

    /// 黑色（`#000000`）。
    public static let black = KCHexColor(red: 0, green: 0, blue: 0)
    /// 白色（`#FFFFFF`）。
    public static let white = KCHexColor(red: 1, green: 1, blue: 1)
    /// 完全透明。
    public static let clear = KCHexColor(red: 0, green: 0, blue: 0, alpha: 0)

    /// 每通道 8 位的分量，计算方式与原型对颜色栅格化的方式一致
    /// （`lrint(component * 255)`），从而保证油漆桶填充和取色保持准确。
    public var rgba8: (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        (
            UInt8(max(0, min(255, lrint(red * 255)))),
            UInt8(max(0, min(255, lrint(green * 255)))),
            UInt8(max(0, min(255, lrint(blue * 255)))),
            UInt8(max(0, min(255, lrint(alpha * 255))))
        )
    }

    /// 解析十六进制颜色字符串。
    ///
    /// 可接受的形式（前导 `#` 可选）：`RGB`、`RRGGBB`、`RRGGBBAA`。
    /// 对于格式错误的输入返回 `nil`。
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

        // 格式为 `#RRGGBB` 或 `#RRGGBBAA`（alpha 位于低位字节）。移位排列确保
        // alpha 的位置不会与某个 RGB 通道发生混叠。
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

    /// 紧凑的十六进制表示：完全不透明时为 `#RRGGBB`，否则为 `#RRGGBBAA`。
    public var hex: String {
        let (r, g, b, a) = rgba8
        let prefix = String(format: "#%02X%02X%02X", r, g, b)
        if a == 255 {
            return prefix
        }
        return prefix + String(format: "%02X", a)
    }
}

extension KCHexColor: Codable {
    private enum CodingKeys: String, CodingKey {
        case hex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hexString = try container.decode(String.self)
        guard let parsed = KCHexColor(hex: hexString) else {
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
