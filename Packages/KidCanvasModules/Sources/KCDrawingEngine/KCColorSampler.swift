//
//  KCColorSampler.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCCommon

/// 点颜色采样，是原型 `colorAtPoint:` 取色器在引擎层的对应实现。
public enum KCColorSampler {
    /// 返回 `(x, y)` 处的像素颜色，当该点越界时返回 `nil`。
    public static func sample(buffer: KCBitmapBuffer, x: Int, y: Int) -> KCRGBA8? {
        guard x >= 0, x < buffer.width, y >= 0, y < buffer.height else { return nil }
        return buffer.pixel(x: x, y: y)
    }

    /// 便捷方法：将采样到的颜色作为 `KCHexColor` 返回。
    public static func sampleHex(buffer: KCBitmapBuffer, x: Int, y: Int) -> KCHexColor? {
        guard let rgba = sample(buffer: buffer, x: x, y: y) else { return nil }
        return KCHexColor(
            red: Double(rgba.red) / 255.0,
            green: Double(rgba.green) / 255.0,
            blue: Double(rgba.blue) / 255.0,
            alpha: Double(rgba.alpha) / 255.0
        )
    }
}
