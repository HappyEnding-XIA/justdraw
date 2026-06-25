import Foundation
import KCCommon

/// An immutable snapshot of the canvas, used for undo/redo and serialization.
///
/// Modeled on the Objective-C `KDCanvasState`: a background raster (PNG bytes),
/// the committed strokes, and the placed stickers. Keeping the background as
/// `Data` keeps this type `UIKit`-free and `Codable`; the app/engine layer
/// produces the bytes when rasterizing flood-fill results or line art.
public struct CanvasSnapshot: Codable, Equatable, Sendable {
    public var backgroundImageData: Data?
    public var strokes: [Stroke]
    public var stickers: [StickerItem]

    public init(
        backgroundImageData: Data? = nil,
        strokes: [Stroke] = [],
        stickers: [StickerItem] = []
    ) {
        self.backgroundImageData = backgroundImageData
        self.strokes = strokes
        self.stickers = stickers
    }

    /// `true` when there is anything to render — matching the prototype's
    /// `canvasStateHasVisibleContent:`.
    public var hasVisibleContent: Bool {
        backgroundImageData != nil || !strokes.isEmpty || !stickers.isEmpty
    }
}
