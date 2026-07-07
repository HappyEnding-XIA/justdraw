//
//  KCPhotoLibraryService.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/08.
//

import UIKit
import KCDomain

/// 系统相册适配器。App 层只通过 `KCPhotoLibraryServicing` 依赖该能力，
/// 避免编辑器控制器直接绑定 Photos 写入 API。
final class KCPhotoLibraryService: NSObject, KCPhotoLibraryServicing, @unchecked Sendable {
    private let exportLock = NSLock()
    private var exportContinuations: [UnsafeMutableRawPointer: CheckedContinuation<Bool, Never>] = [:]

    @discardableResult
    func export(imageData: Data) async -> Bool {
        guard let image = UIImage(data: imageData) else { return false }

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }

                let token = UnsafeMutableRawPointer(Unmanaged.passRetained(NSObject()).toOpaque())
                self.exportLock.lock()
                self.exportContinuations[token] = continuation
                self.exportLock.unlock()
                UIImageWriteToSavedPhotosAlbum(
                    image,
                    self,
                    #selector(KCPhotoLibraryService.image(_:didFinishSavingWithError:contextInfo:)),
                    token
                )
            }
        }
    }

    func importPhoto() async -> KCImportedPhoto? {
        nil
    }

    @objc private func image(
        _ image: UIImage,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        guard let contextInfo else { return }
        Unmanaged<NSObject>.fromOpaque(contextInfo).release()

        let continuation: CheckedContinuation<Bool, Never>?
        self.exportLock.lock()
        continuation = self.exportContinuations.removeValue(forKey: contextInfo)
        self.exportLock.unlock()
        continuation?.resume(returning: error == nil)
    }
}
