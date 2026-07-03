//
//  KCToolStateChipTitle.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/26.
//

/// 工具状态芯片（折叠态显示当前工具）的展示逻辑：把当前工具/画笔映射为本地化 key。
/// 纯展示逻辑、UIKit-free，供 `KCEditorPanelsFeature` 的折叠芯片复用（T017 Feature 拆分）。
///
/// 本类型只返回**稳定的本地化 key**（ASCII），不直接调用 `NSLocalizedString`（避免 bundle
/// 依赖、保持可单测）；由 App 层 `KCL10n.tr(...)` 解析为最终展示文案（见 T025/T026）。
public enum KCToolStateChipTitle {
    /// 返回当前工具在芯片上的标题本地化 key。
    public static func title(tool: KCToolMode, brush: KCBrushStyle) -> String {
        switch tool {
        case .eraser: return "chip.title.eraser"
        case .fill: return "chip.title.fill"
        case .picker: return "chip.title.picker"
        case .sticker: return "chip.title.sticker"
        case .brush:
            switch brush {
            case .pencil: return "chip.title.pencil"
            case .pen: return "chip.title.pen"
            case .crayon: return "chip.title.crayon"
            }
        }
    }
}
