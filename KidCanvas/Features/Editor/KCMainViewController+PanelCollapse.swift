//
//  KCMainViewController+PanelCollapse.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/07.
//

import UIKit

// MARK: - 工具栏收起（小屏画布空间）

extension KCMainViewController {
    /// 构建常驻可见的收起按钮（右下角，位于主绘画区之外），以及仅在浮动面板
    /// 收起时显示的最小当前工具芯片。iPhone 与 iPad 默认都展开；该按钮可让
    /// 用户隐藏全部浮动面板以释放画布空间——在 iPhone 横屏下最有用。
    func buildCollapseControls() {
        let toggle = self.editorUIFactory.collapseToggleButton(symbolName: "rectangle.compress.vertical")
        toggle.accessibilityLabel = KCL10n.hideToolsTitle
        toggle.addTarget(self, action: #selector(togglePanelsCollapsed(_:)), for: .touchUpInside)
        self.view.addSubview(toggle)
        self.collapseToggleButton = toggle

        let chip = self.editorUIFactory.toolStateChip()
        self.view.addSubview(chip)
        self.toolStateChip = chip

        let swatch = self.editorUIFactory.toolStateSwatch()
        chip.addSubview(swatch)
        self.toolStateSwatch = swatch

        let label = self.editorUIFactory.toolStateLabel()
        chip.addSubview(label)
        self.toolStateLabel = label

        NSLayoutConstraint.activate([
            toggle.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -20.0),
            toggle.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -20.0),

            chip.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -10.0),
            chip.centerYAnchor.constraint(equalTo: toggle.centerYAnchor),
            chip.heightAnchor.constraint(equalToConstant: 36.0),

            swatch.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 10.0),
            swatch.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            swatch.widthAnchor.constraint(equalToConstant: 18.0),
            swatch.heightAnchor.constraint(equalToConstant: 18.0),

            label.leadingAnchor.constraint(equalTo: swatch.trailingAnchor, constant: 8.0),
            label.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -12.0),
            label.centerYAnchor.constraint(equalTo: chip.centerYAnchor)
        ])

        self.refreshToolStateChip()
    }

    @objc func togglePanelsCollapsed(_ button: UIButton) {
        self.editorPanels.toggleCollapsed()
        self.applyPanelsCollapsedAnimated(true)
    }

    /// 隐藏或显示浮动面板。切换只改 `hidden`/`alpha`/userInteractionEnabled，
    /// 所有约束保持不变，因此旋转、后台、打开历史都不会让控件错位，
    /// 也不触碰任何工具/颜色/橡皮/贴纸/撤销/保存状态。
    func applyPanelsCollapsedAnimated(_ animated: Bool) {
        self.refreshToolStateChip()
        // 折叠态下的图标/标签/各视图 alpha·hidden·enabled 决策由编辑器面板 Feature（KCDomain）给出。
        let state = self.editorPanels.collapseState

        self.collapseToggleButton.setImage(self.safeSystemImageNamed(state.toggleIconName), for: .normal)
        self.collapseToggleButton.accessibilityLabel = KCL10n.tr(state.toggleAccessibilityLabel)

        // 渐变过程中保留面板在视图层级中（已布局），在完成回调里再切换 hidden。
        // userInteractionEnabled 不可动画，故立即生效——收起的面板会立刻停止
        // 拦截画布触摸。
        for panel in self.collapsiblePanels {
            panel.isHidden = false
        }
        self.toolStateChip.isHidden = false

        let panelAlpha = state.panelAlpha
        let panelEnabled = state.panelIsUserInteractionEnabled
        let chipAlpha = state.chipAlpha
        let update: () -> Void = {
            for panel in self.collapsiblePanels {
                panel.alpha = panelAlpha
                panel.isUserInteractionEnabled = panelEnabled
            }
            self.toolStateChip.alpha = chipAlpha
        }

        let panelHidden = state.panelIsHidden
        let chipHidden = state.chipIsHidden
        let finalize: () -> Void = {
            for panel in self.collapsiblePanels {
                panel.isHidden = panelHidden
            }
            self.toolStateChip.isHidden = chipHidden
        }

        if animated {
            UIView.animate(withDuration: 0.25,
                           delay: 0.0,
                           options: .curveEaseOut,
                           animations: update,
                           completion: { _ in
                               finalize()
                           })
        } else {
            update()
            finalize()
        }
    }

    /// 从画布状态刷新最小当前工具芯片（色块 + 工具名）。在收起时以及工具/画笔/
    /// 颜色变化时调用，使芯片在面板隐藏期间始终反映当前绘图工具。
    func refreshToolStateChip() {
        guard self.toolStateLabel != nil else {
            return
        }

        let swatchColor = self.editorPanels.chipSwatchColor(
            toolMode: self.canvasView.currentToolMode,
            currentColor: self.canvasView.currentColor
        )

        let title = self.drawingEngine.toolStateChipTitle(
            toolMode: self.canvasView.currentToolMode.rawValue,
            brushStyle: self.canvasView.currentBrushStyle.rawValue
        )
        self.toolStateLabel.text = KCL10n.tr(title)
        self.toolStateSwatch.backgroundColor = swatchColor
    }
}
