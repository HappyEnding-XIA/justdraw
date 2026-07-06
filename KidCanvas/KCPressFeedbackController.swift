//
//  KCPressFeedbackController.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit
import ObjectiveC

private var KCPressBaseTransformKey: UInt8 = 0
private var KCPressBaseAlphaKey: UInt8 = 0

/// 通用按钮按压反馈控制器。只负责注册控件事件和播放按压动画，不持有业务状态。
final class KCPressFeedbackController {

    func register(_ control: UIControl) {
        control.addTarget(self, action: #selector(handleControlPressDown(_:)), for: .touchDown)
        control.addTarget(self, action: #selector(handleControlPressDown(_:)), for: .touchDragEnter)
        control.addTarget(self, action: #selector(handleControlPressRelease(_:)), for: .touchUpInside)
        control.addTarget(self, action: #selector(handleControlPressRelease(_:)), for: .touchUpOutside)
        control.addTarget(self, action: #selector(handleControlPressRelease(_:)), for: .touchCancel)
        control.addTarget(self, action: #selector(handleControlPressRelease(_:)), for: .touchDragExit)
    }

    @objc private func handleControlPressDown(_ control: UIControl) {
        if !control.isEnabled || objc_getAssociatedObject(control, &KCPressBaseTransformKey) != nil {
            return
        }

        objc_setAssociatedObject(
            control,
            &KCPressBaseTransformKey,
            NSValue(cgAffineTransform: control.transform),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            control,
            &KCPressBaseAlphaKey,
            NSNumber(value: Double(control.alpha)),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        let pressedTransform = control.transform.scaledBy(x: 0.96, y: 0.96)
        UIView.animate(
            withDuration: 0.16,
            delay: 0.0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: {
                control.transform = pressedTransform
                control.alpha = max(0.72, control.alpha * 0.92)
            },
            completion: nil
        )
    }

    @objc private func handleControlPressRelease(_ control: UIControl) {
        guard let storedTransform = objc_getAssociatedObject(control, &KCPressBaseTransformKey) as? NSValue else {
            return
        }
        let storedAlpha = objc_getAssociatedObject(control, &KCPressBaseAlphaKey) as? NSNumber

        let baseTransform = storedTransform.cgAffineTransformValue
        let baseAlpha: CGFloat = storedAlpha != nil ? CGFloat(storedAlpha!.doubleValue) : 1.0
        objc_setAssociatedObject(control, &KCPressBaseTransformKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(control, &KCPressBaseAlphaKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        UIView.animate(
            withDuration: 0.18,
            delay: 0.0,
            usingSpringWithDamping: 0.68,
            initialSpringVelocity: 0.0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: {
                control.transform = baseTransform
                control.alpha = baseAlpha
            },
            completion: nil
        )
    }
}
