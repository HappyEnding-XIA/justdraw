//
//  KCColorPalettePanelRenderer.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit

/// 颜色面板 UIKit 渲染器。只负责创建色盘视图、最近色行和高亮样式，不持有颜色业务状态。
final class KCColorPalettePanelRenderer {

    struct Configuration {
        let title: String
        let palette24Title: String
        let palette36Title: String
        let customColorTitle: String
        let customColorAccessibility: String
        let isCompactPhoneLayout: Bool
        let innerInset: CGFloat
        let paletteGridWidth: CGFloat
        let paletteGridInitialHeight: CGFloat
        let paletteColorButtonSize: CGFloat
        let paletteColorButtonSpacing: CGFloat
    }

    struct RenderedPanel {
        let palette24Button: UIButton
        let palette36Button: UIButton
        let customColorButton: UIButton
        let paletteGridView: UIView
        let paletteGridHeightConstraint: NSLayoutConstraint
        let recentColorRowStack: UIStackView
    }

    struct PaletteGridResult {
        let buttons: [UIButton]
    }

    struct RecentColorResult {
        let buttons: [UIButton]
    }

    private let defaultBorderColor = UIColor(white: 1.0, alpha: 0.92).cgColor
    private let activeBorderColor = UIColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 0.18).cgColor

    func renderPanel(
        in panel: UIView,
        configuration: Configuration,
        makeTitleLabel: (String) -> UILabel,
        makeSegmentButton: (String, Bool) -> UIButton,
        target: Any?,
        palette24Action: Selector,
        palette36Action: Selector,
        customColorAction: Selector,
        registerPressFeedback: (UIControl) -> Void
    ) -> RenderedPanel {
        let titleLabel = makeTitleLabel(configuration.title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)

        let segmentContainer = UIView()
        segmentContainer.translatesAutoresizingMaskIntoConstraints = false
        segmentContainer.backgroundColor = UIColor(white: 1.0, alpha: 0.76)
        segmentContainer.layer.cornerRadius = 18.0
        panel.addSubview(segmentContainer)

        let palette24Button = makeSegmentButton("24", true)
        let palette36Button = makeSegmentButton("36", false)
        palette24Button.accessibilityLabel = configuration.palette24Title
        palette24Button.accessibilityIdentifier = "palette.24"
        palette36Button.accessibilityLabel = configuration.palette36Title
        palette36Button.accessibilityIdentifier = "palette.36"
        palette24Button.addTarget(target, action: palette24Action, for: .touchUpInside)
        palette36Button.addTarget(target, action: palette36Action, for: .touchUpInside)
        segmentContainer.addSubview(palette24Button)
        segmentContainer.addSubview(palette36Button)

        let grid = UIView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.tag = 701
        panel.addSubview(grid)

        let customButton = UIButton(type: .system)
        customButton.translatesAutoresizingMaskIntoConstraints = false
        customButton.setTitle(configuration.customColorTitle, for: .normal)
        customButton.titleLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: .bold)
        customButton.setTitleColor(UIColor(red: 0.23, green: 0.28, blue: 0.35, alpha: 1.0), for: .normal)
        customButton.backgroundColor = UIColor(white: 1.0, alpha: 0.82)
        customButton.layer.cornerRadius = 18.0
        customButton.layer.borderWidth = 1.0
        customButton.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        customButton.accessibilityLabel = configuration.customColorAccessibility
        customButton.accessibilityIdentifier = "palette.custom-color"
        customButton.addTarget(target, action: customColorAction, for: .touchUpInside)
        registerPressFeedback(customButton)
        panel.addSubview(customButton)

        let recentScrollView = UIScrollView()
        recentScrollView.translatesAutoresizingMaskIntoConstraints = false
        recentScrollView.showsHorizontalScrollIndicator = false
        recentScrollView.alwaysBounceHorizontal = true
        recentScrollView.clipsToBounds = true
        panel.addSubview(recentScrollView)

        let recentRow = UIStackView()
        recentRow.translatesAutoresizingMaskIntoConstraints = false
        recentRow.axis = .horizontal
        recentRow.spacing = configuration.paletteColorButtonSpacing
        recentRow.distribution = .equalSpacing
        recentRow.tag = 702
        recentScrollView.addSubview(recentRow)

        let segmentWidth: CGFloat = configuration.isCompactPhoneLayout ? 132.0 : 146.0
        let segmentHeight: CGFloat = configuration.isCompactPhoneLayout ? 38.0 : 42.0
        let segmentButtonWidth: CGFloat = configuration.isCompactPhoneLayout ? 60.0 : 68.0
        let segmentButtonHeight: CGFloat = configuration.isCompactPhoneLayout ? 28.0 : 32.0
        let customButtonWidth: CGFloat = configuration.isCompactPhoneLayout ? 78.0 : 92.0
        let customButtonHeight: CGFloat = configuration.isCompactPhoneLayout ? 32.0 : 36.0
        let inset = configuration.innerInset

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: inset),

            segmentContainer.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            segmentContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12.0),
            segmentContainer.widthAnchor.constraint(equalToConstant: segmentWidth),
            segmentContainer.heightAnchor.constraint(equalToConstant: segmentHeight),

            palette24Button.leadingAnchor.constraint(equalTo: segmentContainer.leadingAnchor, constant: 6.0),
            palette24Button.centerYAnchor.constraint(equalTo: segmentContainer.centerYAnchor),
            palette24Button.widthAnchor.constraint(equalToConstant: segmentButtonWidth),
            palette24Button.heightAnchor.constraint(equalToConstant: segmentButtonHeight),

            palette36Button.trailingAnchor.constraint(equalTo: segmentContainer.trailingAnchor, constant: -6.0),
            palette36Button.centerYAnchor.constraint(equalTo: segmentContainer.centerYAnchor),
            palette36Button.widthAnchor.constraint(equalToConstant: segmentButtonWidth),
            palette36Button.heightAnchor.constraint(equalToConstant: segmentButtonHeight),

            grid.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            grid.topAnchor.constraint(equalTo: segmentContainer.bottomAnchor, constant: 14.0),
            grid.widthAnchor.constraint(equalToConstant: configuration.paletteGridWidth),

            customButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            customButton.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 12.0),
            customButton.widthAnchor.constraint(equalToConstant: customButtonWidth),
            customButton.heightAnchor.constraint(equalToConstant: customButtonHeight),

            recentScrollView.leadingAnchor.constraint(
                equalTo: customButton.trailingAnchor,
                constant: configuration.isCompactPhoneLayout ? 8.0 : 12.0
            ),
            recentScrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -inset),
            recentScrollView.centerYAnchor.constraint(equalTo: customButton.centerYAnchor),
            recentScrollView.heightAnchor.constraint(equalToConstant: configuration.paletteColorButtonSize),

            recentRow.leadingAnchor.constraint(equalTo: recentScrollView.contentLayoutGuide.leadingAnchor),
            recentRow.trailingAnchor.constraint(equalTo: recentScrollView.contentLayoutGuide.trailingAnchor),
            recentRow.topAnchor.constraint(equalTo: recentScrollView.contentLayoutGuide.topAnchor),
            recentRow.bottomAnchor.constraint(equalTo: recentScrollView.contentLayoutGuide.bottomAnchor),
            recentRow.heightAnchor.constraint(equalTo: recentScrollView.frameLayoutGuide.heightAnchor),

            customButton.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -inset)
        ])

        let gridHeightConstraint = grid.heightAnchor.constraint(equalToConstant: configuration.paletteGridInitialHeight)
        gridHeightConstraint.isActive = true

        return RenderedPanel(
            palette24Button: palette24Button,
            palette36Button: palette36Button,
            customColorButton: customButton,
            paletteGridView: grid,
            paletteGridHeightConstraint: gridHeightConstraint,
            recentColorRowStack: recentRow
        )
    }

    func reloadPaletteGrid(
        in grid: UIView,
        palette: [UIColor],
        columns: Int,
        buttonSize: CGFloat,
        spacing: CGFloat,
        gridHeightConstraint: NSLayoutConstraint,
        gridHeight: CGFloat,
        target: Any?,
        action: Selector,
        registerPressFeedback: (UIControl) -> Void,
        accessibilityLabelProvider: (Int) -> String
    ) -> PaletteGridResult {
        for subview in grid.subviews {
            subview.removeFromSuperview()
        }
        gridHeightConstraint.constant = gridHeight

        var buttons: [UIButton] = []
        buttons.reserveCapacity(palette.count)

        for index in 0..<palette.count {
            let colorButton = UIButton(type: .custom)
            colorButton.translatesAutoresizingMaskIntoConstraints = false
            colorButton.backgroundColor = palette[index]
            applyColorButtonBaseAppearance(to: colorButton, buttonSize: buttonSize)
            colorButton.tag = index
            colorButton.accessibilityLabel = accessibilityLabelProvider(index)
            colorButton.accessibilityIdentifier = "palette.color.\(index + 1)"
            colorButton.addTarget(target, action: action, for: .touchUpInside)
            registerPressFeedback(colorButton)
            grid.addSubview(colorButton)
            buttons.append(colorButton)

            let row = index / columns
            let column = index % columns
            NSLayoutConstraint.activate([
                colorButton.leadingAnchor.constraint(equalTo: grid.leadingAnchor, constant: CGFloat(column) * (buttonSize + spacing)),
                colorButton.topAnchor.constraint(equalTo: grid.topAnchor, constant: CGFloat(row) * (buttonSize + spacing)),
                colorButton.widthAnchor.constraint(equalToConstant: buttonSize),
                colorButton.heightAnchor.constraint(equalToConstant: buttonSize)
            ])
        }

        return PaletteGridResult(buttons: buttons)
    }

    func reloadRecentColorRow(
        in recentStack: UIStackView,
        recentColors: [UIColor],
        buttonSize: CGFloat,
        target: Any?,
        action: Selector,
        registerPressFeedback: (UIControl) -> Void,
        accessibilityLabelProvider: (Int) -> String
    ) -> RecentColorResult {
        for view in recentStack.arrangedSubviews {
            recentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        var buttons: [UIButton] = []
        buttons.reserveCapacity(recentColors.count)

        for index in 0..<recentColors.count {
            let button = UIButton(type: .custom)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.backgroundColor = recentColors[index]
            applyColorButtonBaseAppearance(to: button, buttonSize: buttonSize)
            button.tag = index
            button.accessibilityLabel = accessibilityLabelProvider(index)
            button.accessibilityIdentifier = "palette.recent.\(index + 1)"
            button.addTarget(target, action: action, for: .touchUpInside)
            registerPressFeedback(button)
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: buttonSize),
                button.heightAnchor.constraint(equalToConstant: buttonSize)
            ])
            recentStack.addArrangedSubview(button)
            buttons.append(button)
        }

        return RecentColorResult(buttons: buttons)
    }

    func updateSegmentButtons(palette24Button: UIButton, palette36Button: UIButton, showing36Palette: Bool) {
        applySegmentAppearance(to: palette24Button, active: !showing36Palette)
        applySegmentAppearance(to: palette36Button, active: showing36Palette)
    }

    func applyActiveColor(
        color: UIColor,
        preferredButton: UIButton?,
        previousActiveButton: UIButton?,
        paletteButtons: [UIButton],
        palette: [UIColor],
        recentButtons: [UIButton],
        recentColors: [UIColor],
        colorMatches: (UIColor?, UIColor?) -> Bool
    ) -> UIButton? {
        previousActiveButton?.layer.borderColor = defaultBorderColor

        if let preferredButton {
            preferredButton.layer.borderColor = activeBorderColor
            return preferredButton
        }

        for button in paletteButtons where button.tag < palette.count {
            if colorMatches(palette[button.tag], color) {
                button.layer.borderColor = activeBorderColor
                return button
            }
        }

        for button in recentButtons where button.tag < recentColors.count {
            if colorMatches(recentColors[button.tag], color) {
                button.layer.borderColor = activeBorderColor
                return button
            }
        }

        return nil
    }

    private func applyColorButtonBaseAppearance(to button: UIButton, buttonSize: CGFloat) {
        button.layer.cornerRadius = buttonSize / 2.0
        button.layer.borderWidth = 3.0
        button.layer.borderColor = defaultBorderColor
    }

    private func applySegmentAppearance(to button: UIButton, active: Bool) {
        button.setTitleColor(
            active
                ? UIColor(red: 0.39, green: 0.26, blue: 0.0, alpha: 1.0)
                : UIColor(red: 0.49, green: 0.53, blue: 0.59, alpha: 1.0),
            for: .normal
        )
        button.backgroundColor = active ? UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0) : UIColor.clear
        button.layer.borderWidth = active ? 1.0 : 0.0
    }
}
