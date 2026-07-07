//
//  KCEditorColorBridge.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/07.
//

import UIKit
import KCCommon

// MARK: - KCHexColor 到 UIColor 桥接

extension UIColor {
    /// 把 UIKit 无关的 `KCHexColor`（KCCommon）转成 `UIColor`。两者都用归一化 0...1
    /// 分量，因此转换是无损的：与原 `makePalette24/36` 里直接 `UIColor(red:green:blue:alpha:)`
    /// 的取值逐位一致，避免色板视觉回归。
    convenience init(kcHex hex: KCHexColor) {
        self.init(red: hex.red, green: hex.green, blue: hex.blue, alpha: hex.alpha)
    }
}
