//
//  KCToolRailFeature.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit

/// App 层左侧工具栏 Feature：集中工具项配置、强调色和选中态样式。
final class KCToolRailFeature {
    private let pickerBackgroundColor = UIColor(red: 0.96, green: 0.85, blue: 0.48, alpha: 1.0)

    func toolItems() -> [KCToolRailItem] {
        [
            KCToolRailItem(id: "brush", mode: .brush, symbolName: "pencil.tip", title: KCL10n.toolBrushTitle),
            KCToolRailItem(id: "eraser", mode: .eraser, symbolName: "eraser", title: KCL10n.toolEraserTitle),
            KCToolRailItem(id: "fill", mode: .fill, symbolName: "paintbrush.pointed", title: KCL10n.toolFillTitle),
            KCToolRailItem(id: "sticker", mode: .sticker, symbolName: "seal.fill", title: KCL10n.toolStickerTitle),
            KCToolRailItem(id: "eyedropper", mode: .picker, symbolName: "eyedropper.halffull", title: KCL10n.toolPickerTitle)
        ]
    }

    /// 左侧工具按钮强调色。当前只有取色器使用黄色强调背景。
    func accentColor(for mode: KDToolMode) -> UIColor? {
        mode == .picker ? self.pickerBackgroundColor : nil
    }

    func isButton(_ button: KDToolButton, activeFor toolMode: KDToolMode) -> Bool {
        button.toolMode == toolMode
    }

    /// 应用左侧工具栏选中态样式，控制器只负责遍历按钮和协调工具切换。
    func applySelectionAppearance(to button: KDToolButton, active: Bool) {
        button.backgroundColor = active
            ? KCEditorVisualStyle.accentColor
            : (self.accentColor(for: button.toolMode) ?? KCEditorVisualStyle.raisedBackgroundColor)
        button.tintColor = active ? KCEditorVisualStyle.accentInkColor : KCEditorVisualStyle.inkColor
        button.layer.borderColor = active ? KCEditorVisualStyle.activeBorderColor : KCEditorVisualStyle.borderColor
        button.layer.shadowOpacity = active ? 0.12 : 0.06
        button.layer.shadowRadius = active ? 8.0 : 6.0
        button.transform = .identity
    }
}

struct KCToolRailItem: Equatable {
    let id: String
    let mode: KDToolMode
    let symbolName: String
    let title: String
}
