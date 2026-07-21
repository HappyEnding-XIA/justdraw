//
//  KCMainViewController+ImagePicking.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/08.
//

import UIKit
import Photos
import PhotosUI
import KCDomain

// MARK: - 图片导入（相册 / 拍照，T100；生成线稿，T101）

/// 图片导入意图：作为画布底图（既有），或离线生成线稿（T101）。
enum KCImageImportIntent {
    case asCanvas
    case generateLineArt
}

extension KCMainViewController {
    @objc func didTapImportImage() {
        self.presentImportActionSheet()
    }

    // MARK: - T101 从照片生成线稿

    /// “从照片生成线稿”入口：选相册图片（不覆盖当前画布）→ 离线提取 → 结果确认。
    func didTapGenerateLineArtFromPhoto() {
        self.pendingImageImportIntent = .generateLineArt
        self.setContentLibraryPanelVisible(false)
        // 直接走相册导入；草稿保护在 confirmImport 内处理。
        self.performCanvasReplacementAfterUserConfirmation { [weak self] in
            self?.beginImport(from: .photoLibrary)
        }
    }

    func prepareImageImportGeneration() -> Int {
        self.invalidateArtworkLoadWork()
        let generation = self.imageImportGeneration + 1
        self.imageImportGeneration = generation
        return generation
    }

    func processImportedImage(_ image: UIImage?, generation: Int) {
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
                if self.pendingImageImportIntent == .generateLineArt {
                    self.generateLineArt(from: normalizedImage)
                } else {
                    self.finishImportingImage(normalizedImage)
                }
            }
        }
    }

    /// 用导入的图片离线生成线稿，并弹结果确认（使用这张线稿 / 重新生成 / 取消）。
    func generateLineArt(from image: UIImage) {
        self.pendingImageImportIntent = .asCanvas
        let extractor = self.lineArtExtractor
        let imageData = image.pngData() ?? Data()
        self.imageImportProcessingQueue.async { [weak self] in
            let result = extractor.extract(from: imageData)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.presentLineArtExtractionResult(result, sourceImage: image)
            }
        }
    }

    /// 结果确认：使用这张线稿（保存到我的线稿并打开）/ 重新生成（重选）/ 取消。
    private func presentLineArtExtractionResult(_ result: KCLineArtExtractionResult?, sourceImage: UIImage) {
        _ = sourceImage
        guard let result else {
            self.showCustomLineArtToast(title: KCL10n.lineArtExtractionFailedTitle,
                                        symbol: "exclamationmark.triangle.fill",
                                        tint: .systemOrange)
            return
        }
        let message: String
        switch result.quality {
        case .good: message = KCL10n.lineArtExtractionGoodMessage
        case .marginal: message = KCL10n.lineArtExtractionMarginalMessage
        case .poor: message = KCL10n.lineArtExtractionPoorMessage
        }
        let previewImage = UIImage(data: result.thumbnailJPEG) ?? UIImage(data: result.lineArtPNG)
        let card = KCLineArtExtractionResultCard()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.configure(title: KCL10n.lineArtExtractionConfirmTitle,
                       message: message,
                       previewImage: previewImage,
                       canUseResult: result.quality.isUsable)
        card.onUse = { [weak self, weak card] in
            card?.dismiss {
                self?.useGeneratedLineArt(result)
            }
        }
        card.onRetry = { [weak self, weak card] in
            card?.dismiss {
                self?.didTapGenerateLineArtFromPhoto()
            }
        }
        card.onCancel = { [weak card] in
            card?.dismiss(completion: nil)
        }
        self.view.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: self.view.topAnchor),
            card.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        self.view.bringSubviewToFront(card)
        card.present()
    }

    /// 确认使用：保存到我的线稿（sourceKind=.photoExtraction）并打开。
    private func useGeneratedLineArt(_ result: KCLineArtExtractionResult) {
        let activeId = (self.activeSession as KCSessionMetadata?)?.identifier
        self.customLineArtService.saveExtraction(result, sourceSessionId: activeId) { [weak self] saved in
            guard let self else { return }
            self.refreshCustomLineArt()
            guard saved != nil, let uiImage = UIImage(data: result.lineArtPNG) else {
                self.showSaveToastWithSuccess(false)
                return
            }
            // 打开到画布（替换当前画布前已由用户在导入入口确认过草稿保护）。
            self.canvasView.loadLineArtImage(uiImage)
            self.activeSession = nil
            self.selectedHistorySession = nil
            self.activeSessionHasUnsavedChanges = false
            self.selectToolMode(.fill)
            self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
            self.refreshActionButtons()
            self.showCustomLineArtToast(title: KCL10n.saveAsLineArtSuccessTitle,
                                        symbol: "checkmark.circle.fill",
                                        tint: .systemGreen)
        }
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

    func configuredPhotoLibraryPicker() -> PHPickerViewController {
        let picker = PHPickerViewController(configuration: self.configuredPhotoLibraryPickerConfiguration())
        picker.delegate = self
        return picker
    }

    func configuredPhotoLibraryPickerConfiguration() -> PHPickerConfiguration {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        return configuration
    }

    @discardableResult
    func presentPhotoLibraryPicker(animated: Bool, completion: ((PHPickerViewController) -> Void)?) -> Bool {
        let startedAt = Date()
        self.showCustomLineArtToast(title: KCL10n.importOpeningPhotoLibraryTitle,
                                    symbol: "photo.on.rectangle.angled",
                                    tint: .systemBlue)
        let picker = self.configuredPhotoLibraryPicker()
        self.present(picker, animated: animated) {
#if DEBUG
            let elapsed = Date().timeIntervalSince(startedAt)
            print("[KidCanvas] Photo library picker presented in \(String(format: "%.3f", elapsed))s")
#endif
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
        let generation = self.prepareImageImportGeneration()
        picker.dismiss(animated: true, completion: nil)
        self.processImportedImage(image, generation: generation)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.invalidateArtworkLoadWork()
        self.invalidateImageImportWork()
        picker.dismiss(animated: true, completion: nil)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let generation = self.prepareImageImportGeneration()
        guard let result = results.first else {
            self.invalidateImageImportWork()
            picker.dismiss(animated: true, completion: nil)
            return
        }
        let provider = result.itemProvider
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            picker.dismiss(animated: true, completion: nil)
            self.processImportedImage(nil, generation: generation)
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                guard self.imageImportGeneration == generation else { return }
                picker.dismiss(animated: true) {
                    self.processImportedImage(object as? UIImage, generation: generation)
                }
            }
        }
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

// MARK: - 线稿生成结果确认卡片

/// T103：自有浅色确认卡片，替代 iPad 上表现不稳定的系统 alert。
private final class KCLineArtExtractionResultCard: UIView {
    var onUse: (() -> Void)?
    var onRetry: (() -> Void)?
    var onCancel: (() -> Void)?

    private let backdropView = UIView()
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let previewImageView = UIImageView()
    private let useButton = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildInterface()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildInterface()
    }

    func configure(title: String, message: String, previewImage: UIImage?, canUseResult: Bool) {
        titleLabel.text = title
        messageLabel.text = message
        previewImageView.image = previewImage
        useButton.isHidden = !canUseResult
    }

    func present() {
        alpha = 0.0
        cardView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.18, delay: 0.0, options: [.curveEaseOut]) {
            self.alpha = 1.0
            self.cardView.transform = .identity
        }
    }

    func dismiss(completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.15, delay: 0.0, options: [.curveEaseIn], animations: {
            self.alpha = 0.0
            self.cardView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }

    private func buildInterface() {
        backgroundColor = .clear
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.backgroundColor = UIColor(white: 0.0, alpha: 0.24)
        addSubview(backdropView)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCancel))
        backdropView.addGestureRecognizer(tap)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .clear
        cardView.layer.cornerRadius = 24.0
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = KCEditorVisualStyle.glassShadowColor
        cardView.layer.shadowOpacity = 0.14
        cardView.layer.shadowRadius = 18.0
        cardView.layer.shadowOffset = CGSize(width: 0.0, height: 8.0)
        addSubview(cardView)

        // T109 G2：线稿提取结果卡由"假玻璃"（实色 0.98）改为统一玻璃入口：
        // `cardView` 承载阴影与圆角，玻璃由 `cardGlass`（系统液态玻璃 / 降级模糊 + 暖底 + 白高光描边，强染色保弹层对比度）铺底。
        let cardGlass = KCEditorVisualStyle.makeGlassEffectView(contentTint: KCEditorVisualStyle.glassContentTintStrong)
        KCEditorVisualStyle.applyGlassSurface(to: cardGlass, cornerRadius: 24.0)
        cardGlass.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(cardGlass)
        cardView.sendSubviewToBack(cardGlass)
        NSLayoutConstraint.activate([
            cardGlass.topAnchor.constraint(equalTo: cardView.topAnchor),
            cardGlass.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            cardGlass.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            cardGlass.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        ])

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 20.0, weight: .bold)
        titleLabel.textColor = KCEditorVisualStyle.inkColor
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 15.0, weight: .medium)
        messageLabel.textColor = KCEditorVisualStyle.mutedInkColor
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.backgroundColor = UIColor(red: 1.0, green: 0.995, blue: 0.98, alpha: 1.0)
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.layer.cornerRadius = 18.0
        previewImageView.layer.cornerCurve = .continuous
        previewImageView.layer.borderColor = KCEditorVisualStyle.subtleBorderColor
        previewImageView.layer.borderWidth = 1.0
        previewImageView.clipsToBounds = true

        useButton.setTitle(KCL10n.lineArtExtractionUseTitle, for: .normal)
        retryButton.setTitle(KCL10n.lineArtExtractionRetryTitle, for: .normal)
        cancelButton.setTitle(KCL10n.cancelTitle, for: .normal)
        for button in [useButton, retryButton, cancelButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.titleLabel?.font = .systemFont(ofSize: 15.0, weight: .bold)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.78
            button.layer.cornerRadius = 17.0
            button.layer.cornerCurve = .continuous
        }
        useButton.backgroundColor = KCEditorVisualStyle.accentColor
        useButton.setTitleColor(KCEditorVisualStyle.accentInkColor, for: .normal)
        retryButton.backgroundColor = KCEditorVisualStyle.compactBackgroundColor
        retryButton.setTitleColor(KCEditorVisualStyle.inkColor, for: .normal)
        cancelButton.backgroundColor = UIColor.clear
        cancelButton.setTitleColor(KCEditorVisualStyle.mutedInkColor, for: .normal)

        useButton.addTarget(self, action: #selector(handleUse), for: .touchUpInside)
        retryButton.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [useButton, retryButton, cancelButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.alignment = .fill
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 10.0

        for view in [titleLabel, previewImageView, messageLabel, buttonStack] {
            cardView.addSubview(view)
        }

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            cardView.heightAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.heightAnchor, multiplier: 0.82),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 22.0),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 22.0),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -22.0),

            previewImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16.0),
            previewImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24.0),
            previewImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24.0),
            previewImageView.heightAnchor.constraint(equalTo: cardView.heightAnchor, multiplier: 0.38),

            messageLabel.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 14.0),
            messageLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24.0),
            messageLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24.0),

            buttonStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 18.0),
            buttonStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 22.0),
            buttonStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -22.0),
            buttonStack.heightAnchor.constraint(equalToConstant: 42.0),
            buttonStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -22.0)
        ])
        let widthConstraint = cardView.widthAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor, multiplier: 0.62)
        widthConstraint.priority = .defaultHigh
        let maxWidthConstraint = cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 520.0)
        NSLayoutConstraint.activate([widthConstraint, maxWidthConstraint])
    }

    @objc private func handleUse() {
        onUse?()
    }

    @objc private func handleRetry() {
        onRetry?()
    }

    @objc private func handleCancel() {
        onCancel?()
    }
}
