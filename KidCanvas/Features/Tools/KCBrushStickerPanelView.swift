//
//  KCBrushStickerPanelView.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit
import QuartzCore

/// 画笔、贴纸、橡皮与贴纸编辑面板的 UIKit 组装器。
/// 只负责视图创建、约束和按钮外观，不持有画布状态。
final class KCBrushStickerPanelView {
    private static let categorySymbolImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 32
        return cache
    }()

    struct Texts {
        let brushStickerTitle: String
        let sizeSliderAccessibility: String
        let stickersTitle: String
        let eraserTitle: String
        let stickerEditTitle: String
        let circleEraserTitle: String
        let cloudEraserTitle: String
        let starEraserTitle: String
        let bringStickerForwardTitle: String
        let deleteStickerTitle: String
    }

    struct RenderedPanel {
        let sizeSlider: UISlider
        let sizePreviewView: UIView
        let sizePreviewShapeLayer: CAShapeLayer
        let stickerCategoryButtons: [UIButton]
        let stickerRowStack: UIStackView
        let circleEraserButton: UIButton
        let cloudEraserButton: UIButton
        let starEraserButton: UIButton
        let frontStickerButton: UIButton
        let deleteStickerButton: UIButton
    }

    func renderPanel(
        in panel: UIView,
        texts: Texts,
        stickerCategories: [String],
        target: Any?,
        makeTitleLabel: (String) -> UILabel,
        makeSmallToolButton: (String, Bool) -> UIButton,
        categorySymbolProvider: (String) -> String,
        imageProvider: (String) -> UIImage,
        stickerCategoryAccessibilityProvider: (String) -> String,
        registerPressFeedback: (UIControl) -> Void,
        sizeSliderAction: Selector,
        stickerCategoryAction: Selector,
        circleEraserAction: Selector,
        cloudEraserAction: Selector,
        starEraserAction: Selector,
        bringStickerForwardAction: Selector,
        deleteStickerAction: Selector
    ) -> RenderedPanel {
        let titleLabel = makeTitleLabel(texts.brushStickerTitle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)

        let shell = UIView()
        shell.translatesAutoresizingMaskIntoConstraints = false
        shell.backgroundColor = UIColor(white: 1.0, alpha: 0.58)
        shell.layer.cornerRadius = 24.0
        shell.layer.cornerCurve = .continuous
        shell.layer.borderWidth = 1.0
        shell.layer.borderColor = UIColor(white: 1.0, alpha: 0.54).cgColor
        panel.addSubview(shell)

        let sizeSlider = UISlider()
        sizeSlider.translatesAutoresizingMaskIntoConstraints = false
        sizeSlider.minimumValue = 4.0
        sizeSlider.maximumValue = 36.0
        sizeSlider.value = 12.0
        sizeSlider.minimumTrackTintColor = UIColor(red: 0.93, green: 0.83, blue: 0.46, alpha: 1.0)
        sizeSlider.maximumTrackTintColor = UIColor(red: 0.91, green: 0.66, blue: 0.45, alpha: 0.42)
        sizeSlider.accessibilityLabel = texts.sizeSliderAccessibility
        sizeSlider.accessibilityIdentifier = "size.slider"
        sizeSlider.addTarget(target, action: sizeSliderAction, for: .valueChanged)
        shell.addSubview(sizeSlider)

        let sizePreviewView = UIView()
        sizePreviewView.translatesAutoresizingMaskIntoConstraints = false
        sizePreviewView.backgroundColor = UIColor(white: 1.0, alpha: 0.72)
        sizePreviewView.layer.cornerRadius = 24.0
        sizePreviewView.layer.cornerCurve = .continuous
        sizePreviewView.layer.borderWidth = 1.0
        sizePreviewView.layer.borderColor = UIColor(white: 1.0, alpha: 0.74).cgColor
        shell.addSubview(sizePreviewView)

        let sizePreviewShapeLayer = CAShapeLayer()
        sizePreviewShapeLayer.lineCap = .round
        sizePreviewShapeLayer.lineJoin = .round
        sizePreviewView.layer.addSublayer(sizePreviewShapeLayer)

        let dots = UIStackView()
        dots.translatesAutoresizingMaskIntoConstraints = false
        dots.axis = .horizontal
        dots.distribution = .equalSpacing
        dots.alignment = .bottom
        shell.addSubview(dots)

        for size in [8.0, 14.0, 20.0, 28.0] as [CGFloat] {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = UIColor(red: 0.91, green: 0.64, blue: 0.42, alpha: 1.0)
            dot.layer.cornerRadius = size / 2.0
            dot.widthAnchor.constraint(equalToConstant: size).isActive = true
            dot.heightAnchor.constraint(equalToConstant: size).isActive = true
            dots.addArrangedSubview(dot)
        }

        let stickerTitle = makeTitleLabel(texts.stickersTitle)
        stickerTitle.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stickerTitle)

        let stickerCategoryRow = UIStackView()
        stickerCategoryRow.translatesAutoresizingMaskIntoConstraints = false
        stickerCategoryRow.axis = .horizontal
        stickerCategoryRow.spacing = 8.0
        stickerCategoryRow.distribution = .fillEqually
        panel.addSubview(stickerCategoryRow)

        var stickerCategoryButtons: [UIButton] = []
        for category in stickerCategories {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            let symbolName = categorySymbolProvider(category)
            let categoryImage = cachedCategorySymbolImage(symbolName: symbolName) {
                imageProvider("star.fill")
            }
            button.setImage(categoryImage, for: .normal)
            button.accessibilityLabel = stickerCategoryAccessibilityProvider(category)
            button.accessibilityIdentifier = "sticker.category.\(category.lowercased())"
            applyPillSelectionAppearance(to: button, active: false)
            button.addTarget(target, action: stickerCategoryAction, for: .touchUpInside)
            registerPressFeedback(button)
            stickerCategoryRow.addArrangedSubview(button)
            stickerCategoryButtons.append(button)
        }

        let stickerScrollView = UIScrollView()
        stickerScrollView.translatesAutoresizingMaskIntoConstraints = false
        stickerScrollView.showsHorizontalScrollIndicator = false
        stickerScrollView.alwaysBounceHorizontal = true
        stickerScrollView.clipsToBounds = true
        panel.addSubview(stickerScrollView)

        let stickerRow = UIStackView()
        stickerRow.translatesAutoresizingMaskIntoConstraints = false
        stickerRow.axis = .horizontal
        stickerRow.spacing = 10.0
        stickerRow.distribution = .fill
        stickerScrollView.addSubview(stickerRow)

        let eraserTitle = makeTitleLabel(texts.eraserTitle)
        eraserTitle.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(eraserTitle)

        let eraserRow = UIStackView()
        eraserRow.translatesAutoresizingMaskIntoConstraints = false
        eraserRow.axis = .horizontal
        eraserRow.spacing = 10.0
        eraserRow.distribution = .fillEqually
        panel.addSubview(eraserRow)

        let circleEraserButton = makeSmallToolButton("circle.fill", false)
        let cloudEraserButton = makeSmallToolButton("cloud.fill", false)
        let starEraserButton = makeSmallToolButton("star.fill", false)
        circleEraserButton.accessibilityLabel = texts.circleEraserTitle
        circleEraserButton.accessibilityIdentifier = "eraser.circle"
        cloudEraserButton.accessibilityLabel = texts.cloudEraserTitle
        cloudEraserButton.accessibilityIdentifier = "eraser.cloud"
        starEraserButton.accessibilityLabel = texts.starEraserTitle
        starEraserButton.accessibilityIdentifier = "eraser.star"
        circleEraserButton.addTarget(target, action: circleEraserAction, for: .touchUpInside)
        cloudEraserButton.addTarget(target, action: cloudEraserAction, for: .touchUpInside)
        starEraserButton.addTarget(target, action: starEraserAction, for: .touchUpInside)
        eraserRow.addArrangedSubview(circleEraserButton)
        eraserRow.addArrangedSubview(cloudEraserButton)
        eraserRow.addArrangedSubview(starEraserButton)

        let editTitle = makeTitleLabel(texts.stickerEditTitle)
        editTitle.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(editTitle)

        let editRow = UIStackView()
        editRow.translatesAutoresizingMaskIntoConstraints = false
        editRow.axis = .horizontal
        editRow.spacing = 10.0
        editRow.distribution = .fillEqually
        panel.addSubview(editRow)

        let frontStickerButton = makeSmallToolButton("square.2.layers.3d.top.filled", false)
        let deleteStickerButton = makeSmallToolButton("trash.fill", false)
        frontStickerButton.accessibilityLabel = texts.bringStickerForwardTitle
        frontStickerButton.accessibilityIdentifier = "sticker.bring-forward"
        deleteStickerButton.accessibilityLabel = texts.deleteStickerTitle
        deleteStickerButton.accessibilityIdentifier = "sticker.delete"
        frontStickerButton.addTarget(target, action: bringStickerForwardAction, for: .touchUpInside)
        deleteStickerButton.addTarget(target, action: deleteStickerAction, for: .touchUpInside)
        editRow.addArrangedSubview(frontStickerButton)
        editRow.addArrangedSubview(deleteStickerButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18.0),

            shell.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            shell.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            shell.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12.0),

            sizeSlider.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14.0),
            sizeSlider.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -14.0),
            sizeSlider.topAnchor.constraint(equalTo: shell.topAnchor, constant: 18.0),

            sizePreviewView.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 16.0),
            sizePreviewView.topAnchor.constraint(equalTo: sizeSlider.bottomAnchor, constant: 14.0),
            sizePreviewView.widthAnchor.constraint(equalToConstant: 50.0),
            sizePreviewView.heightAnchor.constraint(equalToConstant: 50.0),

            dots.leadingAnchor.constraint(equalTo: sizePreviewView.trailingAnchor, constant: 18.0),
            dots.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -22.0),
            dots.topAnchor.constraint(equalTo: sizeSlider.bottomAnchor, constant: 16.0),
            dots.bottomAnchor.constraint(equalTo: shell.bottomAnchor, constant: -14.0),

            stickerTitle.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            stickerTitle.topAnchor.constraint(equalTo: shell.bottomAnchor, constant: 14.0),

            stickerCategoryRow.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            stickerCategoryRow.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            stickerCategoryRow.topAnchor.constraint(equalTo: stickerTitle.bottomAnchor, constant: 9.0),
            stickerCategoryRow.heightAnchor.constraint(equalToConstant: 32.0),

            stickerScrollView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            stickerScrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            stickerScrollView.topAnchor.constraint(equalTo: stickerCategoryRow.bottomAnchor, constant: 10.0),
            stickerScrollView.heightAnchor.constraint(equalToConstant: 48.0),

            stickerRow.leadingAnchor.constraint(equalTo: stickerScrollView.contentLayoutGuide.leadingAnchor),
            stickerRow.trailingAnchor.constraint(equalTo: stickerScrollView.contentLayoutGuide.trailingAnchor),
            stickerRow.topAnchor.constraint(equalTo: stickerScrollView.contentLayoutGuide.topAnchor),
            stickerRow.bottomAnchor.constraint(equalTo: stickerScrollView.contentLayoutGuide.bottomAnchor),
            stickerRow.heightAnchor.constraint(equalTo: stickerScrollView.frameLayoutGuide.heightAnchor),

            eraserTitle.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            eraserTitle.topAnchor.constraint(equalTo: stickerScrollView.bottomAnchor, constant: 14.0),

            eraserRow.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            eraserRow.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            eraserRow.topAnchor.constraint(equalTo: eraserTitle.bottomAnchor, constant: 10.0),

            editTitle.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            editTitle.topAnchor.constraint(equalTo: eraserRow.bottomAnchor, constant: 14.0),

            editRow.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            editRow.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            editRow.topAnchor.constraint(equalTo: editTitle.bottomAnchor, constant: 10.0),
            editRow.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -18.0)
        ])

        return RenderedPanel(
            sizeSlider: sizeSlider,
            sizePreviewView: sizePreviewView,
            sizePreviewShapeLayer: sizePreviewShapeLayer,
            stickerCategoryButtons: stickerCategoryButtons,
            stickerRowStack: stickerRow,
            circleEraserButton: circleEraserButton,
            cloudEraserButton: cloudEraserButton,
            starEraserButton: starEraserButton,
            frontStickerButton: frontStickerButton,
            deleteStickerButton: deleteStickerButton
        )
    }

    func reloadStickerButtons(
        in stickerRowStack: UIStackView,
        symbols: [String],
        target: Any?,
        action: Selector,
        imageProvider: (String) -> UIImage,
        accessibilityLabelProvider: (String) -> String,
        registerPressFeedback: (UIControl) -> Void
    ) -> [UIButton] {
        for view in stickerRowStack.arrangedSubviews {
            stickerRowStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        var buttons: [UIButton] = []
        buttons.reserveCapacity(symbols.count)

        for symbol in symbols {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setImage(imageProvider(symbol), for: .normal)
            applyStampButtonAppearance(to: button, active: false, enabled: true)
            button.widthAnchor.constraint(equalToConstant: 44.0).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44.0).isActive = true
            button.accessibilityIdentifier = symbol
            button.accessibilityLabel = accessibilityLabelProvider(symbol)
            button.addTarget(target, action: action, for: .touchUpInside)
            registerPressFeedback(button)
            stickerRowStack.addArrangedSubview(button)
            buttons.append(button)
        }

        return buttons
    }

    func applyStickerCategorySelection(
        to buttons: [UIButton],
        selectedCategory: String,
        categoryResolver: (UIButton) -> String?
    ) {
        for button in buttons {
            let category = categoryResolver(button)
            let active = category == selectedCategory
            applyPillSelectionAppearance(to: button, active: active)
        }
    }

    func applyStickerSymbolSelection(to buttons: [UIButton], selectedSymbol: String?) {
        for button in buttons {
            let active = button.accessibilityIdentifier == selectedSymbol
            applyStampButtonAppearance(to: button, active: active, enabled: true)
        }
    }

    func applyStickerEditButtonsEnabled(frontButton: UIButton, deleteButton: UIButton, enabled: Bool) {
        frontButton.isEnabled = enabled
        deleteButton.isEnabled = enabled
        frontButton.alpha = enabled ? 1.0 : 0.55
        deleteButton.alpha = enabled ? 1.0 : 0.55
        applyStampButtonAppearance(to: frontButton, active: false, enabled: enabled)
        applyStampButtonAppearance(to: deleteButton, active: false, enabled: enabled)
    }

    private func cachedCategorySymbolImage(symbolName: String, fallbackImageProvider: () -> UIImage) -> UIImage {
        let key = "\(symbolName)|15|bold" as NSString
        if let cachedImage = Self.categorySymbolImageCache.object(forKey: key) {
            return cachedImage
        }

        let configuration = UIImage.SymbolConfiguration(pointSize: 15.0, weight: .bold)
        let image = UIImage(systemName: symbolName, withConfiguration: configuration) ?? fallbackImageProvider()
        Self.categorySymbolImageCache.setObject(image, forKey: key)
        return image
    }

    private func applyPillSelectionAppearance(to button: UIButton, active: Bool) {
        button.layer.cornerRadius = 15.0
        button.layer.cornerCurve = .continuous
        KCEditorVisualStyle.applySelectableButtonAppearance(
            to: button,
            active: active,
            baseBackgroundColor: KCEditorVisualStyle.pillBackgroundColor,
            inactiveTintColor: KCEditorVisualStyle.mutedInkColor,
            activeShadowRadius: 6.0,
            inactiveShadowRadius: 3.0
        )
    }

    private func applyStampButtonAppearance(to button: UIButton, active: Bool, enabled: Bool) {
        button.layer.cornerRadius = 18.0
        button.layer.cornerCurve = .continuous
        if enabled {
            KCEditorVisualStyle.applySelectableButtonAppearance(
                to: button,
                active: active,
                baseBackgroundColor: KCEditorVisualStyle.compactBackgroundColor,
                activeShadowRadius: 6.0,
                inactiveShadowRadius: 4.0
            )
        } else {
            KCEditorVisualStyle.applyActionButtonAvailability(to: button, enabled: false)
        }
    }
}
