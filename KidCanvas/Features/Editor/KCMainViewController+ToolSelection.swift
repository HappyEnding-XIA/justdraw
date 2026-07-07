//
//  KCMainViewController+ToolSelection.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/07.
//

import UIKit

// MARK: - 工具 / 画笔 / 颜色选择

extension KCMainViewController {
    func selectToolMode(_ mode: KDToolMode) {
        self.transientToolModeMemory.recordSelection(mode.domainToolMode)
        self.canvasView.currentToolMode = mode
        self.applyStoredWidthForCurrentTool()
        for button in self.toolButtons {
            let active = self.toolRailFeature.isButton(button, activeFor: mode)
            self.toolRailFeature.applySelectionAppearance(to: button, active: active)
        }
        self.refreshStickerEditButtons()
        self.refreshBrushDockSelection()
        self.scrollBrushDockToToolMode(mode)
        self.refreshSizePreview()
        self.refreshToolStateChip()
    }

    func selectBrushStyle(_ style: KDBrushStyle) {
        self.canvasView.currentBrushStyle = style
        self.applyStoredWidthForCurrentTool()
        self.refreshBrushDockSelection()
        self.refreshSizePreview()
        self.refreshToolStateChip()
    }

    func applyStoredWidthForCurrentTool() {
        guard self.sizeSlider != nil else {
            return
        }

        var width: CGFloat = CGFloat(self.sizeSlider.value)
        if self.canvasView.currentToolMode == .brush {
            let storedWidth = self.brushWidthsByStyle[self.canvasView.currentBrushStyle.rawValue]
            width = storedWidth ?? 12.0
        } else if self.canvasView.currentToolMode == .eraser {
            width = self.eraserSliderValue
        }

        width = self.clampedBrushWidth(width)
        self.sizeSlider.value = Float(width)
        self.canvasView.currentLineWidth = width
        self.refreshSizePreview()
    }

    func refreshSizePreview() {
        guard self.sizePreviewView != nil && self.sizePreviewShapeLayer != nil else {
            return
        }

        let bounds = self.sizePreviewView.bounds
        if bounds.isEmpty {
            return
        }

        let emphasizesSize = self.canvasView.currentToolMode == .brush || self.canvasView.currentToolMode == .eraser
        var previewDiameter = min(36.0, max(8.0, CGFloat(self.sizeSlider.value)))
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        var path: UIBezierPath?
        var fillColor: UIColor = self.canvasFeature.currentFillColor(for: self.canvasView)
        var strokeColor: UIColor = UIColor(white: 1.0, alpha: 0.92)
        var alpha: CGFloat = 1.0

        if self.canvasView.currentToolMode == .eraser {
            previewDiameter = min(38.0, max(16.0, CGFloat(self.sizeSlider.value) * 1.08))
            path = self.eraserControlsFeature.previewPath(
                for: self.canvasView.currentEraserShape,
                center: center,
                size: previewDiameter
            )
            fillColor = UIColor(white: 1.0, alpha: 1.0)
            strokeColor = UIColor(red: 0.50, green: 0.56, blue: 0.62, alpha: 0.55)
        } else {
            path = UIBezierPath(ovalIn: CGRect(x: center.x - previewDiameter / 2.0,
                                               y: center.y - previewDiameter / 2.0,
                                               width: previewDiameter,
                                               height: previewDiameter))
            if self.canvasView.currentBrushStyle == .pencil {
                alpha = 0.72
            } else if self.canvasView.currentBrushStyle == .crayon {
                alpha = 0.82
            }
        }

        self.sizePreviewView.alpha = emphasizesSize ? 1.0 : 0.45
        self.sizePreviewShapeLayer.frame = bounds
        self.sizePreviewShapeLayer.path = path?.cgPath
        self.sizePreviewShapeLayer.fillColor = fillColor.withAlphaComponent(alpha).cgColor
        self.sizePreviewShapeLayer.strokeColor = strokeColor.cgColor
        self.sizePreviewShapeLayer.lineWidth = self.canvasView.currentToolMode == .eraser ? 2.0 : 0.0
    }

    func refreshBrushDockSelection() {
        for button in self.brushButtons {
            let active = self.brushDockFeature.isButton(
                button,
                activeForToolMode: self.canvasView.currentToolMode,
                brushStyle: self.canvasView.currentBrushStyle
            )
            self.brushDockFeature.applySelectionAppearance(to: button, active: active)
            if active {
                self.scrollBrushDockToButton(button)
            }
        }
    }

    func scrollBrushDockToToolMode(_ mode: KDToolMode) {
        for button in self.brushButtons {
            let matches = self.brushDockFeature.button(
                button,
                matchesToolMode: mode,
                brushStyle: self.canvasView.currentBrushStyle
            )
            if matches {
                self.scrollBrushDockToButton(button)
                return
            }
        }
    }

    func scrollBrushDockToButton(_ button: UIButton) {
        guard let scrollView = self.scrollViewAncestorForView(button) else {
            return
        }
        if button.bounds.isEmpty {
            return
        }

        let targetRect = button.convert(button.bounds, to: scrollView)
        scrollView.scrollRectToVisible(targetRect.insetBy(dx: -18.0, dy: 0.0), animated: true)
    }

    func scrollViewAncestorForView(_ view: UIView) -> UIScrollView? {
        var candidate = view.superview
        while candidate != nil {
            if let scrollView = candidate as? UIScrollView {
                return scrollView
            }
            candidate = candidate?.superview
        }
        return nil
    }

    func selectColor(_ color: UIColor, sender: UIButton?) {
        self.canvasView.currentColor = color
        self.refreshSizePreview()
        self.refreshToolStateChip()
        self.activeColorButton = self.colorPaletteRenderer.applyActiveColor(
            color: color,
            preferredButton: sender,
            previousActiveButton: self.activeColorButton,
            paletteButtons: self.colorButtons,
            palette: self.currentPalette(),
            recentButtons: self.recentColorButtons,
            recentColors: self.contentPicker.recentColors,
            colorMatches: self.color(_:matchesColor:)
        )
    }

    func selectStickerSymbol(_ symbol: String?) {
        var resolved = symbol
        if (resolved ?? "").isEmpty {
            resolved = self.currentStickerSymbols().first
        }
        self.canvasView.currentStickerSymbol = resolved ?? ""
        self.brushStickerPanelView.applyStickerSymbolSelection(to: self.stickerButtons, selectedSymbol: resolved)
    }

    @objc func didTapPalette24() {
        self.contentPicker.setShowing36Palette(false)
        self.updatePaletteButtons()
        self.reloadPaletteGrid()
    }

    @objc func didTapPalette36() {
        self.contentPicker.setShowing36Palette(true)
        self.updatePaletteButtons()
        self.reloadPaletteGrid()
    }

    @objc func didTapCustomColor() {
        self.presentCustomColorPicker(animated: true, completion: nil)
    }

    func configuredCustomColorPicker() -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.selectedColor = self.canvasView.currentColor
        picker.modalPresentationStyle = .popover
        let popover = picker.popoverPresentationController
        popover?.sourceView = self.customColorButton ?? self.view
        popover?.sourceRect = self.customColorButton != nil
            ? self.customColorButton.bounds
            : CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1.0, height: 1.0)
        popover?.permittedArrowDirections = self.customColorButton != nil ? .any : []
        return picker
    }

    func presentCustomColorPicker(animated: Bool, completion: ((UIColorPickerViewController) -> Void)?) {
        let picker = self.configuredCustomColorPicker()
        self.present(picker, animated: animated) {
            completion?(picker)
        }
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        self.canvasView.currentColor = viewController.selectedColor
        self.selectColor(viewController.selectedColor, sender: nil)
        self.addRecentColor(viewController.selectedColor)
    }

    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        self.canvasView.currentColor = viewController.selectedColor
        self.selectColor(viewController.selectedColor, sender: nil)
    }

    @objc func didTapCircleEraser() {
        self.canvasView.currentEraserShape = .circle
        self.refreshEraserShapeButtons()
        self.selectToolMode(.eraser)
        self.refreshSizePreview()
    }

    @objc func didTapCloudEraser() {
        self.canvasView.currentEraserShape = .cloud
        self.refreshEraserShapeButtons()
        self.selectToolMode(.eraser)
        self.refreshSizePreview()
    }

    @objc func didTapStarEraser() {
        self.canvasView.currentEraserShape = .star
        self.refreshEraserShapeButtons()
        self.selectToolMode(.eraser)
        self.refreshSizePreview()
    }

    @objc func didTapDeleteSticker() {
        self.canvasView.deleteSelectedSticker()
        self.refreshStickerEditButtons()
    }

    @objc func didTapBringStickerFront() {
        self.canvasView.bringSelectedStickerToFront()
        self.refreshStickerEditButtons()
    }

    @objc func didTapToolButton(_ button: KDToolButton) {
        self.selectToolMode(button.toolMode)
    }

    @objc func didTapColorButton(_ button: UIButton) {
        let palette = self.currentPalette()
        if button.tag < palette.count {
            self.selectColor(palette[button.tag], sender: button)
        }
    }

    @objc func didTapRecentColorButton(_ button: UIButton) {
        if button.tag < self.contentPicker.recentColors.count {
            self.selectColor(self.contentPicker.recentColors[button.tag], sender: button)
        }
    }

    @objc func didTapBrushButton(_ button: KDBrushButton) {
        if !button.representsBrushStyle {
            self.selectToolMode(button.toolMode)
            return
        }

        self.selectToolMode(.brush)
        self.selectBrushStyle(button.brushStyle)
    }

    @objc func didTapStickerButton(_ button: UIButton) {
        self.selectStickerSymbol(button.accessibilityIdentifier)
        self.selectToolMode(.sticker)
        self.refreshStickerEditButtons()
    }

    @objc func didTapStickerCategoryButton(_ button: UIButton) {
        guard let category = self.stickerCategoryFromButton(button) else {
            return
        }
        if self.contentPicker.stickerSymbolsByCategory[category] == nil {
            return
        }

        self.contentPicker.selectStickerCategory(category)
        let firstSymbol = self.currentStickerSymbols().first
        if let firstSymbol, firstSymbol.count > 0 {
            self.canvasView.currentStickerSymbol = firstSymbol
        }
        self.reloadStickerButtons()
    }
}
