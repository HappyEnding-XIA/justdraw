//
//  KCEditorUIFactory.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit

/// App 层编辑器 UI 工厂：集中通用 UIKit 控件的样式创建。
/// 只负责外观和固定尺寸，不绑定业务事件，不访问画布/会话状态。
struct KCEditorUIFactory {
    let metrics: KCDeviceLayoutMetrics

    func floatingPanel() -> UIView {
        let panel = UIView()
        panel.backgroundColor = UIColor.clear
        panel.layer.cornerRadius = 30.0
        panel.layer.shadowColor = UIColor(red: 0.34, green: 0.26, blue: 0.14, alpha: 1.0).cgColor
        panel.layer.shadowOpacity = 0.14
        panel.layer.shadowRadius = 26.0
        panel.layer.shadowOffset = CGSize(width: 0, height: 14)

        let effect = UIBlurEffect(style: .systemThinMaterialLight)
        let blurView = UIVisualEffectView(effect: effect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 30.0
        blurView.layer.masksToBounds = true
        blurView.layer.borderColor = UIColor(white: 1.0, alpha: 0.66).cgColor
        blurView.layer.borderWidth = 1.0
        blurView.contentView.backgroundColor = UIColor(white: 1.0, alpha: 0.28)
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
        button.backgroundColor = accentColor ?? UIColor(white: 1.0, alpha: 0.76)
        button.layer.cornerRadius = 18.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        button.layer.shadowColor = UIColor(red: 0.47, green: 0.40, blue: 0.29, alpha: 1.0).cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 10.0
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        button.tintColor = UIColor(red: 0.19, green: 0.26, blue: 0.33, alpha: 1.0)
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
        button.layer.cornerRadius = 20.0
        button.clipsToBounds = true
        button.layer.borderWidth = 2.0
        button.layer.borderColor = UIColor(red: 0.17, green: 0.22, blue: 0.30, alpha: 0.08).cgColor
        button.backgroundColor = UIColor(red: 1.0, green: 0.995, blue: 0.98, alpha: 1.0)
        button.imageView?.contentMode = .scaleAspectFill
        button.layer.shadowColor = UIColor(red: 0.40, green: 0.32, blue: 0.22, alpha: 1.0).cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 10.0
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
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
        button.tintColor = UIColor(red: 0.19, green: 0.26, blue: 0.33, alpha: 1.0)
        button.backgroundColor = slim
            ? UIColor(red: 0.96, green: 0.85, blue: 0.48, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 0.82)
        button.layer.cornerRadius = 20.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        button.layer.shadowColor = UIColor(red: 0.47, green: 0.40, blue: 0.29, alpha: 1.0).cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 8.0
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
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
            active ? UIColor(red: 0.39, green: 0.26, blue: 0.0, alpha: 1.0) : UIColor(red: 0.49, green: 0.53, blue: 0.59, alpha: 1.0),
            for: .normal
        )
        button.backgroundColor = active ? UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0) : UIColor.clear
        button.layer.cornerRadius = 16.0
        button.layer.borderWidth = active ? 1.0 : 0.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.76).cgColor
        return button
    }

    func historyActionButton(title: String, accent: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: .bold)
        button.setTitleColor(
            accent ? UIColor(red: 0.39, green: 0.26, blue: 0.0, alpha: 1.0) : UIColor(red: 0.23, green: 0.28, blue: 0.35, alpha: 1.0),
            for: .normal
        )
        button.backgroundColor = accent ? UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0) : UIColor(white: 1.0, alpha: 0.82)
        button.layer.cornerRadius = 18.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        return button
    }

    func smallToolButton(symbolName: String, accent: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = accent
            ? UIColor(red: 0.39, green: 0.26, blue: 0.0, alpha: 1.0)
            : UIColor(red: 0.23, green: 0.28, blue: 0.35, alpha: 1.0)
        button.backgroundColor = accent
            ? UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 0.82)
        button.layer.cornerRadius = 16.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        let configuration = UIImage.SymbolConfiguration(pointSize: 16.0, weight: .bold)
        let image = UIImage(systemName: symbolName, withConfiguration: configuration)
        button.setImage(image, for: .normal)
        button.heightAnchor.constraint(equalToConstant: 36.0).isActive = true
        return button
    }

    func toolCardButton(symbolName: String, accentColor: UIColor, title: String) -> KDBrushButton {
        let button = KDBrushButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.84)
        button.layer.cornerRadius = metrics.isCompactPhoneLayout ? 22.0 : 28.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        button.layer.shadowColor = UIColor(red: 0.47, green: 0.40, blue: 0.29, alpha: 1.0).cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = metrics.isCompactPhoneLayout ? 7.0 : 10.0
        button.layer.shadowOffset = CGSize(width: 0, height: metrics.isCompactPhoneLayout ? 4.0 : 6.0)
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
        label.textColor = UIColor(red: 0.16, green: 0.22, blue: 0.28, alpha: 1.0)

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
