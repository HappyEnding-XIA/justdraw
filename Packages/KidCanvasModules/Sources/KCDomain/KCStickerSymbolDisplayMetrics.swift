//
//  KCStickerSymbolDisplayMetrics.swift
//  KCDomain
//
//  Created by 小大 on 2026/07/07.
//

import CoreGraphics
import Foundation

/// 印章 SF Symbol 的显示指标。
///
/// 这里只维护不依赖 UIKit 的纯数值：容器边长、符号点大小、描边点大小和
/// 内容安全边距。真实 `UIImage` 生成仍由 App 层画布完成。
public struct KCStickerSymbolDisplayMetrics: Equatable, Sendable {

    /// 印章视图的默认正方形容器边长。
    public let canvasSide: CGFloat

    /// 彩色主体符号使用的 SF Symbol point size。
    public let symbolPointSize: CGFloat

    /// 白色描边符号使用的 SF Symbol point size。
    public let outlinePointSize: CGFloat

    /// 绘制时预留给描边、阴影和外轮廓的安全边距。
    public let contentInset: CGFloat

    public init(
        canvasSide: CGFloat,
        symbolPointSize: CGFloat,
        outlinePointSize: CGFloat,
        contentInset: CGFloat
    ) {
        self.canvasSide = canvasSide
        self.symbolPointSize = symbolPointSize
        self.outlinePointSize = outlinePointSize
        self.contentInset = contentInset
    }

    /// 根据 SF Symbol 返回印章显示指标。
    public static func metrics(forSymbol symbol: String) -> KCStickerSymbolDisplayMetrics {
        if largeAnimalSymbols.contains(symbol) {
            return largeAnimalMetrics
        }

        return standardMetrics
    }

    private static let standardMetrics = KCStickerSymbolDisplayMetrics(
        canvasSide: 72.0,
        symbolPointSize: 54.0,
        outlinePointSize: 60.0,
        contentInset: 6.0
    )

    private static let largeAnimalMetrics = KCStickerSymbolDisplayMetrics(
        canvasSide: 72.0,
        symbolPointSize: 46.0,
        outlinePointSize: 52.0,
        contentInset: 10.0
    )

    private static let largeAnimalSymbols: Set<String> = ["hare.fill", "tortoise.fill", "butterfly.fill"]
}
