//
//  KCContentTypes.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCCommon

/// 具名调色板（例如内置的 24 色和 36 色集合）。
public struct KCContentPalette: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var title: String
    public var colors: [KCHexColor]

    public init(id: String, title: String, colors: [KCHexColor]) {
        self.id = id
        self.title = title
        self.colors = colors
    }
}

/// 一组共享同一分类的贴纸 SF Symbol 标识符。
public struct KCStickerGroup: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var title: String
    public var symbols: [String]

    public init(id: String, title: String, symbols: [String]) {
        self.id = id
        self.title = title
        self.symbols = symbols
    }
}

/// 内置线稿模板的元数据。实际的程序化绘制由绘图引擎完成；该类型仅描述
/// 目录条目信息。
public struct KCLineArtTemplate: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var title: String
    public var category: String

    public init(id: String, title: String, category: String) {
        self.id = id
        self.title = title
        self.category = category
    }
}
