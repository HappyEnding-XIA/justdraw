import Foundation
import KCCommon

/// A named color palette (e.g. the built-in 24- and 36-color sets).
public struct ContentPalette: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var title: String
    public var colors: [HexColor]

    public init(id: String, title: String, colors: [HexColor]) {
        self.id = id
        self.title = title
        self.colors = colors
    }
}

/// A grouped set of sticker SF Symbol identifiers sharing a category.
public struct StickerGroup: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var title: String
    public var symbols: [String]

    public init(id: String, title: String, symbols: [String]) {
        self.id = id
        self.title = title
        self.symbols = symbols
    }
}

/// Metadata for a built-in line-art template. The procedural drawing itself is
/// produced by the drawing engine; this type only describes the catalog entry.
public struct LineArtTemplate: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var title: String
    public var category: String

    public init(id: String, title: String, category: String) {
        self.id = id
        self.title = title
        self.category = category
    }
}
