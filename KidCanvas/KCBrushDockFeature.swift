//
//  KCBrushDockFeature.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit

/// App 层画笔 Dock Feature：集中底部画笔项配置，控制器只负责创建按钮和绑定事件。
final class KCBrushDockFeature {
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
        KCEditorVisualStyle.applySelectableButtonAppearance(
            to: button,
            active: active,
            baseBackgroundColor: KCEditorVisualStyle.raisedBackgroundColor,
            activeShadowRadius: 9.0,
            inactiveShadowRadius: 6.0
        )
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
