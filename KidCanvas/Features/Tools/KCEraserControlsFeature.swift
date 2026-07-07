//
//  KCEraserControlsFeature.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit

/// App 层橡皮擦控件 Feature：集中橡皮擦尺寸预览路径和形状按钮选中态样式。
final class KCEraserControlsFeature {
    func previewPath(for shape: KDEraserShape, center: CGPoint, size: CGFloat) -> UIBezierPath {
        let radius = size / 2.0
        switch shape {
        case .circle:
            return UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: size, height: size))
        case .cloud:
            let path = UIBezierPath()
            path.append(UIBezierPath(ovalIn: CGRect(x: center.x - radius * 1.05, y: center.y - radius * 0.32, width: radius * 0.95, height: radius * 0.74)))
            path.append(UIBezierPath(ovalIn: CGRect(x: center.x - radius * 0.42, y: center.y - radius * 0.78, width: radius * 1.02, height: radius * 0.98)))
            path.append(UIBezierPath(ovalIn: CGRect(x: center.x + radius * 0.18, y: center.y - radius * 0.28, width: radius * 0.90, height: radius * 0.70)))
            return path
        case .star:
            return self.starPath(center: center, radius: radius)
        }
    }

    func isShape(_ shape: KDEraserShape, activeFor currentShape: KDEraserShape) -> Bool {
        shape == currentShape
    }

    /// 应用橡皮擦形状按钮选中态样式，控制器只负责按钮集合和事件协调。
    func applyShapeButtonAppearance(to button: UIButton, active: Bool) {
        KCEditorVisualStyle.applySelectableButtonAppearance(
            to: button,
            active: active,
            baseBackgroundColor: KCEditorVisualStyle.compactBackgroundColor,
            activeShadowRadius: 6.0,
            inactiveShadowRadius: 4.0
        )
    }

    private func starPath(center: CGPoint, radius: CGFloat) -> UIBezierPath {
        let star = UIBezierPath()
        let points = 5
        let innerRadius = radius * 0.45
        for index in 0..<(points * 2) {
            let angle = (-CGFloat.pi / 2.0) + CGFloat(index) * (CGFloat.pi / CGFloat(points))
            let currentRadius = (index % 2 == 0) ? radius : innerRadius
            let point = CGPoint(x: center.x + currentRadius * cos(angle), y: center.y + currentRadius * sin(angle))
            if index == 0 {
                star.move(to: point)
            } else {
                star.addLine(to: point)
            }
        }
        star.close()
        return star
    }
}
