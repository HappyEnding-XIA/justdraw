//
//  KCImageImport.swift
//  KCDomain
//
//  Created by 小大 on 2026/07/09.
//

import Foundation
import KCCommon

/// 图片导入来源（T100）。相册导入作为新画布底图/新会话内容；拍照导入需处理无相机与权限。
public enum KCImageImportSource: String, Equatable, Sendable {
    case photoLibrary
    case camera
}

/// 图片导入的失败类型（统一结果模型，供 App 层映射为本地化反馈，不直接暴露系统错误）。
public enum KCImageImportFailure: String, Equatable, Sendable {
    case cancelled
    case photoLibraryDenied
    case cameraDenied
    case noCamera
    case failed
}

/// 某来源当前的授权状态（App 层把系统权限 API 映射为此枚举）。
public enum KCImageImportAuthorization: String, Equatable, Sendable {
    case authorized
    case notDetermined
    case denied
}

/// 导入协调的下一步动作（纯决策，App 层据此决定出示 picker / 请求权限 / 提示）。
public enum KCImageImportAction: Equatable, Sendable {
    /// 已授权，直接出示系统 picker。
    case present
    /// 权限未决定，需先请求系统授权。
    case requestAuthorization
    /// 权限被拒绝，按来源给出对应失败反馈。
    case showDeniedFailure(KCImageImportFailure)
    /// 无相机（模拟器或无相机设备），降级提示并保留相册路径。
    case showNoCamera
}

/// 图片导入纯决策工具：把“来源 + 是否可用 + 授权状态”映射为下一步动作。
/// App 层负责把 `UIImagePickerController.isSourceTypeAvailable` 与相册/相机权限
/// API 的结果归一为入参；本工具不依赖 UIKit，可在 KCDomain 单测。
public enum KCImageImportDecision {

    /// 根据来源、可用性与授权状态推导下一步动作。
    public static func resolve(
        source: KCImageImportSource,
        isAvailable: Bool,
        authorization: KCImageImportAuthorization
    ) -> KCImageImportAction {
        if !isAvailable {
            // 相机不可用（模拟器/无相机设备）走降级；相册不可用属异常失败。
            return source == .camera ? .showNoCamera : .showDeniedFailure(.failed)
        }
        switch authorization {
        case .authorized:
            return .present
        case .notDetermined:
            return .requestAuthorization
        case .denied:
            return .showDeniedFailure(source == .camera ? .cameraDenied : .photoLibraryDenied)
        }
    }
}
