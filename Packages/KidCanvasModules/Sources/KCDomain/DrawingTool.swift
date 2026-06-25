import Foundation

public enum ToolMode: String, Codable, CaseIterable, Sendable {
    case brush
    case eraser
    case fill
    case sticker
    case picker
}

public enum BrushStyle: String, Codable, CaseIterable, Sendable {
    case pencil
    case pen
    case crayon
}

public enum EraserShape: String, Codable, CaseIterable, Sendable {
    case circle
    case cloud
    case star
}
