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
        let toast = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.layer.cornerRadius = 24.0
        toast.clipsToBounds = true
        toast.layer.borderWidth = 1.0
        toast.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        toast.alpha = 0.0
        toast.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
        view.addSubview(toast)

        let configuration = UIImage.SymbolConfiguration(pointSize: 24.0, weight: .bold)
        let symbolName = success ? "checkmark" : "exclamationmark.triangle.fill"
        let iconView = UIImageView(image: UIImage(systemName: symbolName, withConfiguration: configuration))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = success
            ? UIColor(red: 0.23, green: 0.58, blue: 0.34, alpha: 1.0)
            : UIColor(red: 0.83, green: 0.36, blue: 0.24, alpha: 1.0)
        toast.contentView.addSubview(iconView)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: anchorView.centerXAnchor),
            toast.topAnchor.constraint(equalTo: anchorView.bottomAnchor, constant: 14.0),
            toast.widthAnchor.constraint(equalToConstant: 64.0),
            toast.heightAnchor.constraint(equalToConstant: 52.0),
            iconView.centerXAnchor.constraint(equalTo: toast.contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: toast.contentView.centerYAnchor)
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
