//
//  KCImageImportService.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/09.
//

import UIKit
import AVFoundation
import KCDomain

/// 图片导入策略服务（T100）。把系统 picker 可用性与相册/相机权限 API 归一为
/// KCDomain 决策（`KCImageImportDecision`），让 `KCMainViewController` 不再直接堆
/// 系统权限细节，统一处理“出示 / 请求权限 / 权限拒绝 / 无相机降级”。
protocol KCImageImportServicing: AnyObject {
    /// 该来源在当前设备是否可用（相机在模拟器上为 false）。
    func isSourceAvailable(_ source: KCImageImportSource) -> Bool
    /// 该来源当前的授权状态。
    func authorizationStatus(for source: KCImageImportSource) -> KCImageImportAuthorization
    /// 请求该来源授权（未决定时调用），主线程回调。
    func requestAuthorization(for source: KCImageImportSource, completion: @escaping (KCImageImportAuthorization) -> Void)
    /// 综合可用性与授权，给出下一步动作。
    func decideAction(for source: KCImageImportSource) -> KCImageImportAction
}

final class KCImageImportService: KCImageImportServicing {

    func isSourceAvailable(_ source: KCImageImportSource) -> Bool {
        switch source {
        case .photoLibrary:
            return UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
        case .camera:
            return UIImagePickerController.isSourceTypeAvailable(.camera)
        }
    }

    func authorizationStatus(for source: KCImageImportSource) -> KCImageImportAuthorization {
        switch source {
        case .photoLibrary:
            return .authorized
        case .camera:
            return Self.mapCameraStatus(AVCaptureDevice.authorizationStatus(for: .video))
        }
    }

    func requestAuthorization(for source: KCImageImportSource, completion: @escaping (KCImageImportAuthorization) -> Void) {
        switch source {
        case .photoLibrary:
            DispatchQueue.main.async { completion(.authorized) }
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted ? .authorized : .denied) }
            }
        }
    }

    func decideAction(for source: KCImageImportSource) -> KCImageImportAction {
        KCImageImportDecision.resolve(
            source: source,
            isAvailable: isSourceAvailable(source),
            authorization: authorizationStatus(for: source)
        )
    }

    private static func mapCameraStatus(_ status: AVAuthorizationStatus) -> KCImageImportAuthorization {
        switch status {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }
}
