//
//  KCEditorUIFactory.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit

/// 编辑器通用视觉 token。只放颜色、圆角、阴影等外观常量，不承载业务含义。
enum KCEditorVisualStyle {
    static let inkColor = UIColor(red: 0.18, green: 0.24, blue: 0.31, alpha: 1.0)
    static let mutedInkColor = UIColor(red: 0.48, green: 0.52, blue: 0.58, alpha: 1.0)
    static let accentColor = UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0)
    static let accentInkColor = UIColor(red: 0.39, green: 0.26, blue: 0.0, alpha: 1.0)
    static let raisedBackgroundColor = UIColor(white: 1.0, alpha: 0.86)
    static let compactBackgroundColor = UIColor(white: 1.0, alpha: 0.80)
    static let pillBackgroundColor = UIColor(white: 1.0, alpha: 0.68)
    static let disabledBackgroundColor = UIColor(white: 1.0, alpha: 0.58)
    static let saveActionColor = UIColor(red: 0.54, green: 0.80, blue: 0.98, alpha: 1.0)
    static let borderColor = UIColor(white: 1.0, alpha: 0.78).cgColor
    static let activeBorderColor = UIColor(white: 1.0, alpha: 0.94).cgColor
    static let subtleBorderColor = UIColor(red: 0.17, green: 0.22, blue: 0.30, alpha: 0.08).cgColor
    static let shadowColor = UIColor(red: 0.37, green: 0.32, blue: 0.24, alpha: 1.0).cgColor
    static let inactiveShadowOpacity: Float = 0.05
    static let activeShadowOpacity: Float = 0.09
    static let disabledAlpha: CGFloat = 0.56

    static func applyFloatingPanelChrome(to panel: UIView, blurView: UIVisualEffectView) {
        panel.backgroundColor = UIColor.clear
        panel.layer.cornerRadius = 26.0
        panel.layer.cornerCurve = .continuous
        panel.layer.shadowColor = shadowColor
        panel.layer.shadowOpacity = 0.10
        panel.layer.shadowRadius = 20.0
        panel.layer.shadowOffset = CGSize(width: 0.0, height: 10.0)

        blurView.layer.cornerRadius = 26.0
        blurView.layer.cornerCurve = .continuous
        blurView.layer.masksToBounds = true
        blurView.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        blurView.layer.borderWidth = 1.0
        blurView.contentView.backgroundColor = UIColor(white: 1.0, alpha: 0.24)
    }

    static func applyRaisedButtonAppearance(
        to view: UIView,
        cornerRadius: CGFloat,
        backgroundColor: UIColor = raisedBackgroundColor,
        shadowOpacity: Float = 0.10,
        shadowRadius: CGFloat = 9.0,
        shadowOffset: CGSize = CGSize(width: 0.0, height: 5.0)
    ) {
        view.backgroundColor = backgroundColor
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1.0
        view.layer.borderColor = borderColor
        view.layer.shadowColor = shadowColor
        view.layer.shadowOpacity = shadowOpacity
        view.layer.shadowRadius = shadowRadius
        view.layer.shadowOffset = shadowOffset
    }

    static func applyCompactButtonAppearance(to button: UIButton, accent: Bool, cornerRadius: CGFloat = 16.0) {
        button.backgroundColor = accent ? accentColor : compactBackgroundColor
        button.tintColor = accent ? accentInkColor : inkColor
        button.layer.cornerRadius = cornerRadius
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 1.0
        button.layer.borderColor = borderColor
    }

    static func applySmallToolButtonAppearance(to button: UIButton, accent: Bool) {
        applyRaisedButtonAppearance(
            to: button,
            cornerRadius: 16.0,
            backgroundColor: accent ? accentColor : compactBackgroundColor,
            shadowOpacity: 0.05,
            shadowRadius: 5.0,
            shadowOffset: CGSize(width: 0.0, height: 2.0)
        )
        button.tintColor = accent ? accentInkColor : inkColor
    }

    static func applySelectableButtonAppearance(
        to button: UIButton,
        active: Bool,
        baseBackgroundColor: UIColor = raisedBackgroundColor,
        selectedBackgroundColor: UIColor = accentColor,
        inactiveTintColor: UIColor = inkColor,
        activeTintColor: UIColor = accentInkColor,
        activeShadowRadius: CGFloat = 8.0,
        inactiveShadowRadius: CGFloat = 5.5
    ) {
        button.backgroundColor = active ? selectedBackgroundColor : baseBackgroundColor
        button.tintColor = active ? activeTintColor : inactiveTintColor
        button.layer.borderWidth = 1.0
        button.layer.borderColor = active ? activeBorderColor : borderColor
        button.layer.cornerCurve = .continuous
        button.layer.shadowColor = shadowColor
        button.layer.shadowOpacity = active ? activeShadowOpacity : inactiveShadowOpacity
        button.layer.shadowRadius = active ? activeShadowRadius : inactiveShadowRadius
        button.layer.shadowOffset = CGSize(width: 0.0, height: active ? 4.0 : 2.0)
        button.transform = .identity
    }

    static func applyActionButtonAvailability(to button: UIButton, enabled: Bool, accentWhenEnabled: UIColor? = nil) {
        button.isEnabled = enabled
        button.alpha = enabled ? 1.0 : disabledAlpha
        button.backgroundColor = enabled ? (accentWhenEnabled ?? compactBackgroundColor) : disabledBackgroundColor
        button.tintColor = enabled ? inkColor : mutedInkColor
        button.layer.borderWidth = 1.0
        button.layer.borderColor = enabled ? borderColor : subtleBorderColor
        button.layer.shadowOpacity = enabled ? inactiveShadowOpacity : 0.0
        button.layer.shadowRadius = enabled ? 5.5 : 0.0
        button.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
    }
}

/// App 层编辑器 UI 工厂：集中通用 UIKit 控件的样式创建。
/// 只负责外观和固定尺寸，不绑定业务事件，不访问画布/会话状态。
struct KCEditorUIFactory {
    let metrics: KCDeviceLayoutMetrics

    func floatingPanel() -> UIView {
        let panel = UIView()

        let effect = UIBlurEffect(style: .systemThinMaterialLight)
        let blurView = UIVisualEffectView(effect: effect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        KCEditorVisualStyle.applyFloatingPanelChrome(to: panel, blurView: blurView)
        panel.addSubview(blurView)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: panel.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
        ])

        return panel
    }

    func iconButton(symbolName: String, accentColor: UIColor?) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        KCEditorVisualStyle.applyRaisedButtonAppearance(
            to: button,
            cornerRadius: 18.0,
            backgroundColor: accentColor ?? KCEditorVisualStyle.raisedBackgroundColor
        )
        button.tintColor = KCEditorVisualStyle.inkColor
        let configuration = UIImage.SymbolConfiguration(pointSize: 20.0, weight: .bold)
        let image = UIImage(systemName: symbolName, withConfiguration: configuration)
        button.setImage(image, for: .normal)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 56.0),
            button.heightAnchor.constraint(equalToConstant: 50.0)
        ])
        return button
    }

    func historyThumbButton() -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.clipsToBounds = true
        KCEditorVisualStyle.applyRaisedButtonAppearance(
            to: button,
            cornerRadius: 20.0,
            backgroundColor: UIColor(red: 1.0, green: 0.995, blue: 0.98, alpha: 1.0),
            shadowOpacity: 0.06,
            shadowRadius: 8.0
        )
        button.layer.borderColor = KCEditorVisualStyle.subtleBorderColor
        button.layer.borderWidth = 2.0
        button.imageView?.contentMode = .scaleAspectFill
        let configuration = UIImage.SymbolConfiguration(pointSize: 24.0, weight: .semibold)
        let placeholder = UIImage(systemName: "photo", withConfiguration: configuration)?
            .withTintColor(UIColor(red: 0.62, green: 0.67, blue: 0.74, alpha: 0.52), renderingMode: .alwaysOriginal)
        button.setImage(placeholder, for: .normal)
        button.imageView?.contentMode = .center
        return button
    }

    func railToolButton(symbolName: String, slim: Bool) -> KDToolButton {
        let button = KDToolButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        KCEditorVisualStyle.applyRaisedButtonAppearance(
            to: button,
            cornerRadius: 20.0,
            backgroundColor: slim ? KCEditorVisualStyle.accentColor : KCEditorVisualStyle.raisedBackgroundColor,
            shadowOpacity: 0.07,
            shadowRadius: 7.0,
            shadowOffset: CGSize(width: 0.0, height: 4.0)
        )
        button.tintColor = slim ? KCEditorVisualStyle.accentInkColor : KCEditorVisualStyle.inkColor
        let configuration = UIImage.SymbolConfiguration(pointSize: 20.0, weight: .bold)
        let image = UIImage(systemName: symbolName, withConfiguration: configuration)
        button.setImage(image, for: .normal)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 56.0),
            button.heightAnchor.constraint(equalToConstant: 56.0)
        ])
        return button
    }

    func panelTitleLabel(_ title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 15.0, weight: .semibold)
        label.textColor = UIColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 1.0)
        return label
    }

    func segmentButton(title: String, active: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: .bold)
        button.setTitleColor(
            active ? KCEditorVisualStyle.accentInkColor : KCEditorVisualStyle.mutedInkColor,
            for: .normal
        )
        KCEditorVisualStyle.applyCompactButtonAppearance(to: button, accent: active, cornerRadius: 16.0)
        button.backgroundColor = active ? KCEditorVisualStyle.accentColor : UIColor.clear
        button.layer.borderWidth = active ? 1.0 : 0.0
        return button
    }

    func historyActionButton(title: String, accent: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: .bold)
        button.setTitleColor(
            accent ? KCEditorVisualStyle.accentInkColor : KCEditorVisualStyle.inkColor,
            for: .normal
        )
        KCEditorVisualStyle.applyRaisedButtonAppearance(
            to: button,
            cornerRadius: 18.0,
            backgroundColor: accent ? KCEditorVisualStyle.accentColor : KCEditorVisualStyle.raisedBackgroundColor,
            shadowOpacity: 0.06,
            shadowRadius: 6.0,
            shadowOffset: CGSize(width: 0.0, height: 3.0)
        )
        return button
    }

    func smallToolButton(symbolName: String, accent: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        KCEditorVisualStyle.applySmallToolButtonAppearance(to: button, accent: accent)
        let configuration = UIImage.SymbolConfiguration(pointSize: 16.0, weight: .bold)
        let image = UIImage(systemName: symbolName, withConfiguration: configuration)
        button.setImage(image, for: .normal)
        button.heightAnchor.constraint(equalToConstant: 36.0).isActive = true
        return button
    }

    func collapseToggleButton(symbolName: String) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        KCEditorVisualStyle.applyRaisedButtonAppearance(
            to: button,
            cornerRadius: 18.0,
            backgroundColor: KCEditorVisualStyle.compactBackgroundColor,
            shadowOpacity: 0.06,
            shadowRadius: 6.0,
            shadowOffset: CGSize(width: 0.0, height: 3.0)
        )
        button.tintColor = KCEditorVisualStyle.inkColor
        let configuration = UIImage.SymbolConfiguration(pointSize: 18.0, weight: .bold)
        button.setImage(UIImage(systemName: symbolName, withConfiguration: configuration), for: .normal)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44.0),
            button.heightAnchor.constraint(equalToConstant: 44.0)
        ])
        return button
    }

    func toolStateChip() -> UIView {
        let chip = UIView()
        chip.translatesAutoresizingMaskIntoConstraints = false
        KCEditorVisualStyle.applyRaisedButtonAppearance(
            to: chip,
            cornerRadius: 18.0,
            backgroundColor: KCEditorVisualStyle.compactBackgroundColor,
            shadowOpacity: 0.05,
            shadowRadius: 5.0,
            shadowOffset: CGSize(width: 0.0, height: 2.0)
        )
        chip.isHidden = true
        chip.alpha = 0.0
        return chip
    }

    func toolStateSwatch() -> UIView {
        let swatch = UIView()
        swatch.translatesAutoresizingMaskIntoConstraints = false
        swatch.layer.cornerRadius = 9.0
        swatch.layer.cornerCurve = .continuous
        swatch.layer.borderWidth = 1.0
        swatch.layer.borderColor = KCEditorVisualStyle.activeBorderColor
        return swatch
    }

    func toolStateLabel() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        label.textColor = KCEditorVisualStyle.inkColor
        return label
    }

    func toolCardButton(symbolName: String, accentColor: UIColor, title: String) -> KDBrushButton {
        let button = KDBrushButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        KCEditorVisualStyle.applyRaisedButtonAppearance(
            to: button,
            cornerRadius: metrics.isCompactPhoneLayout ? 22.0 : 24.0,
            backgroundColor: KCEditorVisualStyle.raisedBackgroundColor,
            shadowOpacity: 0.09,
            shadowRadius: metrics.isCompactPhoneLayout ? 6.0 : 8.0,
            shadowOffset: CGSize(width: 0.0, height: metrics.isCompactPhoneLayout ? 3.0 : 5.0)
        )
        button.widthAnchor.constraint(equalToConstant: metrics.brushCardWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: metrics.brushCardHeight).isActive = true

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let configuration = UIImage.SymbolConfiguration(pointSize: metrics.brushCardIconSize, weight: .bold)
        iconView.image = UIImage(systemName: symbolName, withConfiguration: configuration)?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = accentColor
        iconView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = UIFont.systemFont(ofSize: metrics.brushCardLabelFontSize, weight: .semibold)
        label.textColor = KCEditorVisualStyle.inkColor

        let halo = UIView()
        halo.translatesAutoresizingMaskIntoConstraints = false
        halo.backgroundColor = accentColor.withAlphaComponent(0.16)
        halo.layer.cornerRadius = metrics.brushCardHaloSize / 2.0

        button.addSubview(halo)
        button.addSubview(iconView)
        button.addSubview(label)

        NSLayoutConstraint.activate([
            halo.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: metrics.isCompactPhoneLayout ? 10.0 : 14.0),
            halo.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            halo.widthAnchor.constraint(equalToConstant: metrics.brushCardHaloSize),
            halo.heightAnchor.constraint(equalToConstant: metrics.brushCardHaloSize),
            iconView.centerXAnchor.constraint(equalTo: halo.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: halo.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: metrics.brushCardIconSize),
            iconView.heightAnchor.constraint(equalToConstant: metrics.brushCardIconSize),
            label.leadingAnchor.constraint(equalTo: halo.trailingAnchor, constant: metrics.isCompactPhoneLayout ? 10.0 : 14.0),
            label.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])

        return button
    }
}
