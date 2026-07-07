//
//  KCLineArtFeature.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit
import KCContentCatalog

/// App 层线稿 Feature：负责把内容目录中的线稿元数据和 DrawingEngine 几何连接起来，
/// 并提供缩略图/画布线稿图片渲染。控制器只负责展示弹窗和响应点击。
final class KCLineArtFeature {
    private let contentCatalog: KCBundledContentCatalog
    private let drawingEngine: KCDrawingEngineProviding
    private let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 32
        return cache
    }()
    private let thumbnailRenderingQueue = DispatchQueue(label: "com.kidcanvas.line-art.thumbnail-rendering", qos: .userInitiated)

    init(contentCatalog: KCBundledContentCatalog, drawingEngine: KCDrawingEngineProviding) {
        self.contentCatalog = contentCatalog
        self.drawingEngine = drawingEngine
    }

    func makeLineArtItems() -> [KCLineArtItem] {
        self.contentCatalog.lineArtTemplates.compactMap { template in
            guard self.hasDrawing(forTemplateId: template.id) else { return nil }
            return KCLineArtItem(id: template.id, title: template.title)
        }
    }

    func thumbnailImage(for item: KCLineArtItem) -> UIImage {
        let cacheKey = item.id as NSString
        if let cachedImage = self.thumbnailCache.object(forKey: cacheKey) {
            return cachedImage
        }

        let image = self.renderThumbnailImage(for: item)
        self.thumbnailCache.setObject(image, forKey: cacheKey)
        return image
    }

    func cachedThumbnailImage(for item: KCLineArtItem) -> UIImage? {
        self.thumbnailCache.object(forKey: item.id as NSString)
    }

    func prepareThumbnailImage(for item: KCLineArtItem, completion: @escaping (KCLineArtItem, UIImage) -> Void) {
        if let cachedImage = cachedThumbnailImage(for: item) {
            DispatchQueue.main.async {
                completion(item, cachedImage)
            }
            return
        }

        self.thumbnailRenderingQueue.async { [weak self, item] in
            guard let self else { return }
            let image = self.thumbnailImage(for: item)
            DispatchQueue.main.async {
                completion(item, image)
            }
        }
    }

    private func renderThumbnailImage(for item: KCLineArtItem) -> UIImage {
        let size = CGSize(width: 160.0, height: 112.0)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { (_: UIGraphicsImageRendererContext) in
            UIColor(red: 1.0, green: 0.995, blue: 0.98, alpha: 1.0).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.18, green: 0.23, blue: 0.30, alpha: 1.0).setStroke()

            let drawingRect = CGRect(origin: .zero, size: size).insetBy(dx: 22.0, dy: 18.0)
            let context = UIGraphicsGetCurrentContext()
            context?.saveGState()
            let scale = min(drawingRect.size.width / 520.0, drawingRect.size.height / 420.0)
            context?.translateBy(x: drawingRect.midX, y: drawingRect.midY)
            context?.scaleBy(x: scale, y: scale)
            context?.translateBy(x: -260.0, y: -210.0)
            self.draw(item, in: CGRect(x: 0.0, y: 0.0, width: 520.0, height: 420.0), strokeScale: 0.22)
            context?.restoreGState()
        }
    }

    func lineArtImage(for item: KCLineArtItem, canvasSize: CGSize, drawingRect: CGRect? = nil) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { (rendererContext: UIGraphicsImageRendererContext) in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvasSize))
            let context = rendererContext.cgContext
            context.setLineWidth(12.0)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(UIColor.black.cgColor)

            let fallbackRect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: 110.0, dy: 90.0)
            let targetRect = drawingRect ?? CGRect(origin: .zero, size: canvasSize).insetBy(dx: 110.0, dy: 90.0)
            self.draw(item, in: targetRect.isEmpty ? fallbackRect : targetRect, strokeScale: 1.0)
        }
    }

    private func hasDrawing(forTemplateId templateId: String) -> Bool {
        self.drawingEngine.lineArtDrawingBlock(templateId: templateId, stroke: { _, _ in }) != nil
    }

    private func draw(_ item: KCLineArtItem, in rect: CGRect, strokeScale: CGFloat) {
        let stroke: (_ path: UIBezierPath, _ lineWidth: CGFloat) -> Void = { path, width in
            self.strokePath(path, width: width, strokeScale: strokeScale)
        }
        self.drawingEngine.lineArtDrawingBlock(templateId: item.id, stroke: stroke)?(rect)
    }

    private func strokePath(_ path: UIBezierPath, width: CGFloat, strokeScale: CGFloat) {
        path.lineWidth = width * strokeScale
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}

struct KCLineArtItem: Equatable {
    let id: String
    let title: String
}
