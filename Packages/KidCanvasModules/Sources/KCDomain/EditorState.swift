import Foundation
import KCCommon

/// The single source of truth for the active editing configuration, consolidating
/// the tool/brush/color/size state that the prototype scattered across the canvas
/// view and main view controller.
public struct EditorState: Codable, Equatable, Sendable {
    public var toolMode: ToolMode
    public var brushStyle: BrushStyle
    public var eraserShape: EraserShape
    public var color: HexColor
    public var lineWidth: Double
    public var stickerSymbol: String
    public var fillTolerance: Double
    /// Recently used colors (PRD calls for 6–8). Newest first.
    public var recentColors: [HexColor]
    /// Last-used width per brush style, so each brush remembers its own size
    /// (mirrors the prototype's `KDBrushWidthsByStyle` preference).
    public var lineWidthByBrush: [BrushStyle: Double]
    /// Which palette size is currently shown.
    public var paletteSize: PaletteSize

    public init(
        toolMode: ToolMode = .brush,
        brushStyle: BrushStyle = .pencil,
        eraserShape: EraserShape = .circle,
        color: HexColor = EditorState.defaultColor,
        lineWidth: Double = EditorState.defaultLineWidth,
        stickerSymbol: String = EditorState.defaultStickerSymbol,
        fillTolerance: Double = EditorState.defaultFillTolerance,
        recentColors: [HexColor] = [],
        lineWidthByBrush: [BrushStyle: Double] = [:],
        paletteSize: PaletteSize = .standard
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
    public static let defaultColor = HexColor(red: 0.94, green: 0.43, blue: 0.45)
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
    public mutating func selectBrush(_ style: BrushStyle, fallbackWidth: Double = EditorState.defaultLineWidth) {
        brushStyle = style
        if let remembered = lineWidthByBrush[style] {
            lineWidth = remembered
        } else {
            lineWidth = fallbackWidth
        }
    }

    /// Pushes a color onto recent history (deduplicated, capped), newest first.
    public mutating func useColor(_ newColor: HexColor) {
        color = newColor
        recentColors.removeAll { $0 == newColor }
        recentColors.insert(newColor, at: 0)
        if recentColors.count > EditorState.recentColorLimit {
            recentColors.removeLast(recentColors.count - EditorState.recentColorLimit)
        }
    }
}

/// Palette size toggle (PRD: 24-color default, optional 36-color).
public enum PaletteSize: String, Codable, CaseIterable, Sendable {
    case standard
    case extended

    public var colorCount: Int {
        switch self {
        case .standard: return 24
        case .extended: return 36
        }
    }
}
