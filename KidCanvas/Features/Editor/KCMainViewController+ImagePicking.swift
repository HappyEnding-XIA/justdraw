//
//  KCMainViewController+ImagePicking.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/08.
//

import UIKit
import KCDomain

// MARK: - 图片导入（相册 / 拍照，T100）

extension KCMainViewController {
    @objc func didTapImportImage() {
        self.presentImportActionSheet()
    }

    /// 导入动作表：从相册导入 / 拍照导入 / 取消。顶栏与内容库入口共用此入口。
    private func presentImportActionSheet() {
        let sheet = UIAlertController(title: KCL10n.importActionSheetTitle, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: KCL10n.importFromPhotoLibraryTitle, style: .default) { [weak self] _ in
            self?.confirmImport(from: .photoLibrary)
        })
        sheet.addAction(UIAlertAction(title: KCL10n.importFromCameraTitle, style: .default) { [weak self] _ in
            self?.confirmImport(from: .camera)
        })
        sheet.addAction(UIAlertAction(title: KCL10n.cancelTitle, style: .cancel))
        // iPad/横屏 popover 锚定到导入按钮。
        let anchor = self.importAnchorView()
        sheet.popoverPresentationController?.sourceView = anchor
        sheet.popoverPresentationController?.sourceRect = anchor.bounds
        self.present(sheet, animated: true)
    }

    /// popover 锚点视图（非可选，优先导入按钮，兜底 view）。
    private func importAnchorView() -> UIView {
        if let button = self.importButton { return button }
        if let button = self.contentLibraryButton { return button }
        if let button = self.saveButton { return button }
        return self.view
    }

    /// 选定来源后，先按需确认替换当前画布（草稿保护），再进入权限/降级决策。
    func confirmImport(from source: KCImageImportSource) {
        self.performCanvasReplacementAfterUserConfirmation { [weak self] in
            self?.beginImport(from: source)
        }
    }

    /// 根据导入策略服务的决策出示 picker / 请求权限 / 给出降级或失败反馈。
    func beginImport(from source: KCImageImportSource) {
        switch self.imageImportService.decideAction(for: source) {
        case .present:
            self.presentImagePicker(for: source)
        case .requestAuthorization:
            self.imageImportService.requestAuthorization(for: source) { [weak self] authorization in
                guard let self else { return }
                if authorization == .authorized {
                    self.presentImagePicker(for: source)
                } else {
                    self.showImageImportFailure(source == .camera ? .cameraDenied : .photoLibraryDenied)
                }
            }
        case .showDeniedFailure(let failure):
            self.showImageImportFailure(failure)
        case .showNoCamera:
            self.showImageImportFailure(.noCamera)
        }
    }

    /// 出示对应来源的系统 picker。相册沿用既有路径；相机新增。
    @discardableResult
    func presentImagePicker(for source: KCImageImportSource) -> Bool {
        switch source {
        case .photoLibrary:
            return self.presentPhotoLibraryPicker(animated: true, completion: nil)
        case .camera:
            return self.presentCameraPicker(animated: true)
        }
    }

    func configuredPhotoLibraryPicker() -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        let popover = picker.popoverPresentationController
        popover?.sourceView = self.view
        popover?.sourceRect = CGRect(x: self.view.bounds.maxX - 110.0, y: 88.0, width: 1.0, height: 1.0)
        popover?.permittedArrowDirections = .up
        return picker
    }

    @discardableResult
    func presentPhotoLibraryPicker(animated: Bool, completion: ((UIImagePickerController) -> Void)?) -> Bool {
        if !UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            return false
        }

        let picker = self.configuredPhotoLibraryPicker()
        self.present(picker, animated: animated) {
            completion?(picker)
        }
        return true
    }

    /// 出示相机 picker（模拟器/无相机设备返回 false，由调用方走降级提示）。
    @discardableResult
    func presentCameraPicker(animated: Bool) -> Bool {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return false }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = self
        let popover = picker.popoverPresentationController
        let anchor = self.importAnchorView()
        popover?.sourceView = anchor
        popover?.sourceRect = anchor.bounds
        self.present(picker, animated: animated)
        return true
    }

    /// 导入失败/降级的本地化反馈（用户取消不提示）。
    func showImageImportFailure(_ failure: KCImageImportFailure) {
        let title: String
        let symbol: String
        let tint: UIColor
        switch failure {
        case .cancelled:
            return
        case .noCamera:
            title = KCL10n.importNoCameraTitle
            symbol = "camera.metering.unknown"
            tint = .systemOrange
        case .cameraDenied:
            title = KCL10n.importCameraDeniedTitle
            symbol = "lock.fill"
            tint = .systemOrange
        case .photoLibraryDenied:
            title = KCL10n.importPhotoLibraryDeniedTitle
            symbol = "lock.fill"
            tint = .systemOrange
        case .failed:
            title = KCL10n.saveFailedToastTitle
            symbol = "exclamationmark.triangle.fill"
            tint = .systemRed
        }
        self.showCustomLineArtToast(title: title, symbol: symbol, tint: tint)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.originalImage] as? UIImage
        self.invalidateArtworkLoadWork()
        let generation = self.imageImportGeneration + 1
        self.imageImportGeneration = generation
        picker.dismiss(animated: true, completion: nil)

        self.imageImportProcessingQueue.async { [weak self, image] in
            guard let self else { return }
            let normalizedImage = self.normalizedImageFromImage(image)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.imageImportGeneration == generation else { return }
                guard let normalizedImage else {
                    self.showSaveToastWithSuccess(false)
#if DEBUG
                    let runtimeCompletion = self.runtimeAcceptanceImageImportCompletion
                    self.runtimeAcceptanceImageImportCompletion = nil
                    runtimeCompletion?()
#endif
                    return
                }
                self.finishImportingImage(normalizedImage)
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.invalidateArtworkLoadWork()
        self.invalidateImageImportWork()
        picker.dismiss(animated: true, completion: nil)
    }

    private func finishImportingImage(_ normalizedImage: UIImage) {
        let preservedDraft = self.preserveUnsavedActiveSessionDraftIfNeeded()
        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.invalidateDraftSaveTimer()
        if !preservedDraft {
            self.clearDraftAndInvalidateCurrentDraftMarker()
        }
        self.canvasView.replaceCanvas(with: normalizedImage)
        self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
        self.refreshActionButtons()
#if DEBUG
        let runtimeCompletion = self.runtimeAcceptanceImageImportCompletion
        self.runtimeAcceptanceImageImportCompletion = nil
        runtimeCompletion?()
#endif
    }

    func normalizedImageFromImage(_ image: UIImage?) -> UIImage? {
        guard let image = image, image.size.width > 0.0, image.size.height > 0.0 else {
            return nil
        }

        let maxDimension: CGFloat = 2400.0
        let imageSize = image.size
        let scale = min(1.0, maxDimension / max(imageSize.width, imageSize.height))
        let needsResize = scale < 1.0

        if image.imageOrientation == .up && !needsResize {
            return image
        }

        let targetSize = needsResize ? CGSize(width: imageSize.width * scale, height: imageSize.height * scale) : imageSize
        if targetSize.width <= 0.0 || targetSize.height <= 0.0 {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { (_: UIGraphicsImageRendererContext) in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
