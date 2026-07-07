//
//  KCEditorToolControls.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/07.
//

import UIKit
import KCDomain

// MARK: - 工具按钮

class KDToolButton: UIButton {
    var toolMode: KDToolMode = .brush
}

class KDBrushButton: UIButton {
    var brushStyle: KDBrushStyle = .pencil
    var toolMode: KDToolMode = .brush
    var representsBrushStyle: Bool = false
}

// MARK: - 工具模式映射

extension KDToolMode {
    init(domainToolMode: KCToolMode) {
        switch domainToolMode {
        case .brush: self = .brush
        case .eraser: self = .eraser
        case .fill: self = .fill
        case .sticker: self = .sticker
        case .picker: self = .picker
        }
    }

    var domainToolMode: KCToolMode {
        switch self {
        case .brush: return .brush
        case .eraser: return .eraser
        case .fill: return .fill
        case .sticker: return .sticker
        case .picker: return .picker
        }
    }
}
