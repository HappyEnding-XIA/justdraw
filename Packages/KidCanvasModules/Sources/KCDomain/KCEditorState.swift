//
//  KCEditorState.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCCommon

/// 当前编辑配置的唯一数据源，整合了原型中分散在画布视图与主视图控制器里的
/// 工具/画笔/颜色/尺寸状态。
public struct KCEditorState: Codable, Equatable, Sendable {
    public var toolMode: KCToolMode
    public var brushStyle: KCBrushStyle
    public var eraserShape: KCEraserShape
    public var color: KCHexColor
    public var lineWidth: Double
    public var stickerSymbol: String
    public var fillTolerance: Double
    /// 最近使用的颜色（PRD 要求 6–8 种）。最新的排在最前。
    public var recentColors: [KCHexColor]
    /// 每种画笔样式上次使用的宽度，使每种画笔各自记住自己的尺寸
    /// （对应原型中的 `KDBrushWidthsByStyle` 偏好）。
    public var lineWidthByBrush: [KCBrushStyle: Double]
    /// 当前显示的调色板尺寸。
    public var paletteSize: KCPaletteSize

    public init(
        toolMode: KCToolMode = .brush,
        brushStyle: KCBrushStyle = .pencil,
        eraserShape: KCEraserShape = .circle,
        color: KCHexColor = KCEditorState.defaultColor,
        lineWidth: Double = KCEditorState.defaultLineWidth,
        stickerSymbol: String = KCEditorState.defaultStickerSymbol,
        fillTolerance: Double = KCEditorState.defaultFillTolerance,
        recentColors: [KCHexColor] = [],
        lineWidthByBrush: [KCBrushStyle: Double] = [:],
        paletteSize: KCPaletteSize = .standard
    ) {
        self.toolMode = toolMode
        self.brushStyle = brushStyle
        self.eraserShape = eraserShape
        self.color = color
        self.lineWidth = lineWidth
        self.stickerSymbol = stickerSymbol
        self.fillTolerance = fillTolerance
        self.recentColors = recentColors
        self.lineWidthByBrush = lineWidthByBrush
        self.paletteSize = paletteSize
    }

    /// 原型默认颜色：`rgb(0.94, 0.43, 0.45)` ≈ `#F06E73`。
    public static let defaultColor = KCHexColor(red: 0.94, green: 0.43, blue: 0.45)
    public static let defaultLineWidth: Double = 12.0
    public static let defaultStickerSymbol = "star.fill"
    public static let defaultFillTolerance: Double = 28.0
    /// 保留的最近颜色上限（PRD 要求“6–8”的上界）。
    public static let recentColorLimit = 8

    /// 将 `width` 记为当前画笔样式上次使用的尺寸。
    public mutating func rememberBrushWidth(_ width: Double) {
        lineWidthByBrush[brushStyle] = width
    }

    /// 切换画笔样式，并恢复该画笔记忆的宽度（如有）。
    public mutating func selectBrush(_ style: KCBrushStyle, fallbackWidth: Double = KCEditorState.defaultLineWidth) {
        brushStyle = style
        if let remembered = lineWidthByBrush[style] {
            lineWidth = remembered
        } else {
            lineWidth = fallbackWidth
        }
    }

    /// 将一个颜色推入最近历史（去重、封顶），最新的排在最前。
    public mutating func useColor(_ newColor: KCHexColor) {
        color = newColor
        recentColors.removeAll { $0 == newColor }
        recentColors.insert(newColor, at: 0)
        if recentColors.count > KCEditorState.recentColorLimit {
            recentColors.removeLast(recentColors.count - KCEditorState.recentColorLimit)
        }
    }
}

/// 调色板尺寸切换（PRD：默认 24 色，可选 36 色）。
public enum KCPaletteSize: String, Codable, CaseIterable, Sendable {
    case standard
    case extended

    public var colorCount: Int {
        switch self {
        case .standard: return 24
        case .extended: return 36
        }
    }
}
