//
//  KCMainViewController+ImagePicking.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/08.
//

import UIKit

// MARK: - 相册导入

extension KCMainViewController {
    @objc func didTapImportImage() {
        self.performCanvasReplacementAfterUserConfirmation { [weak self] in
            guard let self else { return }
            if !self.presentPhotoLibraryPicker(animated: true, completion: nil) {
                self.showSaveToastWithSuccess(false)
            }
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
