//
//  KCDrawingTool.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/25.
//

import Foundation

public enum KCToolMode: String, Codable, CaseIterable, Sendable {
    case brush
    case eraser
    case fill
    case sticker
    case picker
}

public enum KCBrushStyle: String, Codable, CaseIterable, Sendable {
    case pencil
    case pen
    case crayon
}

public enum KCEraserShape: String, Codable, CaseIterable, Sendable {
    case circle
    case cloud
    case star
}
