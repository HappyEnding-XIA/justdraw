//
//  KCContentPickerLayout.swift
//  KCDomain
//
//  Created by 小大 on 2026/07/02.
//

import Foundation
import CoreGraphics

/// 不依赖 UIKit 的内容选择面板网格布局模型——内容选择 Feature
/// （`KCContentPickerFeature`）抽出的纯几何边界。
///
/// 此前 `KCMainViewController` 把色盘网格的列数、按钮尺寸、间距、总宽、
/// 按颜色数推导总高等算术内联在多个 `paletteXxx()` 方法里。这里将其集中，
/// 便于单测，并让控制器/Feature 通过带类型的接口取值，而不是散落算术。
/// UIKit 的实际按钮创建与约束仍留在控制器；该类型只负责布局尺寸模型。
public struct KCContentPickerLayout: Equatable, Sendable {

    /// 色盘网格列数（原型固定为 6）。
    public let columns: Int

    /// 单个色块按钮的边长（原型固定为 30）。
    public let buttonSize: CGFloat

    /// 色块之间的间距（原型固定为 8）。
    public let spacing: CGFloat

    public init(columns: Int = 6, buttonSize: CGFloat = 30.0, spacing: CGFloat = 8.0) {
        self.columns = max(1, columns)
        self.buttonSize = max(0, buttonSize)
        self.spacing = max(0, spacing)
    }

    /// 网格总宽：`列数 × 按钮边长 + (列数 − 1) × 间距`，对应原型 `paletteGridWidth`。
    public var gridWidth: CGFloat {
        CGFloat(columns) * buttonSize + CGFloat(columns - 1) * spacing
    }

    /// `colorCount` 个色块在当前列数下所需的总高，对应原型
    /// `paletteGridHeightForColorCount:`（行数向上取整，行间计入间距）。
    public func gridHeight(forColorCount colorCount: Int) -> CGFloat {
        let rows = (max(0, colorCount) + columns - 1) / columns
        let spacingCount = max(0, rows - 1)
        return CGFloat(rows) * buttonSize + CGFloat(spacingCount) * spacing
    }

    /// 索引 `index` 在网格中的（行、列），用于按钮的 leading/top 偏移计算。
    public func rowColumn(forIndex index: Int) -> (row: Int, column: Int) {
        (max(0, index) / columns, max(0, index) % columns)
    }
}
