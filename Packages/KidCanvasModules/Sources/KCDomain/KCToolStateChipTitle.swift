//
//  KCToolStateChipTitle.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/26.
//

/// 工具状态芯片（折叠态显示当前工具）的展示逻辑：把当前工具/画笔映射为标题文本。
/// 纯展示逻辑、UIKit-free，供 `KCEditorPanelsFeature` 的折叠芯片复用（T017 Feature 拆分）。
public enum KCToolStateChipTitle {
    /// 返回当前工具在芯片上的标题文本。
    public static func title(tool: KCToolMode, brush: KCBrushStyle) -> String {
        switch tool {
        case .eraser: return "Eraser"
        case .fill: return "Fill"
        case .picker: return "Eyedropper"
        case .sticker: return "Sticker"
        case .brush:
            switch brush {
            case .pencil: return "Pencil"
            case .pen: return "Pen"
            case .crayon: return "Crayon"
            }
        }
    }
}
