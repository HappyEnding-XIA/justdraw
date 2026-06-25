//
//  KCCanvasSnapshot.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCCommon

/// An immutable snapshot of the canvas, used for undo/redo and serialization.
///
/// Modeled on the Objective-C `KDCanvasState`: a background raster (PNG bytes),
/// the committed strokes, and the placed stickers. Keeping the background as
/// `Data` keeps this type `UIKit`-free and `Codable`; the app/engine layer
/// produces the bytes when rasterizing flood-fill results or line art.
public struct KCCanvasSnapshot: Codable, Equatable, Sendable {
    public var backgroundImageData: Data?
    public var strokes: [KCStroke]
    public var stickers: [KCStickerItem]

    public init(
        backgroundImageData: Data? = nil,
        strokes: [KCStroke] = [],
        stickers: [KCStickerItem] = []
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
