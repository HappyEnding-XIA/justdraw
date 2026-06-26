//
//  KCCanvasSnapshot.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCCommon

/// 画布的不可变快照，用于撤销/重做与序列化。
///
/// 以 Objective-C 的 `KDCanvasState` 为蓝本：包含背景位图（PNG 字节）、
/// 已提交的笔画，以及已放置的贴纸。将背景保存为 `Data` 使该类型保持
/// 不依赖 `UIKit` 且可 `Codable`；App/引擎层在栅格化油漆桶填充结果或
/// 线稿时产出这些字节。
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

    /// 当存在任何可渲染内容时为 `true`——对应原型中的
    /// `canvasStateHasVisibleContent:`。
    public var hasVisibleContent: Bool {
        backgroundImageData != nil || !strokes.isEmpty || !stickers.isEmpty
    }
}
