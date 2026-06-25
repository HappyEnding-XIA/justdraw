//
//  KCEditorState.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCCommon

/// The single source of truth for the active editing configuration, consolidating
/// the tool/brush/color/size state that the prototype scattered across the canvas
/// view and main view controller.
public struct KCEditorState: Codable, Equatable, Sendable {
    public var toolMode: KCToolMode
    public var brushStyle: KCBrushStyle
    public var eraserShape: KCEraserShape
    public var color: KCHexColor
    public var lineWidth: Double
    public var stickerSymbol: String
    public var fillTolerance: Double
    /// Recently used colors (PRD calls for 6–8). Newest first.
    public var recentColors: [KCHexColor]
    /// Last-used width per brush style, so each brush remembers its own size
    /// (mirrors the prototype's `KDBrushWidthsByStyle` preference).
    public var lineWidthByBrush: [KCBrushStyle: Double]
    /// Which palette size is currently shown.
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

    /// Prototype default color: `rgb(0.94, 0.43, 0.45)` ≈ `#F06E73`.
    public static let defaultColor = KCHexColor(red: 0.94, green: 0.43, blue: 0.45)
    public static let defaultLineWidth: Double = 12.0
    public static let defaultStickerSymbol = "star.fill"
    public static let defaultFillTolerance: Double = 28.0
    /// Maximum recent colors retained (upper bound from the PRD's "6–8").
    public static let recentColorLimit = 8

    /// Remembers `width` as the last-used size for the active brush style.
    public mutating func rememberBrushWidth(_ width: Double) {
        lineWidthByBrush[brushStyle] = width
    }

    /// Switches brush style and restores that brush's remembered width (if any).
    public mutating func selectBrush(_ style: KCBrushStyle, fallbackWidth: Double = KCEditorState.defaultLineWidth) {
        brushStyle = style
        if let remembered = lineWidthByBrush[style] {
            lineWidth = remembered
        } else {
            lineWidth = fallbackWidth
        }
    }

    /// Pushes a color onto recent history (deduplicated, capped), newest first.
    public mutating func useColor(_ newColor: KCHexColor) {
        color = newColor
        recentColors.removeAll { $0 == newColor }
        recentColors.insert(newColor, at: 0)
        if recentColors.count > KCEditorState.recentColorLimit {
            recentColors.removeLast(recentColors.count - KCEditorState.recentColorLimit)
        }
    }
}

/// Palette size toggle (PRD: 24-color default, optional 36-color).
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
