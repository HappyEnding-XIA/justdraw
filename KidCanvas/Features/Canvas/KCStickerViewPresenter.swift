//
//  KCStickerViewPresenter.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/07.
//

import UIKit
import KCDomain

/// 印章视图呈现工具，集中处理 SF Symbol 图片生成和选中态外观。
final class KCStickerViewPresenter {
    private static let fallbackSymbol = "star.fill"
    private static let cornerRadius: CGFloat = 18.0
    private static let idleShadowOpacity: Float = 0.16
    private static let selectedShadowOpacity: Float = 0.26
    private static let stickerImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 160
        return cache
    }()

    func makeStickerView(withSymbol symbol: String, color: UIColor) -> KDStickerView {
        let resolvedSymbol = symbol.isEmpty ? Self.fallbackSymbol : symbol
        let metrics = KCStickerSymbolDisplayMetrics.metrics(forSymbol: resolvedSymbol)
        let sticker = KDStickerView(image: stickerImage(forSymbol: resolvedSymbol, color: color, metrics: metrics))
        sticker.symbolName = resolvedSymbol
        sticker.symbolColor = color
        sticker.isUserInteractionEnabled = true
        sticker.bounds = CGRect(x: 0.0, y: 0.0, width: metrics.canvasSide, height: metrics.canvasSide)
        sticker.contentMode = .scaleAspectFit
        applyIdleAppearance(to: sticker)
        return sticker
    }

    func applyIdleAppearance(to sticker: KDStickerView) {
        sticker.layer.cornerRadius = Self.cornerRadius
        sticker.layer.cornerCurve = .continuous
        sticker.layer.borderWidth = 0.0
        sticker.layer.borderColor = UIColor.clear.cgColor
        sticker.layer.shadowColor = KCEditorVisualStyle.shadowColor
        sticker.layer.shadowOpacity = Self.idleShadowOpacity
        sticker.layer.shadowRadius = 8.0
        sticker.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
    }

    func applySelectedAppearance(to sticker: KDStickerView) {
        sticker.layer.cornerRadius = Self.cornerRadius
        sticker.layer.cornerCurve = .continuous
        sticker.layer.borderWidth = 3.0
        sticker.layer.borderColor = KCEditorVisualStyle.saveActionColor.withAlphaComponent(0.88).cgColor
        sticker.layer.shadowColor = KCEditorVisualStyle.saveActionColor.cgColor
        sticker.layer.shadowOpacity = Self.selectedShadowOpacity
        sticker.layer.shadowRadius = 12.0
        sticker.layer.shadowOffset = CGSize(width: 0.0, height: 5.0)
    }

    private func stickerImage(
        forSymbol symbol: String,
        color: UIColor,
        metrics: KCStickerSymbolDisplayMetrics
    ) -> UIImage {
        let cacheKey = stickerImageCacheKey(forSymbol: symbol, color: color, metrics: metrics)
        if let cachedImage = Self.stickerImageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        let imageSize = CGSize(width: metrics.canvasSide, height: metrics.canvasSide)
        let contentRect = CGRect(origin: .zero, size: imageSize).insetBy(
            dx: metrics.contentInset,
            dy: metrics.contentInset
        )
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let image = renderer.image { _ in
            let resolvedSymbol = renderableSymbol(symbol)
            let outlineConfiguration = UIImage.SymbolConfiguration(pointSize: metrics.outlinePointSize, weight: .bold)
            if let outlineImage = UIImage(systemName: resolvedSymbol, withConfiguration: outlineConfiguration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let outlineRect = aspectFitRect(for: outlineImage.size, in: contentRect)
                outlineImage.draw(in: outlineRect)
            }

            let configuration = UIImage.SymbolConfiguration(pointSize: metrics.symbolPointSize, weight: .semibold)
            if let symbolImage = UIImage(systemName: resolvedSymbol, withConfiguration: configuration)?
                .withTintColor(color, renderingMode: .alwaysOriginal) {
                let symbolRect = aspectFitRect(for: symbolImage.size, in: contentRect)
                symbolImage.draw(in: symbolRect)
            }
        }
        Self.stickerImageCache.setObject(image, forKey: cacheKey)
        return image
    }

    private func renderableSymbol(_ symbol: String) -> String {
        if KCEditorUIFactory.cachedSystemImage(symbolName: symbol) != nil {
            return symbol
        }
        return Self.fallbackSymbol
    }

    private func stickerImageCacheKey(
        forSymbol symbol: String,
        color: UIColor,
        metrics: KCStickerSymbolDisplayMetrics
    ) -> NSString {
        let resolvedSymbol = renderableSymbol(symbol)
        let components = rgbaCacheComponents(for: color)
        let parts = [
            resolvedSymbol,
            String(components.red),
            String(components.green),
            String(components.blue),
            String(components.alpha),
            metricCacheComponent(metrics.canvasSide),
            metricCacheComponent(metrics.contentInset),
            metricCacheComponent(metrics.symbolPointSize),
            metricCacheComponent(metrics.outlinePointSize)
        ]
        return parts.joined(separator: "|") as NSString
    }

    private func rgbaCacheComponents(for color: UIColor) -> (red: Int, green: Int, blue: Int, alpha: Int) {
        let resolvedColor = color.resolvedColor(with: UITraitCollection.current)
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        guard resolvedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return (0, 0, 0, 255)
        }

        return (
            rgbaCacheComponent(red),
            rgbaCacheComponent(green),
            rgbaCacheComponent(blue),
            rgbaCacheComponent(alpha)
        )
    }

    private func rgbaCacheComponent(_ value: CGFloat) -> Int {
        Int(round(max(0.0, min(1.0, value)) * 255.0))
    }

    private func metricCacheComponent(_ value: CGFloat) -> String {
        String(Int(round(value * 100.0)))
    }

    private func aspectFitRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0.0, imageSize.height > 0.0, bounds.width > 0.0, bounds.height > 0.0 else {
            return bounds
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - fittedSize.width / 2.0,
            y: bounds.midY - fittedSize.height / 2.0,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}
