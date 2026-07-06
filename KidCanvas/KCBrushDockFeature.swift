//
//  KCBrushDockFeature.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit

/// App 层画笔 Dock Feature：集中底部画笔项配置，控制器只负责创建按钮和绑定事件。
final class KCBrushDockFeature {
    private let activeBackgroundColor = UIColor(red: 0.66, green: 0.89, blue: 0.72, alpha: 1.0)
    private let inactiveBackgroundColor = UIColor(white: 1.0, alpha: 0.84)
    private let activeBorderColor = UIColor(white: 1.0, alpha: 0.94)
    private let inactiveBorderColor = UIColor(white: 1.0, alpha: 0.72)

    func brushItems() -> [KCBrushDockItem] {
        [
            KCBrushDockItem(
                id: "pencil",
                style: .pencil,
                mode: .brush,
                representsBrushStyle: true,
                symbolName: "pencil.tip",
                accentColor: self.brushColor(for: .pencil),
                title: KCL10n.pencilTitle
            ),
            KCBrushDockItem(
                id: "pen",
                style: .pen,
                mode: .brush,
                representsBrushStyle: true,
                symbolName: "pencil",
                accentColor: self.brushColor(for: .pen),
                title: KCL10n.penTitle
            ),
            KCBrushDockItem(
                id: "crayon",
                style: .crayon,
                mode: .brush,
                representsBrushStyle: true,
                symbolName: "paintbrush.pointed.fill",
                accentColor: self.brushColor(for: .crayon),
                title: KCL10n.crayonTitle
            )
        ]
    }

    /// 画笔卡片强调色（按画笔枚举匹配；标题不参与匹配，便于本地化）。
    func brushColor(for style: KDBrushStyle) -> UIColor {
        switch style {
        case .pencil:
            return UIColor(red: 0.94, green: 0.43, blue: 0.45, alpha: 1.0)
        case .pen:
            return UIColor(red: 0.45, green: 0.73, blue: 0.97, alpha: 1.0)
        case .crayon:
            return UIColor(red: 0.93, green: 0.62, blue: 0.41, alpha: 1.0)
        }
    }

    func isButton(_ button: KDBrushButton, activeForToolMode toolMode: KDToolMode, brushStyle: KDBrushStyle) -> Bool {
        button.representsBrushStyle
            ? (toolMode == .brush && button.brushStyle == brushStyle)
            : (button.toolMode == toolMode)
    }

    func button(_ button: KDBrushButton, matchesToolMode toolMode: KDToolMode, brushStyle: KDBrushStyle) -> Bool {
        self.isButton(button, activeForToolMode: toolMode, brushStyle: brushStyle)
    }

    /// 应用底部画笔 Dock 的选中态样式，控制器只负责滚动和事件协调。
    func applySelectionAppearance(to button: KDBrushButton, active: Bool) {
        button.backgroundColor = active ? self.activeBackgroundColor : self.inactiveBackgroundColor
        button.layer.borderColor = (active ? self.activeBorderColor : self.inactiveBorderColor).cgColor
        button.layer.shadowOpacity = active ? 0.20 : 0.12
        button.transform = active ? CGAffineTransform(scaleX: 1.03, y: 1.03) : .identity
    }
}

struct KCBrushDockItem: Equatable {
    let id: String
    let style: KDBrushStyle
    let mode: KDToolMode
    let representsBrushStyle: Bool
    let symbolName: String
    let accentColor: UIColor
    let title: String

    static func == (lhs: KCBrushDockItem, rhs: KCBrushDockItem) -> Bool {
        lhs.id == rhs.id
            && lhs.style == rhs.style
            && lhs.mode == rhs.mode
            && lhs.representsBrushStyle == rhs.representsBrushStyle
            && lhs.symbolName == rhs.symbolName
            && lhs.accentColor.isEqual(rhs.accentColor)
            && lhs.title == rhs.title
    }
}
