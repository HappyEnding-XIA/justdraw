//
//  KCLineArtDrawing.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/07/06.
//

import CoreGraphics

/// 单条线稿描边指令。`path` 描述几何，`lineWidth` 描述原型线宽。
public struct KCLineArtStroke {
    public let path: CGPath
    public let lineWidth: CGFloat

    public init(path: CGPath, lineWidth: CGFloat) {
        self.path = path
        self.lineWidth = lineWidth
    }
}

/// 内置线稿的程序化绘制几何。这里保持无 UIKit 依赖，App 层只负责把 `CGPath`
/// 转为实际绘制上下文中的描边。
public enum KCLineArtDrawing {
    public static let supportedTemplateIds: [String] = [
        "bunny", "car", "fish", "flower", "house", "rocket", "cupcake", "dino",
    ]

    public static func strokes(forTemplateId templateId: String, in rect: CGRect) -> [KCLineArtStroke]? {
        guard let strokes = rawStrokes(forTemplateId: templateId, in: rect) else { return nil }
        return centered(strokes, in: rect)
    }

    private static func rawStrokes(forTemplateId templateId: String, in rect: CGRect) -> [KCLineArtStroke]? {
        switch templateId {
        case "bunny": return bunny(in: rect)
        case "car": return car(in: rect)
        case "fish": return fish(in: rect)
        case "flower": return flower(in: rect)
        case "house": return house(in: rect)
        case "rocket": return rocket(in: rect)
        case "cupcake": return cupcake(in: rect)
        case "dino": return dino(in: rect)
        default: return nil
        }
    }

    private static func centered(_ strokes: [KCLineArtStroke], in rect: CGRect) -> [KCLineArtStroke] {
        guard let artworkBounds = unionBounds(for: strokes) else { return strokes }
        let translation = CGAffineTransform(
            translationX: rect.midX - artworkBounds.midX,
            y: rect.midY - artworkBounds.midY
        )

        return strokes.map { stroke in
            var transform = translation
            guard let path = stroke.path.copy(using: &transform) else { return stroke }
            return KCLineArtStroke(path: path, lineWidth: stroke.lineWidth)
        }
    }

    private static func unionBounds(for strokes: [KCLineArtStroke]) -> CGRect? {
        strokes
            .map(\.path.boundingBoxOfPath)
            .filter { !$0.isEmpty }
            .reduce(nil) { partialResult, bounds in
                guard let partialResult else { return bounds }
                return partialResult.union(bounds)
            }
    }

    private static func bunny(in rect: CGRect) -> [KCLineArtStroke] {
        let centerX = rect.midX
        let centerY = rect.midY + 18.0
        var strokes: [KCLineArtStroke] = []

        strokes.add(roundedRect(x: centerX - 132.0, y: centerY - 220.0, width: 54.0, height: 150.0, radius: 28.0), 12.0)
        strokes.add(roundedRect(x: centerX + 78.0, y: centerY - 220.0, width: 54.0, height: 150.0, radius: 28.0), 12.0)
        strokes.add(ellipse(x: centerX - 138.0, y: centerY - 108.0, width: 276.0, height: 216.0), 12.0)
        strokes.add(ellipse(x: centerX - 80.0, y: centerY - 18.0, width: 160.0, height: 120.0), 12.0)
        strokes.add(ellipse(x: centerX - 88.0, y: centerY + 82.0, width: 72.0, height: 52.0), 12.0)
        strokes.add(ellipse(x: centerX + 16.0, y: centerY + 82.0, width: 72.0, height: 52.0), 12.0)
        strokes.add(ellipse(x: centerX - 86.0, y: centerY - 20.0, width: 36.0, height: 48.0), 12.0)
        strokes.add(ellipse(x: centerX + 50.0, y: centerY - 20.0, width: 36.0, height: 48.0), 12.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX, y: centerY + 20.0))
            path.addLine(to: CGPoint(x: centerX - 24.0, y: centerY + 46.0))
            path.addLine(to: CGPoint(x: centerX + 24.0, y: centerY + 46.0))
            path.closeSubpath()
        }, 12.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX, y: centerY + 46.0))
            path.addCurve(
                to: CGPoint(x: centerX - 34.0, y: centerY + 72.0),
                control1: CGPoint(x: centerX - 2.0, y: centerY + 63.0),
                control2: CGPoint(x: centerX - 18.0, y: centerY + 76.0)
            )
            path.move(to: CGPoint(x: centerX, y: centerY + 46.0))
            path.addCurve(
                to: CGPoint(x: centerX + 34.0, y: centerY + 72.0),
                control1: CGPoint(x: centerX + 2.0, y: centerY + 63.0),
                control2: CGPoint(x: centerX + 18.0, y: centerY + 76.0)
            )
        }, 12.0)
        return strokes
    }

    private static func car(in rect: CGRect) -> [KCLineArtStroke] {
        let baseY = rect.maxY - 90.0
        let leftX = rect.minX + 80.0
        var strokes: [KCLineArtStroke] = []

        strokes.add(path { path in
            path.move(to: CGPoint(x: leftX, y: baseY))
            path.addLine(to: CGPoint(x: leftX + 92.0, y: baseY - 94.0))
            path.addLine(to: CGPoint(x: leftX + 250.0, y: baseY - 94.0))
            path.addLine(to: CGPoint(x: leftX + 334.0, y: baseY))
            path.addLine(to: CGPoint(x: leftX + 402.0, y: baseY))
            path.addCurve(
                to: CGPoint(x: leftX + 456.0, y: baseY + 38.0),
                control1: CGPoint(x: leftX + 430.0, y: baseY),
                control2: CGPoint(x: leftX + 456.0, y: baseY + 10.0)
            )
            path.addLine(to: CGPoint(x: leftX + 456.0, y: baseY + 86.0))
            path.addLine(to: CGPoint(x: leftX - 10.0, y: baseY + 86.0))
            path.addLine(to: CGPoint(x: leftX - 10.0, y: baseY + 24.0))
            path.addCurve(
                to: CGPoint(x: leftX, y: baseY),
                control1: CGPoint(x: leftX - 10.0, y: baseY + 10.0),
                control2: CGPoint(x: leftX - 4.0, y: baseY)
            )
            path.closeSubpath()
        }, 12.0)
        strokes.add(roundedRect(x: leftX + 110.0, y: baseY - 78.0, width: 112.0, height: 76.0, radius: 18.0), 12.0)
        strokes.add(roundedRect(x: leftX + 232.0, y: baseY - 78.0, width: 90.0, height: 76.0, radius: 18.0), 12.0)
        strokes.add(ellipse(x: leftX + 52.0, y: baseY + 32.0, width: 96.0, height: 96.0), 12.0)
        strokes.add(ellipse(x: leftX + 296.0, y: baseY + 32.0, width: 96.0, height: 96.0), 12.0)
        strokes.add(ellipse(x: leftX + 76.0, y: baseY + 56.0, width: 48.0, height: 48.0), 12.0)
        strokes.add(ellipse(x: leftX + 320.0, y: baseY + 56.0, width: 48.0, height: 48.0), 12.0)
        return strokes
    }

    private static func fish(in rect: CGRect) -> [KCLineArtStroke] {
        let centerX = rect.midX
        let centerY = rect.midY
        var strokes: [KCLineArtStroke] = []

        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX - 160.0, y: centerY))
            path.addCurve(
                to: CGPoint(x: centerX + 74.0, y: centerY - 118.0),
                control1: CGPoint(x: centerX - 126.0, y: centerY - 122.0),
                control2: CGPoint(x: centerX + 8.0, y: centerY - 150.0)
            )
            path.addCurve(
                to: CGPoint(x: centerX + 74.0, y: centerY + 118.0),
                control1: CGPoint(x: centerX + 148.0, y: centerY - 80.0),
                control2: CGPoint(x: centerX + 148.0, y: centerY + 80.0)
            )
            path.addCurve(
                to: CGPoint(x: centerX - 160.0, y: centerY),
                control1: CGPoint(x: centerX + 8.0, y: centerY + 150.0),
                control2: CGPoint(x: centerX - 126.0, y: centerY + 122.0)
            )
            path.closeSubpath()
        }, 12.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX + 74.0, y: centerY))
            path.addLine(to: CGPoint(x: centerX + 208.0, y: centerY - 122.0))
            path.addLine(to: CGPoint(x: centerX + 208.0, y: centerY + 122.0))
            path.closeSubpath()
        }, 12.0)
        strokes.add(ellipse(x: centerX - 96.0, y: centerY - 24.0, width: 46.0, height: 46.0), 12.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX - 18.0, y: centerY - 26.0))
            path.addCurve(
                to: CGPoint(x: centerX + 48.0, y: centerY - 118.0),
                control1: CGPoint(x: centerX - 12.0, y: centerY - 90.0),
                control2: CGPoint(x: centerX + 26.0, y: centerY - 112.0)
            )
            path.addCurve(
                to: CGPoint(x: centerX + 92.0, y: centerY - 30.0),
                control1: CGPoint(x: centerX + 74.0, y: centerY - 116.0),
                control2: CGPoint(x: centerX + 98.0, y: centerY - 72.0)
            )
            path.closeSubpath()
        }, 12.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX - 130.0, y: centerY + 18.0))
            path.addCurve(
                to: CGPoint(x: centerX - 74.0, y: centerY + 42.0),
                control1: CGPoint(x: centerX - 116.0, y: centerY + 42.0),
                control2: CGPoint(x: centerX - 90.0, y: centerY + 54.0)
            )
        }, 12.0)
        return strokes
    }

    private static func flower(in rect: CGRect) -> [KCLineArtStroke] {
        let centerX = rect.midX
        let centerY = rect.midY - 24.0
        var strokes: [KCLineArtStroke] = []
        let petalCenters = [
            CGPoint(x: centerX, y: centerY - 114.0),
            CGPoint(x: centerX + 94.0, y: centerY - 34.0),
            CGPoint(x: centerX + 58.0, y: centerY + 86.0),
            CGPoint(x: centerX - 58.0, y: centerY + 86.0),
            CGPoint(x: centerX - 94.0, y: centerY - 34.0),
        ]
        for point in petalCenters {
            strokes.add(ellipse(x: point.x - 54.0, y: point.y - 62.0, width: 108.0, height: 124.0), 12.0)
        }
        strokes.add(ellipse(x: centerX - 52.0, y: centerY - 52.0, width: 104.0, height: 104.0), 12.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX, y: centerY + 54.0))
            path.addCurve(
                to: CGPoint(x: centerX - 12.0, y: rect.maxY - 18.0),
                control1: CGPoint(x: centerX + 8.0, y: centerY + 136.0),
                control2: CGPoint(x: centerX - 18.0, y: centerY + 222.0)
            )
        }, 12.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX - 8.0, y: centerY + 166.0))
            path.addCurve(
                to: CGPoint(x: centerX - 136.0, y: centerY + 136.0),
                control1: CGPoint(x: centerX - 38.0, y: centerY + 118.0),
                control2: CGPoint(x: centerX - 110.0, y: centerY + 112.0)
            )
            path.addCurve(
                to: CGPoint(x: centerX - 8.0, y: centerY + 166.0),
                control1: CGPoint(x: centerX - 114.0, y: centerY + 186.0),
                control2: CGPoint(x: centerX - 44.0, y: centerY + 194.0)
            )
            path.closeSubpath()
        }, 12.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX - 4.0, y: centerY + 232.0))
            path.addCurve(
                to: CGPoint(x: centerX + 124.0, y: centerY + 198.0),
                control1: CGPoint(x: centerX + 26.0, y: centerY + 188.0),
                control2: CGPoint(x: centerX + 96.0, y: centerY + 174.0)
            )
            path.addCurve(
                to: CGPoint(x: centerX - 4.0, y: centerY + 232.0),
                control1: CGPoint(x: centerX + 104.0, y: centerY + 244.0),
                control2: CGPoint(x: centerX + 38.0, y: centerY + 258.0)
            )
            path.closeSubpath()
        }, 12.0)
        return strokes
    }

    private static func house(in rect: CGRect) -> [KCLineArtStroke] {
        let centerX = rect.midX
        let baseY = rect.maxY - 56.0
        let houseWidth = min(rect.width - 120.0, 360.0)
        let leftX = centerX - houseWidth / 2.0
        let wallTop = baseY - 190.0
        var strokes: [KCLineArtStroke] = []

        strokes.add(path { path in
            path.move(to: CGPoint(x: leftX - 24.0, y: wallTop + 18.0))
            path.addLine(to: CGPoint(x: centerX, y: wallTop - 130.0))
            path.addLine(to: CGPoint(x: leftX + houseWidth + 24.0, y: wallTop + 18.0))
            path.closeSubpath()
        }, 12.0)
        strokes.add(roundedRect(x: leftX, y: wallTop, width: houseWidth, height: 190.0, radius: 22.0), 12.0)
        strokes.add(roundedRect(x: centerX - 42.0, y: baseY - 104.0, width: 84.0, height: 104.0, radius: 18.0), 12.0)
        strokes.add(roundedRect(x: leftX + 38.0, y: wallTop + 46.0, width: 84.0, height: 72.0, radius: 18.0), 12.0)
        strokes.add(roundedRect(x: leftX + houseWidth - 122.0, y: wallTop + 46.0, width: 84.0, height: 72.0, radius: 18.0), 12.0)
        return strokes
    }

    private static func rocket(in rect: CGRect) -> [KCLineArtStroke] {
        let centerX = rect.midX
        let topY = rect.minY + 32.0
        let bottomY = rect.maxY - 54.0
        var strokes: [KCLineArtStroke] = []

        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX, y: topY))
            path.addCurve(
                to: CGPoint(x: centerX + 74.0, y: topY + 150.0),
                control1: CGPoint(x: centerX + 58.0, y: topY + 38.0),
                control2: CGPoint(x: centerX + 86.0, y: topY + 96.0)
            )
            path.addLine(to: CGPoint(x: centerX + 54.0, y: bottomY - 78.0))
            path.addCurve(
                to: CGPoint(x: centerX - 54.0, y: bottomY - 78.0),
                control1: CGPoint(x: centerX + 24.0, y: bottomY - 42.0),
                control2: CGPoint(x: centerX - 24.0, y: bottomY - 42.0)
            )
            path.addLine(to: CGPoint(x: centerX - 74.0, y: topY + 150.0))
            path.addCurve(
                to: CGPoint(x: centerX, y: topY),
                control1: CGPoint(x: centerX - 86.0, y: topY + 96.0),
                control2: CGPoint(x: centerX - 58.0, y: topY + 38.0)
            )
            path.closeSubpath()
        }, 12.0)
        strokes.add(ellipse(x: centerX - 34.0, y: topY + 116.0, width: 68.0, height: 68.0), 12.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX - 58.0, y: bottomY - 112.0))
            path.addLine(to: CGPoint(x: centerX - 142.0, y: bottomY - 38.0))
            path.addLine(to: CGPoint(x: centerX - 44.0, y: bottomY - 44.0))
            path.closeSubpath()
        }, 12.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX + 58.0, y: bottomY - 112.0))
            path.addLine(to: CGPoint(x: centerX + 142.0, y: bottomY - 38.0))
            path.addLine(to: CGPoint(x: centerX + 44.0, y: bottomY - 44.0))
            path.closeSubpath()
        }, 12.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX - 30.0, y: bottomY - 40.0))
            path.addCurve(
                to: CGPoint(x: centerX, y: bottomY + 34.0),
                control1: CGPoint(x: centerX - 14.0, y: bottomY - 4.0),
                control2: CGPoint(x: centerX - 6.0, y: bottomY + 12.0)
            )
            path.addCurve(
                to: CGPoint(x: centerX + 30.0, y: bottomY - 40.0),
                control1: CGPoint(x: centerX + 8.0, y: bottomY + 10.0),
                control2: CGPoint(x: centerX + 16.0, y: bottomY - 6.0)
            )
            path.closeSubpath()
        }, 12.0)
        return strokes
    }

    private static func cupcake(in rect: CGRect) -> [KCLineArtStroke] {
        let centerX = rect.midX
        let centerY = rect.midY + 20.0
        var strokes: [KCLineArtStroke] = []

        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX - 142.0, y: centerY - 18.0))
            path.addCurve(
                to: CGPoint(x: centerX - 78.0, y: centerY - 112.0),
                control1: CGPoint(x: centerX - 150.0, y: centerY - 82.0),
                control2: CGPoint(x: centerX - 112.0, y: centerY - 116.0)
            )
            path.addCurve(
                to: CGPoint(x: centerX, y: centerY - 136.0),
                control1: CGPoint(x: centerX - 58.0, y: centerY - 168.0),
                control2: CGPoint(x: centerX - 18.0, y: centerY - 168.0)
            )
            path.addCurve(
                to: CGPoint(x: centerX + 78.0, y: centerY - 112.0),
                control1: CGPoint(x: centerX + 18.0, y: centerY - 168.0),
                control2: CGPoint(x: centerX + 58.0, y: centerY - 168.0)
            )
            path.addCurve(
                to: CGPoint(x: centerX + 142.0, y: centerY - 18.0),
                control1: CGPoint(x: centerX + 112.0, y: centerY - 116.0),
                control2: CGPoint(x: centerX + 150.0, y: centerY - 82.0)
            )
            path.addCurve(
                to: CGPoint(x: centerX - 142.0, y: centerY - 18.0),
                control1: CGPoint(x: centerX + 84.0, y: centerY + 16.0),
                control2: CGPoint(x: centerX - 84.0, y: centerY + 16.0)
            )
            path.closeSubpath()
        }, 12.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX - 118.0, y: centerY))
            path.addLine(to: CGPoint(x: centerX + 118.0, y: centerY))
            path.addLine(to: CGPoint(x: centerX + 82.0, y: centerY + 158.0))
            path.addLine(to: CGPoint(x: centerX - 82.0, y: centerY + 158.0))
            path.closeSubpath()
        }, 12.0)
        for index in -1...1 {
            strokes.add(
                ellipse(
                    x: centerX + CGFloat(index) * 58.0 - 12.0,
                    y: centerY - 70.0 + (index == 0 ? -24.0 : 0.0),
                    width: 24.0,
                    height: 24.0
                ),
                8.0
            )
        }
        return strokes
    }

    private static func dino(in rect: CGRect) -> [KCLineArtStroke] {
        let centerX = rect.midX
        let centerY = rect.midY + 28.0
        var strokes: [KCLineArtStroke] = []

        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX - 176.0, y: centerY + 16.0))
            path.addCurve(
                to: CGPoint(x: centerX - 44.0, y: centerY - 96.0),
                control1: CGPoint(x: centerX - 166.0, y: centerY - 68.0),
                control2: CGPoint(x: centerX - 104.0, y: centerY - 112.0)
            )
            path.addLine(to: CGPoint(x: centerX + 72.0, y: centerY - 96.0))
            path.addCurve(
                to: CGPoint(x: centerX + 178.0, y: centerY - 28.0),
                control1: CGPoint(x: centerX + 132.0, y: centerY - 96.0),
                control2: CGPoint(x: centerX + 178.0, y: centerY - 70.0)
            )
            path.addCurve(
                to: CGPoint(x: centerX + 120.0, y: centerY + 84.0),
                control1: CGPoint(x: centerX + 178.0, y: centerY + 40.0),
                control2: CGPoint(x: centerX + 156.0, y: centerY + 82.0)
            )
            path.addLine(to: CGPoint(x: centerX - 64.0, y: centerY + 84.0))
            path.addCurve(
                to: CGPoint(x: centerX - 176.0, y: centerY + 16.0),
                control1: CGPoint(x: centerX - 118.0, y: centerY + 84.0),
                control2: CGPoint(x: centerX - 160.0, y: centerY + 60.0)
            )
            path.closeSubpath()
        }, 12.0)
        strokes.add(ellipse(x: centerX + 94.0, y: centerY - 54.0, width: 28.0, height: 28.0), 9.0)
        strokes.add(path { path in
            path.move(to: CGPoint(x: centerX - 162.0, y: centerY + 20.0))
            path.addLine(to: CGPoint(x: centerX - 252.0, y: centerY - 44.0))
            path.addLine(to: CGPoint(x: centerX - 184.0, y: centerY + 64.0))
            path.closeSubpath()
        }, 12.0)
        strokes.add(path { path in
            for index in 0..<4 {
                let x = centerX - 56.0 + CGFloat(index) * 52.0
                path.move(to: CGPoint(x: x, y: centerY - 96.0))
                path.addLine(to: CGPoint(x: x + 26.0, y: centerY - 142.0))
                path.addLine(to: CGPoint(x: x + 52.0, y: centerY - 96.0))
            }
        }, 12.0)
        strokes.add(roundedRect(x: centerX - 52.0, y: centerY + 78.0, width: 42.0, height: 88.0, radius: 16.0), 12.0)
        strokes.add(roundedRect(x: centerX + 58.0, y: centerY + 78.0, width: 42.0, height: 88.0, radius: 16.0), 12.0)
        return strokes
    }

    private static func ellipse(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: x, y: y, width: width, height: height), transform: nil)
    }

    private static func roundedRect(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        radius: CGFloat
    ) -> CGPath {
        CGPath(
            roundedRect: CGRect(x: x, y: y, width: width, height: height),
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
    }

    private static func path(_ build: (CGMutablePath) -> Void) -> CGPath {
        let path = CGMutablePath()
        build(path)
        return path
    }
}

private extension Array where Element == KCLineArtStroke {
    mutating func add(_ path: CGPath, _ lineWidth: CGFloat) {
        append(KCLineArtStroke(path: path, lineWidth: lineWidth))
    }
}
