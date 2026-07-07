//
//  KCToastPresenter.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit

/// 保存反馈 Toast 展示器。只负责 Toast UI 和动画，不处理保存业务语义。
final class KCToastPresenter {
    var dismissalHandler: ((UIView) -> Void)?

    func showSaveToast(success: Bool, in view: UIView, anchorView: UIView) -> UIView {
        self.showToast(
            title: success ? KCL10n.saveSuccessToastTitle : KCL10n.saveFailedToastTitle,
            symbolName: success ? "checkmark" : "exclamationmark.triangle.fill",
            tintColor: success
                ? UIColor(red: 0.23, green: 0.58, blue: 0.34, alpha: 1.0)
                : UIColor(red: 0.83, green: 0.36, blue: 0.24, alpha: 1.0),
            in: view,
            anchorView: anchorView
        )
    }

    func showPhotoExportFailedToast(in view: UIView, anchorView: UIView) -> UIView {
        self.showToast(
            title: KCL10n.photoExportFailedToastTitle,
            symbolName: "photo.badge.exclamationmark",
            tintColor: UIColor(red: 0.83, green: 0.36, blue: 0.24, alpha: 1.0),
            in: view,
            anchorView: anchorView
        )
    }

    private func showToast(
        title: String,
        symbolName: String,
        tintColor: UIColor,
        in view: UIView,
        anchorView: UIView
    ) -> UIView {
        let toast = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.layer.cornerRadius = 24.0
        toast.clipsToBounds = true
        toast.layer.borderWidth = 1.0
        toast.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        toast.alpha = 0.0
        toast.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
        view.addSubview(toast)

        let configuration = UIImage.SymbolConfiguration(pointSize: 20.0, weight: .bold)
        let iconView = UIImageView(image: UIImage(systemName: symbolName, withConfiguration: configuration))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = tintColor

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textColor = UIColor(red: 0.19, green: 0.24, blue: 0.29, alpha: 1.0)
        titleLabel.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.78
        titleLabel.lineBreakMode = .byTruncatingTail

        let stackView = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8.0
        toast.contentView.addSubview(stackView)
        toast.accessibilityLabel = titleLabel.text

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: anchorView.centerXAnchor),
            toast.topAnchor.constraint(equalTo: anchorView.bottomAnchor, constant: 14.0),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 96.0),
            toast.widthAnchor.constraint(lessThanOrEqualToConstant: 156.0),
            toast.heightAnchor.constraint(equalToConstant: 52.0),
            stackView.centerXAnchor.constraint(equalTo: toast.contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: toast.contentView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: toast.contentView.leadingAnchor, constant: 14.0),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: toast.contentView.trailingAnchor, constant: -14.0)
        ])

        UIView.animate(
            withDuration: 0.18,
            delay: 0.0,
            usingSpringWithDamping: 0.72,
            initialSpringVelocity: 0.0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: {
                toast.alpha = 1.0
                toast.transform = .identity
            },
            completion: { [weak self] _ in
                UIView.animate(
                    withDuration: 0.22,
                    delay: 0.85,
                    options: [.beginFromCurrentState, .allowUserInteraction],
                    animations: {
                        toast.alpha = 0.0
                        toast.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
                    },
                    completion: { _ in
                        toast.removeFromSuperview()
                        self?.dismissalHandler?(toast)
                    }
                )
            }
        )

        return toast
    }

    func dismiss(_ toastView: UIView?) {
        toastView?.removeFromSuperview()
    }
}
