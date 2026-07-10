//
//  KCMainViewController+LayoutMetrics.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/07.
//

import UIKit

// MARK: - 设备布局指标

extension KCMainViewController {
    var layoutMetrics: KCDeviceLayoutMetrics {
        KCDeviceLayoutMetrics(userInterfaceIdiom: UIDevice.current.userInterfaceIdiom)
    }

    var editorUIFactory: KCEditorUIFactory {
        KCEditorUIFactory(metrics: self.layoutMetrics)
    }

    var isCompactPhoneLayout: Bool {
        return self.layoutMetrics.isCompactPhoneLayout
    }

    func rightPanelOuterWidth() -> CGFloat {
        return self.layoutMetrics.rightPanelOuterWidth
    }

    func rightPanelWidth() -> CGFloat {
        return self.layoutMetrics.rightPanelWidth
    }

    func rightPanelTopOffset() -> CGFloat {
        return self.layoutMetrics.rightPanelTopOffset
    }

    func rightPanelTrailingOffset() -> CGFloat {
        return self.layoutMetrics.rightPanelTrailingOffset
    }

    func rightPanelBottomGap() -> CGFloat {
        return self.layoutMetrics.rightPanelBottomGap
    }

    func rightPanelInnerInset() -> CGFloat {
        return self.layoutMetrics.rightPanelInnerInset
    }

    func rightPanelStackSpacing() -> CGFloat {
        return self.layoutMetrics.rightPanelStackSpacing
    }

    func bottomDockWidth() -> CGFloat {
        return self.layoutMetrics.bottomDockWidth
    }

    func bottomDockHeight() -> CGFloat {
        return self.layoutMetrics.bottomDockHeight
    }

    func bottomDockBottomInset() -> CGFloat {
        return self.layoutMetrics.bottomDockBottomInset
    }

    func bottomDockHorizontalInset() -> CGFloat {
        return self.layoutMetrics.bottomDockHorizontalInset
    }

    func bottomDockVerticalInset() -> CGFloat {
        return self.layoutMetrics.bottomDockVerticalInset
    }

    func bottomDockStackSpacing() -> CGFloat {
        return self.layoutMetrics.bottomDockStackSpacing
    }

    func leftRailTopOffset() -> CGFloat {
        return self.layoutMetrics.leftRailTopOffset
    }

    func leftRailHeightMultiplier() -> CGFloat {
        return self.layoutMetrics.leftRailHeightMultiplier
    }

    func leftRailButtonSize() -> CGFloat {
        return self.layoutMetrics.leftRailButtonSize
    }

    func leftRailIconPointSize() -> CGFloat {
        return max(17.0, self.layoutMetrics.leftRailButtonSize * 0.36)
    }

    func leftRailStackSpacing() -> CGFloat {
        return self.layoutMetrics.leftRailStackSpacing
    }

    func brushCardWidth() -> CGFloat {
        return self.layoutMetrics.brushCardWidth
    }

    func brushCardHeight() -> CGFloat {
        return self.layoutMetrics.brushCardHeight
    }

    func brushCardIconSize() -> CGFloat {
        return self.layoutMetrics.brushCardIconSize
    }

    func brushCardHaloSize() -> CGFloat {
        return self.layoutMetrics.brushCardHaloSize
    }

    func brushCardLabelFontSize() -> CGFloat {
        return self.layoutMetrics.brushCardLabelFontSize
    }

    func historyThumbSize() -> CGFloat {
        return self.layoutMetrics.historyThumbSize
    }

    func historyDraftThumbHeight() -> CGFloat {
        return self.layoutMetrics.historyDraftThumbHeight
    }
}
