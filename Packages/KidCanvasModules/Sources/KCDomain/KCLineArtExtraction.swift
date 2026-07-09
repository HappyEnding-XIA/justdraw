//
//  KCLineArtExtraction.swift
//  KCDomain
//
//  Created by 小大 on 2026/07/09.
//

import Foundation
import KCCommon

/// 离线线稿生成结果（T101）。位图线稿 PNG + 缩略图 JPEG + 质量分级。
/// 不做矢量化，不上传图片；pipeline 核心在 `KCDrawingEngine`，UIKit-free。
public struct KCLineArtExtractionResult: Equatable, Sendable {
    public let lineArtPNG: Data
    public let thumbnailJPEG: Data
    public let quality: KCLineArtQuality

    public init(lineArtPNG: Data, thumbnailJPEG: Data, quality: KCLineArtQuality) {
        self.lineArtPNG = lineArtPNG
        self.thumbnailJPEG = thumbnailJPEG
        self.quality = quality
    }
}

/// 线稿生成质量分级。`poor` 表示该图片可能不适合生成线稿（过暗/过糊/边缘过少等），
/// 由 App 层给出“这张图片可能不适合”的提示并允许重试/取消；非 `poor` 可使用。
public enum KCLineArtQuality: String, Equatable, Sendable {
    case good
    case marginal
    case poor

    public var isUsable: Bool { self != .poor }
}

/// 离线图片生成线稿契约（UIKit-free）。输入图片 `Data`，输出位图线稿结果；
/// 无法解码或无法生成时返回 `nil`，由 App 层给出失败反馈。
public protocol KCLineArtExtracting: Sendable {
    func extract(from imageData: Data) -> KCLineArtExtractionResult?
}
