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
    /// T109 G3a：raised 按钮底色 0.92 → 0.82，玻璃感更通透（mockup `rgba(255,255,255,0.82)`）。
    static let raisedBackgroundColor = UIColor(white: 1.0, alpha: 0.82)
    static let compactBackgroundColor = UIColor(white: 1.0, alpha: 0.88)
    static let pillBackgroundColor = UIColor(white: 1.0, alpha: 0.78)
    static let disabledBackgroundColor = UIColor(white: 1.0, alpha: 0.68)
    static let saveActionColor = UIColor(red: 0.54, green: 0.80, blue: 0.98, alpha: 1.0)
    static let restoreViewportButtonColor = UIColor(white: 1.0, alpha: 0.98)
    static let restoreViewportBorderColor = UIColor(red: 0.20, green: 0.25, blue: 0.32, alpha: 0.30).cgColor
    static let borderColor = UIColor(white: 1.0, alpha: 0.78).cgColor
    static let activeBorderColor = UIColor(white: 1.0, alpha: 0.94).cgColor
    static let subtleBorderColor = UIColor(red: 0.17, green: 0.22, blue: 0.30, alpha: 0.12).cgColor
    static let shadowColor = UIColor(red: 0.37, green: 0.32, blue: 0.24, alpha: 1.0).cgColor
    static let inactiveShadowOpacity: Float = 0.05
    static let activeShadowOpacity: Float = 0.09
    static let disabledAlpha: CGFloat = 0.56

    // MARK: 玻璃材质 token（T109 液态玻璃，对齐 docs/product/mockups/ui-preview.html）

    /// 玻璃底色/染色（暖奶白，对齐 mockup `--glass rgba(255,251,246,0.72)`）。
    /// iOS 26+ 不额外染色；低版本作为 contentView 叠层。
    static let glassContentTint = UIColor(red: 1.0, green: 0.984, blue: 0.961, alpha: 0.34)
    /// 玻璃染色（强，用于弹层/Toast 等需更高对比处，对齐 `--glass-strong`）。
    static let glassContentTintStrong = UIColor(red: 1.0, green: 0.984, blue: 0.961, alpha: 0.50)
    /// 玻璃内描边：白高光（仅低版本降级路径用；iOS 26 液态玻璃自带高光边缘）。
    static let glassHighlightBorderColor = UIColor(white: 1.0, alpha: 0.76).cgColor
    /// 玻璃投影色：暖棕（对齐 mockup `--shadow rgba(125,91,49,…)`）。按钮投影暂沿用 `shadowColor`，留 G3 统一。
    static let glassShadowColor = UIColor(red: 0.49, green: 0.357, blue: 0.192, alpha: 1.0).cgColor

    /// 玻璃圆角分级（对齐 mockup：容器 30 / 左轨 34 / 底部 Dock 36；Toast/线稿选择器为小弹层，沿用 24/28）。
    static let floatingPanelCornerRadius: CGFloat = 30.0
    static let leftRailCornerRadius: CGFloat = 34.0
    static let bottomDockCornerRadius: CGFloat = 36.0
    static let toastCornerRadius: CGFloat = 24.0
    static let lineArtPickerCornerRadius: CGFloat = 28.0

    /// 创建液态玻璃效果视图（所有玻璃表面的唯一入口）：
    /// - iOS 26+：直接用系统 `UIGlassEffect(style: .regular)`——Apple 液态玻璃，自带折射/镜面高光/厚度感。
    ///   不设置 `tintColor`：保持系统玻璃校准的中性通透，暖调由奶白工作台背景折射提供；
    ///   如需明确色相可设 `tintColor`（系统按玻璃规则柔和混合，仍是半透明，不会变实色）。
    /// - iOS 26 以下：降级为 `systemMaterialLight` 模糊 + 暖底色叠层 + 白高光描边（近似玻璃，无液态折射）。
    static func makeGlassEffectView(contentTint: UIColor = glassContentTint) -> UIVisualEffectView {
        if #available(iOS 26.0, *) {
            let glass = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
            glass.isUserInteractionEnabled = false
            return glass
        }
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialLight))
        blur.isUserInteractionEnabled = false
        blur.contentView.backgroundColor = contentTint
        blur.layer.borderColor = glassHighlightBorderColor
        blur.layer.borderWidth = 1.0
        return blur
    }

    /// 玻璃表面统一裁剪：把 `UIVisualEffectView`（液态玻璃或降级模糊）裁到圆角。
    static func applyGlassSurface(
        to blurView: UIVisualEffectView,
        cornerRadius: CGFloat
    ) {
        blurView.layer.cornerRadius = cornerRadius
        blurView.layer.cornerCurve = .continuous
        blurView.layer.masksToBounds = true
    }

    /// 浮层玻璃铬样：外层 `panel` 承载暖棕投影，内层 `blurView` 经 `applyGlassSurface` 裁圆角。
    static func applyFloatingPanelChrome(
        to panel: UIView,
        blurView: UIVisualEffectView,
        cornerRadius: CGFloat = floatingPanelCornerRadius
    ) {
        panel.backgroundColor = UIColor.clear
        panel.layer.cornerRadius = cornerRadius
        panel.layer.cornerCurve = .continuous
        panel.layer.shadowColor = glassShadowColor
        panel.layer.shadowOpacity = 0.14
        panel.layer.shadowRadius = 18.0
        panel.layer.shadowOffset = CGSize(width: 0.0, height: 8.0)
        applyGlassSurface(to: blurView, cornerRadius: cornerRadius)
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
        // T109 G3a：暗细线描边 → 玻璃高光白边（`glassHighlightBorderColor`），与玻璃面板同源。
        view.layer.borderWidth = 1.0
        view.layer.borderColor = glassHighlightBorderColor
        view.layer.shadowColor = shadowColor
        view.layer.shadowOpacity = shadowOpacity
        view.layer.shadowRadius = shadowRadius
        view.layer.shadowOffset = shadowOffset

        // T109 G3a：顶部 1pt 白色内高光（mockup `inset 0 1px 0 rgba(255,255,255,0.76)`）。
        // 1pt 高 UIView，顶端圆角匹配按钮，其余直角；置底不抢子控件（图标/文字）；防重复加。
        let highlightTag = 0x4B43_4869 // "KCHi"
        if view.viewWithTag(highlightTag) == nil {
            let highlight = UIView()
            highlight.tag = highlightTag
            highlight.translatesAutoresizingMaskIntoConstraints = false
            highlight.backgroundColor = UIColor(white: 1.0, alpha: 0.76)
            highlight.layer.cornerRadius = cornerRadius
            highlight.layer.cornerCurve = .continuous
            highlight.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            highlight.clipsToBounds = true
            highlight.isUserInteractionEnabled = false
            view.addSubview(highlight)
            view.sendSubviewToBack(highlight)
            NSLayoutConstraint.activate([
                highlight.topAnchor.constraint(equalTo: view.topAnchor),
                highlight.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                highlight.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                highlight.heightAnchor.constraint(equalToConstant: 1.0)
            ])
        }
    }

    static func applyCompactButtonAppearance(to button: UIButton, accent: Bool, cornerRadius: CGFloat = 16.0) {
        button.backgroundColor = accent ? accentColor : compactBackgroundColor
        button.tintColor = accent ? accentInkColor : inkColor
        button.layer.cornerRadius = cornerRadius
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 1.0
        button.layer.borderColor = subtleBorderColor
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
        button.layer.borderColor = active ? activeBorderColor : subtleBorderColor
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
    private static let symbolImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 120
        return cache
    }()
    let metrics: KCDeviceLayoutMetrics

    static func cachedSystemImage(symbolName: String) -> UIImage? {
        cachedSystemImage(cacheKey: "\(symbolName)|default") {
            UIImage(systemName: symbolName)
        }
    }

    static func historySlotPlaceholderImage() -> UIImage? {
        cachedConfiguredSystemImage(symbolName: "photo", pointSize: 24.0, weight: .semibold, weightKey: "semibold")?
            .withTintColor(UIColor(red: 0.62, green: 0.67, blue: 0.74, alpha: 0.52), renderingMode: .alwaysOriginal)
    }

    private static func cachedConfiguredSystemImage(
        symbolName: String,
        pointSize: CGFloat,
        weight: UIImage.SymbolWeight,
        weightKey: String
    ) -> UIImage? {
        let formattedPointSize = Int(round(pointSize * 10.0))
        let cacheKey = "\(symbolName)|\(formattedPointSize)|\(weightKey)"
        return cachedSystemImage(cacheKey: cacheKey) {
            let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
            return UIImage(systemName: symbolName, withConfiguration: configuration)
        }
    }

    private static func cachedSystemImage(cacheKey: String, imageBuilder: () -> UIImage?) -> UIImage? {
        let key = cacheKey as NSString
        if let cachedImage = Self.symbolImageCache.object(forKey: key) {
            return cachedImage
        }

        guard let image = imageBuilder() else {
            return nil
        }
        Self.symbolImageCache.setObject(image, forKey: key)
        return image
    }

    func floatingPanel(cornerRadius: CGFloat = KCEditorVisualStyle.floatingPanelCornerRadius) -> UIView {
        let panel = UIView()

        let blurView = KCEditorVisualStyle.makeGlassEffectView()
        blurView.translatesAutoresizingMaskIntoConstraints = false
        KCEditorVisualStyle.applyFloatingPanelChrome(to: panel, blurView: blurView, cornerRadius: cornerRadius)
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
        let image = Self.cachedConfiguredSystemImage(symbolName: symbolName, pointSize: 20.0, weight: .bold, weightKey: "bold")
        button.setImage(image, for: .normal)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 56.0),
            button.heightAnchor.constraint(equalToConstant: 50.0)
        ])
        return button
    }

    func restoreViewportButton(symbolName: String) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        KCEditorVisualStyle.applyRaisedButtonAppearance(
            to: button,
            cornerRadius: 18.0,
            backgroundColor: KCEditorVisualStyle.restoreViewportButtonColor,
            shadowOpacity: 0.24,
            shadowRadius: 16.0,
            shadowOffset: CGSize(width: 0.0, height: 8.0)
        )
        button.tintColor = KCEditorVisualStyle.inkColor
        button.layer.borderColor = KCEditorVisualStyle.restoreViewportBorderColor
        button.layer.borderWidth = 2.0
        let image = Self.cachedConfiguredSystemImage(symbolName: symbolName, pointSize: 24.0, weight: .black, weightKey: "black")
        button.setImage(image, for: .normal)
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
        button.imageView?.contentMode = .center
        button.imageView?.alpha = 0.0
        button.imageView?.isHidden = true
        return button
    }

    func railToolButton(symbolName: String, slim: Bool) -> KDToolButton {
        self.railToolButton(symbolName: symbolName, slim: slim, size: 56.0, iconPointSize: 20.0)
    }

    func railToolButton(symbolName: String, slim: Bool, size: CGFloat, iconPointSize: CGFloat) -> KDToolButton {
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
        let image = Self.cachedConfiguredSystemImage(symbolName: symbolName, pointSize: iconPointSize, weight: .bold, weightKey: "bold")
        button.setImage(image, for: .normal)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: size),
            button.heightAnchor.constraint(equalToConstant: size)
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
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.72
        button.titleLabel?.lineBreakMode = .byTruncatingTail
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
        let image = Self.cachedConfiguredSystemImage(symbolName: symbolName, pointSize: 16.0, weight: .bold, weightKey: "bold")
        button.setImage(image, for: .normal)
        button.heightAnchor.constraint(equalToConstant: 36.0).isActive = true
        return button
    }

    func collapseToggleButton(symbolName: String) -> UIButton {
        // T109 G3b：折叠按钮由"实色 0.88"轻实色改为真玻璃（与所折叠的玻璃面板同源）。
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .clear
        button.layer.cornerRadius = 18.0
        button.layer.cornerCurve = .continuous
        button.layer.shadowColor = KCEditorVisualStyle.glassShadowColor
        button.layer.shadowOpacity = 0.14
        button.layer.shadowRadius = 18.0
        button.layer.shadowOffset = CGSize(width: 0.0, height: 8.0)
        let glass = KCEditorVisualStyle.makeGlassEffectView()
        KCEditorVisualStyle.applyGlassSurface(to: glass, cornerRadius: 18.0)
        glass.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(glass)
        button.sendSubviewToBack(glass)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: button.topAnchor),
            glass.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            glass.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        button.tintColor = KCEditorVisualStyle.inkColor
        button.setImage(Self.cachedConfiguredSystemImage(symbolName: symbolName, pointSize: 18.0, weight: .bold, weightKey: "bold"), for: .normal)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44.0),
            button.heightAnchor.constraint(equalToConstant: 44.0)
        ])
        return button
    }

    func toolStateChip() -> UIView {
        // T109 G3b：工具状态 chip 由"实色 0.88"改为真玻璃（与玻璃面板同源）。
        let chip = UIView()
        chip.translatesAutoresizingMaskIntoConstraints = false
        chip.backgroundColor = .clear
        chip.layer.cornerRadius = 18.0
        chip.layer.cornerCurve = .continuous
        chip.layer.shadowColor = KCEditorVisualStyle.glassShadowColor
        chip.layer.shadowOpacity = 0.14
        chip.layer.shadowRadius = 18.0
        chip.layer.shadowOffset = CGSize(width: 0.0, height: 8.0)
        let glass = KCEditorVisualStyle.makeGlassEffectView()
        KCEditorVisualStyle.applyGlassSurface(to: glass, cornerRadius: 18.0)
        glass.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(glass)
        chip.sendSubviewToBack(glass)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: chip.topAnchor),
            glass.leadingAnchor.constraint(equalTo: chip.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: chip.trailingAnchor),
            glass.bottomAnchor.constraint(equalTo: chip.bottomAnchor)
        ])
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
        iconView.image = Self.cachedConfiguredSystemImage(
            symbolName: symbolName,
            pointSize: metrics.brushCardIconSize,
            weight: .bold,
            weightKey: "bold"
        )?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = accentColor
        iconView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = UIFont.systemFont(ofSize: metrics.brushCardLabelFontSize, weight: .semibold)
        label.textColor = KCEditorVisualStyle.inkColor
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.78
        label.lineBreakMode = .byTruncatingTail

        let halo = UIView()
        halo.translatesAutoresizingMaskIntoConstraints = false
        halo.backgroundColor = accentColor.withAlphaComponent(0.10)
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
            label.trailingAnchor.constraint(lessThanOrEqualTo: button.trailingAnchor, constant: metrics.isCompactPhoneLayout ? -8.0 : -12.0),
            label.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])

        return button
    }
}
