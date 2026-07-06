//
//  KCDeviceLayoutMetrics.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit
import CoreGraphics

/// App 层设备布局指标：集中 iPhone / iPad 的尺寸决策，避免主控制器散落设备判断。
struct KCDeviceLayoutMetrics {
    let userInterfaceIdiom: UIUserInterfaceIdiom

    var isCompactPhoneLayout: Bool {
        userInterfaceIdiom == .phone
    }

    var rightPanelOuterWidth: CGFloat {
        isCompactPhoneLayout ? 238.0 : 272.0
    }

    var rightPanelWidth: CGFloat {
        isCompactPhoneLayout ? 214.0 : 248.0
    }

    var rightPanelTopOffset: CGFloat {
        isCompactPhoneLayout ? 128.0 : 150.0
    }

    var rightPanelTrailingOffset: CGFloat {
        isCompactPhoneLayout ? -24.0 : -40.0
    }

    var rightPanelBottomGap: CGFloat {
        isCompactPhoneLayout ? -10.0 : -16.0
    }

    var rightPanelInnerInset: CGFloat {
        isCompactPhoneLayout ? 14.0 : 18.0
    }

    var rightPanelStackSpacing: CGFloat {
        isCompactPhoneLayout ? 10.0 : 16.0
    }

    var bottomDockWidth: CGFloat {
        isCompactPhoneLayout ? 430.0 : 560.0
    }

    var bottomDockHeight: CGFloat {
        isCompactPhoneLayout ? 74.0 : 98.0
    }

    var bottomDockBottomInset: CGFloat {
        isCompactPhoneLayout ? -12.0 : -22.0
    }

    var bottomDockTitleWidth: CGFloat {
        isCompactPhoneLayout ? 54.0 : 88.0
    }

    var bottomDockTitleFontSize: CGFloat {
        isCompactPhoneLayout ? 13.0 : 16.0
    }

    var bottomDockHorizontalInset: CGFloat {
        isCompactPhoneLayout ? 14.0 : 22.0
    }

    var bottomDockVerticalInset: CGFloat {
        isCompactPhoneLayout ? 8.0 : 12.0
    }

    var bottomDockStackSpacing: CGFloat {
        isCompactPhoneLayout ? 8.0 : 12.0
    }

    var brushCardWidth: CGFloat {
        isCompactPhoneLayout ? 104.0 : 126.0
    }

    var brushCardHeight: CGFloat {
        isCompactPhoneLayout ? 54.0 : 68.0
    }

    var brushCardIconSize: CGFloat {
        isCompactPhoneLayout ? 18.0 : 22.0
    }

    var brushCardHaloSize: CGFloat {
        isCompactPhoneLayout ? 30.0 : 36.0
    }

    var brushCardLabelFontSize: CGFloat {
        isCompactPhoneLayout ? 12.0 : 14.0
    }

    var historyThumbSize: CGFloat {
        isCompactPhoneLayout ? 82.0 : 92.0
    }

    var historyDraftThumbHeight: CGFloat {
        isCompactPhoneLayout ? 74.0 : 86.0
    }
}
