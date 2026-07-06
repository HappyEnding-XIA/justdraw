//
//  KCMainViewController.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/26.
//

import UIKit
import QuartzCore
import KCCommon
import KCDomain
import KCContentCatalog

// MARK: - KDToolButton

class KDToolButton: UIButton {
    var toolMode: KDToolMode = .brush
}

// MARK: - KDBrushButton

class KDBrushButton: UIButton {
    var brushStyle: KDBrushStyle = .pencil
    var toolMode: KDToolMode = .brush
    var representsBrushStyle: Bool = false
}

// MARK: - KCHexColor → UIColor 桥

/// 把 UIKit 无关的 `KCHexColor`（KCCommon）转成 `UIColor`。两者都用归一化 0...1
/// 分量，因此转换是无损的：与原 `makePalette24/36` 里直接 `UIColor(red:green:blue:alpha:)`
/// 的取值逐位一致，避免色板视觉回归。
extension UIColor {
    convenience init(kcHex hex: KCHexColor) {
        self.init(red: hex.red, green: hex.green, blue: hex.blue, alpha: hex.alpha)
    }
}

// MARK: - KCMainViewController

class KCMainViewController: UIViewController, KDDrawingCanvasViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIColorPickerViewControllerDelegate {

    var canvasContainerView: UIView!
    var canvasView: KCDrawingCanvasView!
    var sizeSlider: UISlider!
    var lineArtItems: [KCLineArtItem]!
    var colorButtons: [UIButton] = []
    var recentColorButtons: [UIButton] = []
    var toolButtons: [KDToolButton] = []
    var brushButtons: [KDBrushButton] = []
    var historyThumbButtons: [UIButton] = []
    var stickerButtons: [UIButton] = []
    var stickerCategoryButtons: [UIButton] = []
    var activeColorButton: UIButton?
    var palette24Button: UIButton!
    var palette36Button: UIButton!
    var customColorButton: UIButton!
    var paletteGridHeightConstraint: NSLayoutConstraint!
    var recentColorRowStack: UIStackView!
    var deleteHistoryButton: UIButton!
    var previousHistoryButton: UIButton!
    var nextHistoryButton: UIButton!
    var undoButton: UIButton!
    var redoButton: UIButton!
    var saveButton: UIButton!
    var saveToastView: UIView?
    var sizePreviewView: UIView!
    var sizePreviewShapeLayer: CAShapeLayer!
    var draftThumbButton: UIButton!
    var circleEraserButton: UIButton!
    var cloudEraserButton: UIButton!
    var starEraserButton: UIButton!
    var deleteStickerButton: UIButton!
    var frontStickerButton: UIButton!
    var stickerRowStack: UIStackView!
    let sessionStore: KCSessionService
    let contentCatalog: KCBundledContentCatalog
    let drawingEngine: KCDrawingEngineProviding
    /// 内容选择 Feature（色盘 / 最近色 / 贴纸分类），从 contentCatalog 构造，T022 抽出。
    private(set) lazy var contentPicker: KCContentPickerFeature = {
        KCContentPickerFeature(contentCatalog: self.contentCatalog)
    }()
    /// 编辑器面板 Feature（浮动面板收起/展开 + 工具状态芯片色块），T023 抽出。
    private(set) lazy var editorPanels: KCEditorPanelsFeature = KCEditorPanelsFeature()
    /// 历史 Feature（缩略图槽位状态推导 + 删除可用性），T024 抽出。
    private(set) lazy var history: KCHistoryFeature = KCHistoryFeature()
    /// 主画布 Feature（画布创建 + 画布动作状态），T033 抽出最小边界。
    private(set) lazy var canvasFeature: KCCanvasFeature = KCCanvasFeature(drawingEngine: self.drawingEngine)
    /// 线稿 Feature（线稿 item 构造 + 缩略图/画布线稿渲染），T039 抽出。
    private(set) lazy var lineArtFeature: KCLineArtFeature = {
        KCLineArtFeature(contentCatalog: self.contentCatalog, drawingEngine: self.drawingEngine)
    }()
    /// 画笔 Dock Feature（底部画笔项配置），T042 抽出。
    private(set) lazy var brushDockFeature: KCBrushDockFeature = KCBrushDockFeature()
    /// 橡皮擦控件 Feature（尺寸预览 + 形状按钮选中态），T044 抽出。
    private(set) lazy var eraserControlsFeature: KCEraserControlsFeature = KCEraserControlsFeature()
    /// 左侧工具栏 Feature（工具项配置 + 选中态），T046 抽出。
    private(set) lazy var toolRailFeature: KCToolRailFeature = KCToolRailFeature()
    /// 通用按压反馈控制器，T048 抽出。
    private(set) lazy var pressFeedbackController: KCPressFeedbackController = KCPressFeedbackController()
    /// 保存反馈 Toast 展示器，T048 抽出。
    private(set) lazy var toastPresenter: KCToastPresenter = {
        let presenter = KCToastPresenter()
        presenter.dismissalHandler = { [weak self] toast in
            if self?.saveToastView === toast {
                self?.saveToastView = nil
            }
        }
        return presenter
    }()
    /// 颜色面板 UIKit 渲染器，T049 抽出。
    private(set) lazy var colorPaletteRenderer: KCColorPalettePanelRenderer = KCColorPalettePanelRenderer()
    /// 画笔、贴纸、橡皮与贴纸编辑面板组装器，T050 抽出。
    private(set) lazy var brushStickerPanelView: KCBrushStickerPanelView = KCBrushStickerPanelView()
    var sessions: [KCSessionMetadata] = []
    var activeSession: KCSessionMetadata?
    var selectedHistorySession: KCSessionMetadata?
    var collapsiblePanels: [UIView] = []
    var collapseToggleButton: UIButton!
    var toolStateChip: UIView!
    var toolStateSwatch: UIView!
    var toolStateLabel: UILabel!
    var historyPageIndex: Int = 0
    var draftSaveTimer: Timer?
    var suppressNextDraftSave: Bool = false
    var activeSessionHasUnsavedChanges: Bool = false
    var brushWidthsByStyle: [Int: CGFloat] = [:]
    var eraserSliderValue: CGFloat = 0.0

    // MARK: - 设备布局指标

    private var layoutMetrics: KCDeviceLayoutMetrics {
        KCDeviceLayoutMetrics(userInterfaceIdiom: UIDevice.current.userInterfaceIdiom)
    }

    private var editorUIFactory: KCEditorUIFactory {
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

    func bottomDockTitleWidth() -> CGFloat {
        return self.layoutMetrics.bottomDockTitleWidth
    }

    func bottomDockTitleFontSize() -> CGFloat {
        return self.layoutMetrics.bottomDockTitleFontSize
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

    // MARK: - 视图生命周期

    /// 通过 Composition Root 注入依赖创建。避免控制器内部直接 `KCSessionService.shared`。
    /// 内容目录（色盘 / 贴纸 / 线稿元数据）也由 Composition Root 注入，控制器不再硬编码。
    init(
        sessionService: KCSessionService,
        contentCatalog: KCBundledContentCatalog,
        drawingEngine: KCDrawingEngineProviding
    ) {
        self.sessionStore = sessionService
        self.contentCatalog = contentCatalog
        self.drawingEngine = drawingEngine
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable, message: "Use init(sessionService:contentCatalog:drawingEngine:) via KCAppCompositionRoot")
    required init?(coder: NSCoder) {
        fatalError("Use init(sessionService:contentCatalog:drawingEngine:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor(red: 0.97, green: 0.94, blue: 0.89, alpha: 1.0)
        // 内容选择 Feature 在构造时从 contentCatalog 建好色盘与贴纸分组；这里载入最近色。
        self.contentPicker.loadRecentColors()
        self.lineArtItems = self.lineArtFeature.makeLineArtItems()
        self.colorButtons = []
        self.recentColorButtons = []
        self.toolButtons = []
        self.brushButtons = []
        self.historyThumbButtons = []
        self.stickerButtons = []
        self.stickerCategoryButtons = []
        self.sessions = self.sessionStore.loadAllSessions()
        self.loadBrushWidthPreferences()

        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillResignActiveNotification(_:)), name: UIScene.willDeactivateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidEnterBackgroundNotification(_:)), name: UIScene.didEnterBackgroundNotification, object: nil)

        self.buildInterface()
        self.updatePaletteButtons()
        self.reloadPaletteGrid()
        self.reloadStickerButtons()
        self.selectToolMode(.brush)
        self.selectBrushStyle(.pencil)
        self.selectColor(self.contentPicker.palette24.first!, sender: nil)
        self.selectStickerSymbol(self.currentStickerSymbols().first!)
        self.refreshEraserShapeButtons()
        self.refreshStickerEditButtons()
        self.refreshHistoryUI()
        self.restoreDraftIfNeeded()
        self.refreshActionButtons()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.refreshSizePreview()
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    // MARK: - 界面构建

    func buildInterface() {
        let canvasContainer = UIView()
        canvasContainer.translatesAutoresizingMaskIntoConstraints = false
        canvasContainer.backgroundColor = UIColor.white
        self.view.addSubview(canvasContainer)
        self.canvasContainerView = canvasContainer

        self.canvasView = self.canvasFeature.makeCanvasView(delegate: self)
        canvasContainer.addSubview(self.canvasView)
        self.installCanvasGesturesOnView(self.canvasView)

        let topLeft = self.floatingPanel()
        let topRight = self.floatingPanel()
        let leftRail = self.floatingPanel()
        let colorsPanel = self.floatingPanel()
        let sizePanel = self.floatingPanel()
        let historyPanel = self.floatingPanel()
        let bottomDock = self.floatingPanel()
        let rightScrollView = UIScrollView()
        let rightStack = UIStackView()

        topLeft.translatesAutoresizingMaskIntoConstraints = false
        topRight.translatesAutoresizingMaskIntoConstraints = false
        leftRail.translatesAutoresizingMaskIntoConstraints = false
        bottomDock.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.translatesAutoresizingMaskIntoConstraints = false
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.showsVerticalScrollIndicator = false
        rightScrollView.alwaysBounceVertical = true
        rightScrollView.clipsToBounds = true
        rightStack.axis = .vertical
        rightStack.spacing = self.rightPanelStackSpacing()

        self.view.addSubview(topLeft)
        self.view.addSubview(topRight)
        self.view.addSubview(leftRail)
        self.view.addSubview(rightScrollView)
        rightScrollView.addSubview(rightStack)
        rightStack.addArrangedSubview(colorsPanel)
        rightStack.addArrangedSubview(sizePanel)
        rightStack.addArrangedSubview(historyPanel)
        self.view.addSubview(bottomDock)

        // 收起按钮一起隐藏的 5 组浮动面板，用于在小屏上释放画布空间。
        //（colorsPanel/sizePanel/historyPanel 都在 rightScrollView 内，
        // 所以隐藏它即可一并覆盖这三者。）
        self.collapsiblePanels = [topLeft, topRight, leftRail, rightScrollView, bottomDock]

        NSLayoutConstraint.activate([
            canvasContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            canvasContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            canvasContainer.topAnchor.constraint(equalTo: self.view.topAnchor),
            canvasContainer.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.canvasView.leadingAnchor.constraint(equalTo: canvasContainer.leadingAnchor),
            self.canvasView.trailingAnchor.constraint(equalTo: canvasContainer.trailingAnchor),
            self.canvasView.topAnchor.constraint(equalTo: canvasContainer.topAnchor),
            self.canvasView.bottomAnchor.constraint(equalTo: canvasContainer.bottomAnchor),

            topLeft.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 34.0),
            topLeft.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 30.0),

            topRight.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -34.0),
            topRight.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 30.0),

            leftRail.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 38.0),
            leftRail.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 170.0),
            leftRail.widthAnchor.constraint(equalToConstant: 80.0),
            leftRail.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.46),

            rightScrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: self.rightPanelTrailingOffset()),
            rightScrollView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: self.rightPanelTopOffset()),
            rightScrollView.bottomAnchor.constraint(equalTo: bottomDock.topAnchor, constant: self.rightPanelBottomGap()),
            rightScrollView.widthAnchor.constraint(equalToConstant: self.rightPanelOuterWidth()),

            rightStack.leadingAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.leadingAnchor, constant: 12.0),
            rightStack.trailingAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.trailingAnchor, constant: -12.0),
            rightStack.topAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.topAnchor, constant: 12.0),
            rightStack.bottomAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.bottomAnchor, constant: -12.0),
            rightStack.widthAnchor.constraint(equalTo: rightScrollView.frameLayoutGuide.widthAnchor, constant: -24.0),

            colorsPanel.widthAnchor.constraint(equalToConstant: self.rightPanelWidth()),
            sizePanel.widthAnchor.constraint(equalToConstant: self.rightPanelWidth()),
            historyPanel.widthAnchor.constraint(equalToConstant: self.rightPanelWidth()),

            bottomDock.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            bottomDock.widthAnchor.constraint(equalToConstant: self.bottomDockWidth()),
            bottomDock.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: self.bottomDockBottomInset()),
            bottomDock.heightAnchor.constraint(equalToConstant: self.bottomDockHeight())
        ])

        self.buildTopLeftPanel(topLeft)
        self.buildTopRightPanel(topRight)
        self.buildLeftRail(leftRail)
        self.buildColorsPanel(colorsPanel)
        self.buildSizePanel(sizePanel)
        self.buildHistoryPanel(historyPanel)
        self.buildBottomDock(bottomDock)
        self.buildCollapseControls()
    }

    // MARK: - 工具栏收起（小屏画布空间）

    /// 构建常驻可见的收起按钮（右下角，位于主绘画区之外），以及仅在浮动面板
    /// 收起时显示的最小当前工具芯片。iPhone 与 iPad 默认都展开；该按钮可让
    /// 用户隐藏全部浮动面板以释放画布空间——在 iPhone 横屏下最有用。
    func buildCollapseControls() {
        let toggle = UIButton(type: .system)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.tintColor = UIColor(red: 0.19, green: 0.26, blue: 0.33, alpha: 1.0)
        toggle.backgroundColor = UIColor(white: 1.0, alpha: 0.82)
        toggle.layer.cornerRadius = 22.0
        toggle.layer.borderWidth = 1.0
        toggle.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        toggle.layer.shadowColor = UIColor(red: 0.47, green: 0.40, blue: 0.29, alpha: 1.0).cgColor
        toggle.layer.shadowOpacity = 0.16
        toggle.layer.shadowRadius = 10.0
        toggle.layer.shadowOffset = CGSize(width: 0, height: 6)
        toggle.setImage(UIImage(systemName: "rectangle.compress.vertical"), for: .normal)
        toggle.accessibilityLabel = KCL10n.hideToolsTitle
        toggle.addTarget(self, action: #selector(togglePanelsCollapsed(_:)), for: .touchUpInside)
        self.view.addSubview(toggle)
        self.collapseToggleButton = toggle

        let chip = UIView()
        chip.translatesAutoresizingMaskIntoConstraints = false
        chip.backgroundColor = UIColor(white: 1.0, alpha: 0.82)
        chip.layer.cornerRadius = 18.0
        chip.layer.borderWidth = 1.0
        chip.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        chip.layer.shadowColor = UIColor(red: 0.47, green: 0.40, blue: 0.29, alpha: 1.0).cgColor
        chip.layer.shadowOpacity = 0.12
        chip.layer.shadowRadius = 8.0
        chip.layer.shadowOffset = CGSize(width: 0, height: 4)
        chip.isHidden = true
        chip.alpha = 0.0
        self.view.addSubview(chip)
        self.toolStateChip = chip

        let swatch = UIView()
        swatch.translatesAutoresizingMaskIntoConstraints = false
        swatch.layer.cornerRadius = 9.0
        swatch.layer.borderWidth = 1.0
        swatch.layer.borderColor = UIColor(white: 1.0, alpha: 0.8).cgColor
        chip.addSubview(swatch)
        self.toolStateSwatch = swatch

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = UIColor(red: 0.19, green: 0.26, blue: 0.33, alpha: 1.0)
        chip.addSubview(label)
        self.toolStateLabel = label

        NSLayoutConstraint.activate([
            toggle.widthAnchor.constraint(equalToConstant: 44.0),
            toggle.heightAnchor.constraint(equalToConstant: 44.0),
            toggle.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20.0),
            toggle.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -28.0),

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

        self.collapseToggleButton.setImage(UIImage(systemName: state.toggleIconName), for: .normal)
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

    func floatingPanel() -> UIView {
        return self.editorUIFactory.floatingPanel()
    }

    func iconButtonWithSymbolName(_ symbolName: String, accentColor: UIColor?) -> UIButton {
        let button = self.editorUIFactory.iconButton(symbolName: symbolName, accentColor: accentColor)
        self.registerPressFeedbackForControl(button)
        return button
    }

    func installCanvasGesturesOnView(_ view: UIView) {
        let twoFingerUndo = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerUndoTap(_:)))
        twoFingerUndo.numberOfTouchesRequired = 2
        twoFingerUndo.numberOfTapsRequired = 1

        let twoFingerRedo = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerRedoTap(_:)))
        twoFingerRedo.numberOfTouchesRequired = 2
        twoFingerRedo.numberOfTapsRequired = 2

        twoFingerUndo.require(toFail: twoFingerRedo)
        view.addGestureRecognizer(twoFingerUndo)
        view.addGestureRecognizer(twoFingerRedo)
    }

    func historyThumbButton() -> UIButton {
        let button = self.editorUIFactory.historyThumbButton()
        self.registerPressFeedbackForControl(button)
        return button
    }

    func railToolButtonWithSymbolName(_ symbolName: String, slim: Bool) -> KDToolButton {
        let button = self.editorUIFactory.railToolButton(symbolName: symbolName, slim: slim)
        self.registerPressFeedbackForControl(button)
        return button
    }

    func buildTopLeftPanel(_ panel: UIView) {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 10.0
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12.0),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12.0),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12.0),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12.0)
        ])

        let brandButton = self.iconButtonWithSymbolName("paintpalette.fill", accentColor: UIColor(red: 0.96, green: 0.85, blue: 0.48, alpha: 1.0))
        let newButton = self.iconButtonWithSymbolName("plus", accentColor: nil)
        self.undoButton = self.iconButtonWithSymbolName("arrow.uturn.backward", accentColor: nil)
        self.redoButton = self.iconButtonWithSymbolName("arrow.uturn.forward", accentColor: nil)
        self.applyAccessibilityLabel("Palette", identifier: "top.palette", toControl: brandButton)
        self.applyAccessibilityLabel("New Canvas", identifier: "top.new-canvas", toControl: newButton)
        self.applyAccessibilityLabel("Undo", identifier: "top.undo", toControl: self.undoButton)
        self.applyAccessibilityLabel("Redo", identifier: "top.redo", toControl: self.redoButton)

        newButton.addTarget(self, action: #selector(didTapNewCanvas), for: .touchUpInside)
        self.undoButton.addTarget(self, action: #selector(didTapUndo), for: .touchUpInside)
        self.redoButton.addTarget(self, action: #selector(didTapRedo), for: .touchUpInside)

        stack.addArrangedSubview(brandButton)
        stack.addArrangedSubview(newButton)
        stack.addArrangedSubview(self.undoButton)
        stack.addArrangedSubview(self.redoButton)
    }

    func buildTopRightPanel(_ panel: UIView) {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 10.0
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12.0),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12.0),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12.0),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12.0)
        ])

        let historyButton = self.iconButtonWithSymbolName("clock.arrow.circlepath", accentColor: nil)
        let lineArtButton = self.iconButtonWithSymbolName("square.on.circle", accentColor: nil)
        let importButton = self.iconButtonWithSymbolName("photo.on.rectangle", accentColor: nil)
        self.saveButton = self.iconButtonWithSymbolName("square.and.arrow.down.fill", accentColor: UIColor(red: 0.54, green: 0.80, blue: 0.98, alpha: 1.0))
        self.applyAccessibilityLabel(KCL10n.openLatestTitle, identifier: "top.open-latest", toControl: historyButton)
        self.applyAccessibilityLabel(KCL10n.lineArtTitle, identifier: "top.line-art", toControl: lineArtButton)
        self.applyAccessibilityLabel(KCL10n.importPhotoTitle, identifier: "top.import-photo", toControl: importButton)
        self.applyAccessibilityLabel(KCL10n.saveTitle, identifier: "top.save", toControl: self.saveButton)

        historyButton.addTarget(self, action: #selector(didTapOpenLatestSession), for: .touchUpInside)
        lineArtButton.addTarget(self, action: #selector(didTapLineArtPicker), for: .touchUpInside)
        importButton.addTarget(self, action: #selector(didTapImportImage), for: .touchUpInside)
        self.saveButton.addTarget(self, action: #selector(didTapSaveSession), for: .touchUpInside)

        stack.addArrangedSubview(historyButton)
        stack.addArrangedSubview(lineArtButton)
        stack.addArrangedSubview(importButton)
        stack.addArrangedSubview(self.saveButton)
    }

    func buildLeftRail(_ panel: UIView) {
        let toolScrollView = UIScrollView()
        toolScrollView.translatesAutoresizingMaskIntoConstraints = false
        toolScrollView.showsVerticalScrollIndicator = false
        toolScrollView.alwaysBounceVertical = true
        toolScrollView.clipsToBounds = true
        panel.addSubview(toolScrollView)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 10.0
        toolScrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            toolScrollView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12.0),
            toolScrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12.0),
            toolScrollView.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12.0),
            toolScrollView.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12.0),

            stack.leadingAnchor.constraint(equalTo: toolScrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: toolScrollView.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: toolScrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: toolScrollView.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: toolScrollView.frameLayoutGuide.widthAnchor)
        ])

        let items = self.toolRailFeature.toolItems()

        for item in items {
            let slim = self.toolRailFeature.accentColor(for: item.mode) != nil
            let button = self.railToolButtonWithSymbolName(item.symbolName, slim: slim)
            button.toolMode = item.mode
            self.applyAccessibilityLabel(item.title, identifier: "tool.\(item.id)", toControl: button)
            button.addTarget(self, action: #selector(didTapToolButton(_:)), for: .touchUpInside)

            self.toolButtons.append(button)
            stack.addArrangedSubview(button)
        }
    }

    func buildColorsPanel(_ panel: UIView) {
        let renderedPanel = self.colorPaletteRenderer.renderPanel(
            in: panel,
            configuration: KCColorPalettePanelRenderer.Configuration(
                title: KCL10n.colorsPanelTitle,
                palette24Title: KCL10n.palette24Title,
                palette36Title: KCL10n.palette36Title,
                customColorTitle: KCL10n.customColorTitle,
                customColorAccessibility: KCL10n.customColorAccessibility,
                isCompactPhoneLayout: self.isCompactPhoneLayout,
                innerInset: self.rightPanelInnerInset(),
                paletteGridWidth: self.paletteGridWidth(),
                paletteGridInitialHeight: self.paletteGridHeightForColorCount(self.contentPicker.palette24.count),
                paletteColorButtonSize: self.paletteColorButtonSize(),
                paletteColorButtonSpacing: self.paletteColorButtonSpacing()
            ),
            makeTitleLabel: { [weak self] title in
                self?.panelTitleLabel(title) ?? UILabel()
            },
            makeSegmentButton: { [weak self] title, active in
                self?.segmentButtonWithTitle(title, active: active) ?? UIButton(type: .system)
            },
            target: self,
            palette24Action: #selector(didTapPalette24),
            palette36Action: #selector(didTapPalette36),
            customColorAction: #selector(didTapCustomColor),
            registerPressFeedback: { [weak self] control in
                self?.registerPressFeedbackForControl(control)
            }
        )
        self.palette24Button = renderedPanel.palette24Button
        self.palette36Button = renderedPanel.palette36Button
        self.customColorButton = renderedPanel.customColorButton
        self.paletteGridHeightConstraint = renderedPanel.paletteGridHeightConstraint
        self.recentColorRowStack = renderedPanel.recentColorRowStack
        self.reloadRecentColorRow()
    }

    func buildSizePanel(_ panel: UIView) {
        let renderedPanel = self.brushStickerPanelView.renderPanel(
            in: panel,
            texts: KCBrushStickerPanelView.Texts(
                brushStickerTitle: KCL10n.brushStickerPanelTitle,
                sizeSliderAccessibility: KCL10n.sizeSliderAccessibility,
                stickersTitle: KCL10n.stickersPanelTitle,
                eraserTitle: KCL10n.eraserPanelTitle,
                stickerEditTitle: KCL10n.stickerEditPanelTitle,
                circleEraserTitle: KCL10n.circleEraserTitle,
                cloudEraserTitle: KCL10n.cloudEraserTitle,
                starEraserTitle: KCL10n.starEraserTitle,
                bringStickerForwardTitle: KCL10n.bringStickerForwardTitle,
                deleteStickerTitle: KCL10n.deleteStickerTitle
            ),
            stickerCategories: self.contentPicker.stickerCategories,
            target: self,
            makeTitleLabel: { [weak self] title in
                self?.panelTitleLabel(title) ?? UILabel()
            },
            makeSmallToolButton: { [weak self] symbolName, accent in
                self?.smallToolButtonWithSymbolName(symbolName, accent: accent) ?? UIButton(type: .system)
            },
            categorySymbolProvider: { [weak self] category in
                self?.stickerCategorySymbolForCategory(category) ?? "star.fill"
            },
            imageProvider: { [weak self] symbolName in
                self?.safeSystemImageNamed(symbolName) ?? UIImage(systemName: "star.fill")!
            },
            stickerCategoryAccessibilityProvider: { category in
                KCL10n.stickerCategoryAccessibility(category)
            },
            registerPressFeedback: { [weak self] control in
                self?.registerPressFeedbackForControl(control)
            },
            sizeSliderAction: #selector(didChangeSizeSlider(_:)),
            stickerCategoryAction: #selector(didTapStickerCategoryButton(_:)),
            circleEraserAction: #selector(didTapCircleEraser),
            cloudEraserAction: #selector(didTapCloudEraser),
            starEraserAction: #selector(didTapStarEraser),
            bringStickerForwardAction: #selector(didTapBringStickerFront),
            deleteStickerAction: #selector(didTapDeleteSticker)
        )
        self.sizeSlider = renderedPanel.sizeSlider
        self.sizePreviewView = renderedPanel.sizePreviewView
        self.sizePreviewShapeLayer = renderedPanel.sizePreviewShapeLayer
        self.stickerCategoryButtons = renderedPanel.stickerCategoryButtons
        self.stickerRowStack = renderedPanel.stickerRowStack
        self.circleEraserButton = renderedPanel.circleEraserButton
        self.cloudEraserButton = renderedPanel.cloudEraserButton
        self.starEraserButton = renderedPanel.starEraserButton
        self.frontStickerButton = renderedPanel.frontStickerButton
        self.deleteStickerButton = renderedPanel.deleteStickerButton
    }

    func buildHistoryPanel(_ panel: UIView) {
        let titleLabel = self.panelTitleLabel(KCL10n.historyPanelTitle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)

        let draftLabel = UILabel()
        draftLabel.translatesAutoresizingMaskIntoConstraints = false
        draftLabel.text = KCL10n.draftTitle
        draftLabel.font = UIFont.systemFont(ofSize: 12.0, weight: .semibold)
        draftLabel.textColor = UIColor(red: 0.47, green: 0.52, blue: 0.58, alpha: 1.0)
        panel.addSubview(draftLabel)

        self.draftThumbButton = self.historyThumbButton()
        self.applyAccessibilityLabel(KCL10n.draftThumbAccessibility, identifier: "history.draft", toControl: self.draftThumbButton)
        self.draftThumbButton.addTarget(self, action: #selector(didTapDraftThumb), for: .touchUpInside)
        panel.addSubview(self.draftThumbButton)

        let savedLabel = UILabel()
        savedLabel.translatesAutoresizingMaskIntoConstraints = false
        savedLabel.text = KCL10n.savedTitle
        savedLabel.font = UIFont.systemFont(ofSize: 12.0, weight: .semibold)
        savedLabel.textColor = UIColor(red: 0.47, green: 0.52, blue: 0.58, alpha: 1.0)
        panel.addSubview(savedLabel)

        for index in 0..<4 {
            let thumb = self.historyThumbButton()
            thumb.tag = index
            self.applyAccessibilityLabel(KCL10n.savedThumbAccessibility(index + 1), identifier: "history.saved.\(index + 1)", toControl: thumb)
            thumb.addTarget(self, action: #selector(didTapHistoryThumb(_:)), for: .touchUpInside)
            panel.addSubview(thumb)
            self.historyThumbButtons.append(thumb)
        }

        self.previousHistoryButton = self.smallToolButtonWithSymbolName("chevron.left", accent: false)
        self.nextHistoryButton = self.smallToolButtonWithSymbolName("chevron.right", accent: false)
        self.applyAccessibilityLabel(KCL10n.previousHistoryPageTitle, identifier: "history.previous-page", toControl: self.previousHistoryButton)
        self.applyAccessibilityLabel(KCL10n.nextHistoryPageTitle, identifier: "history.next-page", toControl: self.nextHistoryButton)
        self.previousHistoryButton.translatesAutoresizingMaskIntoConstraints = false
        self.nextHistoryButton.translatesAutoresizingMaskIntoConstraints = false
        self.previousHistoryButton.addTarget(self, action: #selector(didTapPreviousHistoryPage), for: .touchUpInside)
        self.nextHistoryButton.addTarget(self, action: #selector(didTapNextHistoryPage), for: .touchUpInside)
        panel.addSubview(self.previousHistoryButton)
        panel.addSubview(self.nextHistoryButton)

        let openButton = self.historyActionButtonWithTitle(KCL10n.openLatestHistoryTitle, accent: false)
        let importButton = self.historyActionButtonWithTitle(KCL10n.importPhotoHistoryTitle, accent: true)
        self.deleteHistoryButton = self.historyActionButtonWithTitle(KCL10n.deleteLatestHistoryTitle, accent: false)
        self.applyAccessibilityLabel(KCL10n.openLatestHistoryTitle, identifier: "history.open-latest", toControl: openButton)
        self.applyAccessibilityLabel(KCL10n.importPhotoHistoryTitle, identifier: "history.import-photo", toControl: importButton)
        self.applyAccessibilityLabel(KCL10n.deleteLatestHistoryTitle, identifier: "history.delete-latest", toControl: self.deleteHistoryButton)
        openButton.translatesAutoresizingMaskIntoConstraints = false
        importButton.translatesAutoresizingMaskIntoConstraints = false
        self.deleteHistoryButton.translatesAutoresizingMaskIntoConstraints = false

        openButton.addTarget(self, action: #selector(didTapOpenLatestSession), for: .touchUpInside)
        importButton.addTarget(self, action: #selector(didTapImportImage), for: .touchUpInside)
        self.deleteHistoryButton.addTarget(self, action: #selector(didTapDeleteLatestSession), for: .touchUpInside)

        panel.addSubview(openButton)
        panel.addSubview(importButton)
        panel.addSubview(self.deleteHistoryButton)

        let thumbOne = self.historyThumbButtons[0]
        let thumbTwo = self.historyThumbButtons[1]
        let thumbThree = self.historyThumbButtons[2]
        let thumbFour = self.historyThumbButtons[3]
        let inset = self.rightPanelInnerInset()
        let thumbSize = self.historyThumbSize()
        let actionButtonHeight: CGFloat = self.isCompactPhoneLayout ? 34.0 : 38.0
        let pageButtonWidth: CGFloat = self.isCompactPhoneLayout ? 42.0 : 46.0
        let openButtonWidth: CGFloat = self.isCompactPhoneLayout ? 60.0 : 68.0
        let importButtonWidth: CGFloat = self.isCompactPhoneLayout ? 70.0 : 78.0
        let deleteButtonWidth: CGFloat = self.isCompactPhoneLayout ? 70.0 : 78.0

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: inset),

            draftLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            draftLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12.0),

            self.draftThumbButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            self.draftThumbButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -inset),
            self.draftThumbButton.topAnchor.constraint(equalTo: draftLabel.bottomAnchor, constant: 8.0),
            self.draftThumbButton.heightAnchor.constraint(equalToConstant: self.historyDraftThumbHeight()),

            savedLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            savedLabel.topAnchor.constraint(equalTo: self.draftThumbButton.bottomAnchor, constant: 12.0),

            thumbOne.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            thumbOne.topAnchor.constraint(equalTo: savedLabel.bottomAnchor, constant: 8.0),
            thumbOne.widthAnchor.constraint(equalToConstant: thumbSize),
            thumbOne.heightAnchor.constraint(equalToConstant: thumbSize),

            thumbTwo.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -inset),
            thumbTwo.topAnchor.constraint(equalTo: savedLabel.bottomAnchor, constant: 8.0),
            thumbTwo.widthAnchor.constraint(equalToConstant: thumbSize),
            thumbTwo.heightAnchor.constraint(equalToConstant: thumbSize),

            thumbThree.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            thumbThree.topAnchor.constraint(equalTo: thumbOne.bottomAnchor, constant: 10.0),
            thumbThree.widthAnchor.constraint(equalToConstant: thumbSize),
            thumbThree.heightAnchor.constraint(equalToConstant: thumbSize),

            thumbFour.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -inset),
            thumbFour.topAnchor.constraint(equalTo: thumbTwo.bottomAnchor, constant: 10.0),
            thumbFour.widthAnchor.constraint(equalToConstant: thumbSize),
            thumbFour.heightAnchor.constraint(equalToConstant: thumbSize),

            self.previousHistoryButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            self.previousHistoryButton.topAnchor.constraint(equalTo: thumbThree.bottomAnchor, constant: 12.0),
            self.previousHistoryButton.widthAnchor.constraint(equalToConstant: pageButtonWidth),

            self.nextHistoryButton.leadingAnchor.constraint(equalTo: self.previousHistoryButton.trailingAnchor, constant: 8.0),
            self.nextHistoryButton.topAnchor.constraint(equalTo: thumbThree.bottomAnchor, constant: 12.0),
            self.nextHistoryButton.widthAnchor.constraint(equalToConstant: pageButtonWidth),

            openButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            openButton.topAnchor.constraint(equalTo: self.previousHistoryButton.bottomAnchor, constant: 10.0),
            openButton.widthAnchor.constraint(equalToConstant: openButtonWidth),
            openButton.heightAnchor.constraint(equalToConstant: actionButtonHeight),

            importButton.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 8.0),
            importButton.topAnchor.constraint(equalTo: self.previousHistoryButton.bottomAnchor, constant: 10.0),
            importButton.widthAnchor.constraint(equalToConstant: importButtonWidth),
            importButton.heightAnchor.constraint(equalToConstant: actionButtonHeight),

            self.deleteHistoryButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -inset),
            self.deleteHistoryButton.topAnchor.constraint(equalTo: importButton.bottomAnchor, constant: 8.0),
            self.deleteHistoryButton.widthAnchor.constraint(equalToConstant: deleteButtonWidth),
            self.deleteHistoryButton.heightAnchor.constraint(equalToConstant: actionButtonHeight),
            self.deleteHistoryButton.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -inset)
        ])
    }

    func buildBottomDock(_ panel: UIView) {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = KCL10n.brushesPanelTitle
        label.font = UIFont.systemFont(ofSize: self.bottomDockTitleFontSize(), weight: .semibold)
        label.textColor = UIColor(red: 0.34, green: 0.39, blue: 0.45, alpha: 1.0)
        panel.addSubview(label)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = true
        panel.addSubview(scrollView)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = self.bottomDockStackSpacing()
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: self.bottomDockHorizontalInset()),
            label.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: self.bottomDockTitleWidth()),

            scrollView.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8.0),
            scrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -self.bottomDockHorizontalInset()),
            scrollView.topAnchor.constraint(equalTo: panel.topAnchor, constant: self.bottomDockVerticalInset()),
            scrollView.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -self.bottomDockVerticalInset()),

            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let brushItems = self.brushDockFeature.brushItems()

        for (index, item) in brushItems.enumerated() {
            let button = self.toolCardButtonWithSymbolName(item.symbolName, accentColor: item.accentColor, title: item.title)
            button.brushStyle = item.style
            button.toolMode = item.mode
            button.representsBrushStyle = item.representsBrushStyle
            button.tag = index
            self.applyAccessibilityLabel(item.title, identifier: "dock.\(item.id)", toControl: button)
            button.addTarget(self, action: #selector(didTapBrushButton(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            self.brushButtons.append(button)
        }
    }

    func addCanvasBadges() {
        let leftBadge = self.badgeLabelWithText(KCL10n.canvasBadge)
        let rightBadge = self.badgeLabelWithText(KCL10n.lineArtBadge)
        leftBadge.translatesAutoresizingMaskIntoConstraints = false
        rightBadge.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(leftBadge)
        self.view.addSubview(rightBadge)

        NSLayoutConstraint.activate([
            leftBadge.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 214.0),
            leftBadge.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 94.0),
            leftBadge.heightAnchor.constraint(equalToConstant: 40.0),

            rightBadge.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -322.0),
            rightBadge.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 94.0),
            rightBadge.heightAnchor.constraint(equalToConstant: 40.0)
        ])
    }

    func badgeLabelWithText(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        label.textColor = UIColor(red: 0.49, green: 0.53, blue: 0.59, alpha: 1.0)
        label.backgroundColor = UIColor(white: 1.0, alpha: 0.92)
        label.layer.cornerRadius = 18.0
        label.clipsToBounds = true
        label.layer.borderWidth = 1.0
        label.layer.borderColor = UIColor(white: 1.0, alpha: 0.7).cgColor
        return label
    }

    func panelTitleLabel(_ title: String) -> UILabel {
        return self.editorUIFactory.panelTitleLabel(title)
    }

    func segmentButtonWithTitle(_ title: String, active: Bool) -> UIButton {
        let button = self.editorUIFactory.segmentButton(title: title, active: active)
        self.registerPressFeedbackForControl(button)
        return button
    }

    func historyActionButtonWithTitle(_ title: String, accent: Bool) -> UIButton {
        let button = self.editorUIFactory.historyActionButton(title: title, accent: accent)
        self.registerPressFeedbackForControl(button)
        return button
    }

    func smallToolButtonWithSymbolName(_ symbolName: String, accent: Bool) -> UIButton {
        let button = self.editorUIFactory.smallToolButton(symbolName: symbolName, accent: accent)
        self.registerPressFeedbackForControl(button)
        return button
    }

    func applyAccessibilityLabel(_ label: String, identifier: String, toControl control: UIControl) {
        control.accessibilityLabel = label
        control.accessibilityIdentifier = identifier
    }

    func safeSystemImageNamed(_ symbolName: String) -> UIImage {
        let image = UIImage(systemName: symbolName)
        return image ?? UIImage(systemName: "star.fill")!
    }

    func stickerAccessibilityLabelForSymbol(_ symbol: String) -> String {
        return KCL10n.stickerSymbolAccessibility(self.contentPicker.accessibilityLabel(forSymbol: symbol))
    }

    func stickerCategorySymbolForCategory(_ category: String) -> String {
        return self.contentPicker.categorySymbol(forCategory: category)
    }

    func toolCardButtonWithSymbolName(_ symbolName: String, accentColor: UIColor, title: String) -> KDBrushButton {
        let button = self.editorUIFactory.toolCardButton(symbolName: symbolName, accentColor: accentColor, title: title)
        self.registerPressFeedbackForControl(button)
        return button
    }

    // MARK: - 调色板（颜色取自 contentCatalog，见 viewDidLoad）

    func currentPalette() -> [UIColor] {
        return self.contentPicker.currentPalette
    }

    func paletteGridColumns() -> Int {
        return self.contentPicker.paletteGridColumns
    }

    func paletteColorButtonSize() -> CGFloat {
        return self.isCompactPhoneLayout ? 26.0 : self.contentPicker.paletteColorButtonSize
    }

    func paletteColorButtonSpacing() -> CGFloat {
        return self.isCompactPhoneLayout ? 6.0 : self.contentPicker.paletteColorButtonSpacing
    }

    func paletteGridWidth() -> CGFloat {
        let columns = self.paletteGridColumns()
        let buttonSize = self.paletteColorButtonSize()
        let spacing = self.paletteColorButtonSpacing()
        return CGFloat(columns) * buttonSize + CGFloat(columns - 1) * spacing
    }

    func paletteGridHeightForColorCount(_ colorCount: Int) -> CGFloat {
        let rows = Int(ceil(Double(colorCount) / Double(self.paletteGridColumns())))
        let buttonSize = self.paletteColorButtonSize()
        let spacing = self.paletteColorButtonSpacing()
        return CGFloat(rows) * buttonSize + CGFloat(max(0, rows - 1)) * spacing
    }

    func reloadPaletteGrid() {
        let grid = self.view.viewWithTag(701)!
        let palette = self.currentPalette()
        let result = self.colorPaletteRenderer.reloadPaletteGrid(
            in: grid,
            palette: palette,
            columns: self.paletteGridColumns(),
            buttonSize: self.paletteColorButtonSize(),
            spacing: self.paletteColorButtonSpacing(),
            gridHeightConstraint: self.paletteGridHeightConstraint,
            gridHeight: self.paletteGridHeightForColorCount(palette.count),
            target: self,
            action: #selector(didTapColorButton(_:)),
            registerPressFeedback: { [weak self] control in
                self?.registerPressFeedbackForControl(control)
            },
            accessibilityLabelProvider: { index in
                KCL10n.paletteColorTitle(index + 1)
            }
        )
        self.colorButtons = result.buttons

        self.selectColor(self.canvasView.currentColor, sender: nil)
    }

    func reloadRecentColorRow() {
        let recentRow: UIView? = self.recentColorRowStack ?? self.view.viewWithTag(702)
        guard let recentStack = recentRow as? UIStackView else {
            return
        }

        let result = self.colorPaletteRenderer.reloadRecentColorRow(
            in: recentStack,
            recentColors: self.contentPicker.recentColors,
            buttonSize: self.paletteColorButtonSize(),
            target: self,
            action: #selector(didTapRecentColorButton(_:)),
            registerPressFeedback: { [weak self] control in
                self?.registerPressFeedbackForControl(control)
            },
            accessibilityLabelProvider: { index in
                KCL10n.recentColorAccessibility(index + 1)
            }
        )
        self.recentColorButtons = result.buttons
    }

    func currentStickerSymbols() -> [String] {
        return self.contentPicker.currentStickerSymbols()
    }

    func reloadStickerButtons() {
        self.stickerButtons = self.brushStickerPanelView.reloadStickerButtons(
            in: self.stickerRowStack,
            symbols: self.currentStickerSymbols(),
            target: self,
            action: #selector(didTapStickerButton(_:)),
            imageProvider: { [weak self] symbolName in
                self?.safeSystemImageNamed(symbolName) ?? UIImage(systemName: "star.fill")!
            },
            accessibilityLabelProvider: { [weak self] symbol in
                self?.stickerAccessibilityLabelForSymbol(symbol) ?? symbol
            },
            registerPressFeedback: { [weak self] control in
                self?.registerPressFeedbackForControl(control)
            }
        )

        self.refreshStickerCategoryButtons()
        let selectedSymbol = self.canvasFeature.resolvedStickerSymbol(
            currentSymbol: self.canvasView.currentStickerSymbol,
            availableSymbols: self.currentStickerSymbols()
        )
        self.selectStickerSymbol(selectedSymbol)
    }

    func refreshStickerCategoryButtons() {
        self.brushStickerPanelView.applyStickerCategorySelection(
            to: self.stickerCategoryButtons,
            selectedCategory: self.contentPicker.selectedStickerCategory,
            categoryResolver: { [weak self] button in
                self?.stickerCategoryFromButton(button)
            }
        )
    }

    func stickerCategoryFromButton(_ button: UIButton) -> String? {
        return self.contentPicker.category(forButtonIdentifier: button.accessibilityIdentifier ?? "")
    }

    func addRecentColor(_ color: UIColor?) {
        self.contentPicker.addRecentColor(color)
        self.reloadRecentColorRow()
    }

    func loadBrushWidthPreferences() {
        self.brushWidthsByStyle = [
            KDBrushStyle.pencil.rawValue: 12.0,
            KDBrushStyle.pen.rawValue: 9.0,
            KDBrushStyle.crayon.rawValue: 18.0
        ]
        self.eraserSliderValue = 18.0

        if let storedWidths = UserDefaults.standard.dictionary(forKey: "KDBrushWidthsByStyle") {
            if let pencil = storedWidths["pencil"] as? Double {
                self.brushWidthsByStyle[KDBrushStyle.pencil.rawValue] = self.clampedBrushWidth(CGFloat(pencil))
            }
            if let pen = storedWidths["pen"] as? Double {
                self.brushWidthsByStyle[KDBrushStyle.pen.rawValue] = self.clampedBrushWidth(CGFloat(pen))
            }
            if let crayon = storedWidths["crayon"] as? Double {
                self.brushWidthsByStyle[KDBrushStyle.crayon.rawValue] = self.clampedBrushWidth(CGFloat(crayon))
            }
            if let eraser = storedWidths["eraser"] as? Double {
                self.eraserSliderValue = self.clampedBrushWidth(CGFloat(eraser))
            }
        }
    }

    func persistBrushWidthPreferences() {
        let storedWidths: [String: Any] = [
            "pencil": self.brushWidthsByStyle[KDBrushStyle.pencil.rawValue] ?? 12.0,
            "pen": self.brushWidthsByStyle[KDBrushStyle.pen.rawValue] ?? 9.0,
            "crayon": self.brushWidthsByStyle[KDBrushStyle.crayon.rawValue] ?? 18.0,
            "eraser": self.eraserSliderValue
        ]
        UserDefaults.standard.set(storedWidths, forKey: "KDBrushWidthsByStyle")
    }

    func clampedBrushWidth(_ width: CGFloat) -> CGFloat {
        return min(36.0, max(4.0, width))
    }

    func updatePaletteButtons() {
        self.colorPaletteRenderer.updateSegmentButtons(
            palette24Button: self.palette24Button,
            palette36Button: self.palette36Button,
            showing36Palette: self.contentPicker.showing36Palette
        )
    }

    // MARK: - 历史

    func refreshHistoryUI() {
        self.sessions = self.sessionStore.loadAllSessions()
        let maxPageIndex = self.maxHistoryPageIndex()
        self.historyPageIndex = self.drawingEngine.historyClampedPageIndex(
            self.historyPageIndex,
            sessionCount: self.sessions.count,
            pageSize: self.historyPageSize()
        )
        self.previousHistoryButton.isEnabled = self.historyPageIndex > 0
        self.nextHistoryButton.isEnabled = self.historyPageIndex < maxPageIndex
        self.previousHistoryButton.alpha = self.previousHistoryButton.isEnabled ? 1.0 : 0.45
        self.nextHistoryButton.alpha = self.nextHistoryButton.isEnabled ? 1.0 : 0.45

        let draftImage = self.sessionStore.loadDraftImage()
        let selectedSession = self.currentSelectedHistorySession()
        let canDeleteHistoryItem = self.history.canDeleteHistory(
            hasSelectedSession: selectedSession != nil,
            sessionCount: self.sessions.count,
            hasDraft: draftImage != nil
        )
        self.deleteHistoryButton.isEnabled = canDeleteHistoryItem
        self.deleteHistoryButton.alpha = canDeleteHistoryItem ? 1.0 : 0.55

        self.draftThumbButton.setBackgroundImage(draftImage, for: .normal)
        self.draftThumbButton.imageView?.isHidden = draftImage != nil
        self.draftThumbButton.isEnabled = draftImage != nil
        self.draftThumbButton.alpha = draftImage != nil ? 1.0 : 0.55
        self.draftThumbButton.accessibilityLabel = draftImage != nil ? "Draft Thumbnail" : "No Draft Thumbnail"
        self.draftThumbButton.layer.borderColor = (draftImage != nil && self.activeSession == nil
            ? UIColor(red: 0.97, green: 0.82, blue: 0.46, alpha: 0.92)
            : UIColor(red: 0.17, green: 0.22, blue: 0.30, alpha: 0.08)).cgColor
        self.draftThumbButton.transform = (draftImage != nil && self.activeSession == nil)
            ? CGAffineTransform(scaleX: 1.02, y: 1.02)
            : .identity
        if draftImage == nil {
            self.draftThumbButton.imageView?.isHidden = false
            self.draftThumbButton.backgroundColor = UIColor(red: 1.0, green: 0.995, blue: 0.98, alpha: 1.0)
        }

        // 历史缩略图槽位状态推导（分页 + 选中/当前/脏态判定）由历史 Feature（KCDomain）给出，
        // 控制器只负责把状态映射到 UIKit 边框色/缩放/无障碍标签。
        let sessionIds = self.sessions.map(\.identifier)
        let activeSessionId = self.activeSession?.identifier
        let selectedSessionId = selectedSession?.identifier
        for index in 0..<self.historyThumbButtons.count {
            let button = self.historyThumbButtons[index]
            let thumbResult = self.history.thumbStatus(
                sessionIds: sessionIds,
                pageIndex: self.historyPageIndex,
                pageSize: self.historyPageSize(),
                activeSessionId: activeSessionId,
                selectedSessionId: selectedSessionId,
                isDirtyActive: self.activeSessionHasUnsavedChanges,
                thumbIndex: index
            )
            let status = thumbResult.status
            let sessionIndex = thumbResult.sessionIndex
            button.layer.borderColor = self.history.borderColor(for: status).cgColor
            button.layer.borderWidth = status.borderWidth
            if status == .empty {
                button.setBackgroundImage(nil, for: .normal)
                button.imageView?.isHidden = false
                button.isEnabled = false
                button.accessibilityLabel = "\(KCL10n.historyThumbPrefix(status.accessibilityPrefix)) \(index + 1)"
                button.backgroundColor = UIColor(red: 1.0, green: 0.995, blue: 0.98, alpha: 1.0)
                button.transform = .identity
            } else {
                let session = self.sessions[sessionIndex]
                let image = self.sessionStore.thumbnailImage(forSessionId: session.identifier)
                button.setBackgroundImage(image, for: .normal)
                button.imageView?.isHidden = image != nil
                button.isEnabled = true
                button.accessibilityLabel = "\(KCL10n.historyThumbPrefix(status.accessibilityPrefix)) \(sessionIndex + 1)"
                button.transform = status.isEmphasized
                    ? CGAffineTransform(scaleX: status.emphasisScale, y: status.emphasisScale)
                    : .identity
            }
        }
    }

    func historyPageSize() -> Int {
        return self.historyThumbButtons.count
    }

    func maxHistoryPageIndex() -> Int {
        // 历史分页计算在 Swift KCHistoryPaging Feature 模型中。
        return self.drawingEngine.historyMaxPageIndex(sessionCount: self.sessions.count,
                                                         pageSize: self.historyPageSize())
    }

    func sessionIndexForHistoryThumbIndex(_ thumbIndex: Int) -> Int {
        // 历史分页计算在 Swift KCHistoryPaging Feature 模型中。
        return self.drawingEngine.historySessionIndex(
            thumbIndex: thumbIndex,
            pageIndex: self.historyPageIndex,
            pageSize: self.historyPageSize()
        )
    }

    func currentSelectedHistorySession() -> KCSessionMetadata? {
        if (self.selectedHistorySession?.identifier ?? "").isEmpty {
            return nil
        }

        for session in self.sessions {
            if session.identifier == self.selectedHistorySession?.identifier {
                return session
            }
        }

        self.selectedHistorySession = nil
        return nil
    }

    // MARK: - 工具 / 画笔 / 颜色选择

    func selectToolMode(_ mode: KDToolMode) {
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
        for button in self.stickerButtons {
            let active = button.accessibilityIdentifier == resolved
            button.layer.borderWidth = active ? 2.0 : 1.0
            button.layer.borderColor = (active
                ? UIColor(red: 0.45, green: 0.73, blue: 0.97, alpha: 0.55)
                : UIColor(white: 1.0, alpha: 0.72)).cgColor
            button.backgroundColor = active
                ? UIColor(red: 0.86, green: 0.94, blue: 1.0, alpha: 0.94)
                : UIColor(white: 1.0, alpha: 0.76)
            button.transform = active ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
        }
    }

    // MARK: - 按钮动作

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
        self.present(picker, animated: true, completion: nil)
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        self.canvasView.currentColor = viewController.selectedColor
        self.selectColor(viewController.selectedColor, sender: nil)
        self.addRecentColor(viewController.selectedColor)
    }

    @objc func didTapNewCanvas() {
        let alert = UIAlertController(title: KCL10n.clearCanvasAlertTitle, message: KCL10n.clearCanvasAlertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: KCL10n.cancelTitle, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: KCL10n.clearTitle, style: .destructive, handler: { [weak self] (_: UIAlertAction) in
            guard let self = self else { return }
            self.activeSession = nil
            self.selectedHistorySession = nil
            self.activeSessionHasUnsavedChanges = false
            self.draftSaveTimer?.invalidate()
            self.draftSaveTimer = nil
            self.suppressNextDraftSave = true
            self.canvasView.startBlankCanvas()
            self.sessionStore.clearDraft()
            self.refreshHistoryUI()
            self.refreshActionButtons()
        }))
        self.present(alert, animated: true, completion: nil)
    }

    @objc func didTapUndo() {
        self.canvasView.undoLastAction()
        self.refreshActionButtons()
    }

    @objc func didTapRedo() {
        self.canvasView.redoLastAction()
        self.refreshActionButtons()
    }

    @objc func handleTwoFingerUndoTap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .recognized {
            self.didTapUndo()
        }
    }

    @objc func handleTwoFingerRedoTap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .recognized {
            self.didTapRedo()
        }
    }

    @objc func didTapImportImage() {
        if !UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            self.showSaveToastWithSuccess(false)
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        let popover = picker.popoverPresentationController
        popover?.sourceView = self.view
        popover?.sourceRect = CGRect(x: self.view.bounds.maxX - 110.0, y: 88.0, width: 1.0, height: 1.0)
        popover?.permittedArrowDirections = .up
        self.present(picker, animated: true, completion: nil)
    }

    @objc func didTapSaveSession() {
        if !self.canvasFeature.hasVisibleContent(self.canvasView) {
            self.showSaveToastWithSuccess(false)
            return
        }

        let snapshot = self.canvasView.snapshotImage()
        guard let savedSession = self.sessionStore.saveImage(snapshot, existingSessionId: self.activeSession?.identifier) else {
            self.showSaveToastWithSuccess(false)
            return
        }

        self.activeSession = savedSession
        self.selectedHistorySession = savedSession
        self.activeSessionHasUnsavedChanges = false
        self.draftSaveTimer?.invalidate()
        self.draftSaveTimer = nil
        self.sessionStore.clearDraft()
        self.historyPageIndex = 0
        self.refreshHistoryUI()
        self.refreshActionButtons()
        UIImageWriteToSavedPhotosAlbum(snapshot, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?) {
        self.showSaveToastWithSuccess(error == nil)
    }

    @objc func didTapOpenLatestSession() {
        if self.sessions.count == 0 {
            return
        }
        self.openSession(self.sessions.first!)
    }

    @objc func didTapDeleteLatestSession() {
        let draftImage = self.sessionStore.loadDraftImage()
        let selectedSession = self.currentSelectedHistorySession()
        let shouldDeleteDraft = selectedSession == nil && self.activeSession == nil && draftImage != nil
        if self.sessions.count == 0 && !shouldDeleteDraft {
            return
        }

        let session = shouldDeleteDraft ? nil : (selectedSession ?? (self.activeSession ?? self.sessions.first))
        let title = KCL10n.deleteAlertTitle(isDraft: shouldDeleteDraft)
        let message = KCL10n.deleteAlertMessage(isDraft: shouldDeleteDraft)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: KCL10n.cancelTitle, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: KCL10n.deleteTitle, style: .destructive, handler: { [weak self] (_: UIAlertAction) in
            guard let self = self else { return }
            if shouldDeleteDraft {
                self.draftSaveTimer?.invalidate()
                self.draftSaveTimer = nil
                self.sessionStore.clearDraft()
                if self.activeSession == nil {
                    self.suppressNextDraftSave = true
                    self.canvasView.startBlankCanvas()
                    self.sessionStore.clearDraft()
                }
            } else {
                let deletingActiveSession = self.activeSession?.identifier == session?.identifier
                self.sessionStore.deleteSession(withId: session!.identifier)
                if deletingActiveSession {
                    self.activeSession = nil
                    self.selectedHistorySession = nil
                    self.activeSessionHasUnsavedChanges = false
                    self.draftSaveTimer?.invalidate()
                    self.draftSaveTimer = nil
                    self.suppressNextDraftSave = true
                    self.canvasView.startBlankCanvas()
                    self.sessionStore.clearDraft()
                }
                if self.selectedHistorySession?.identifier == session?.identifier {
                    self.selectedHistorySession = nil
                }
            }
            if shouldDeleteDraft {
                self.activeSession = nil
                self.selectedHistorySession = nil
                self.activeSessionHasUnsavedChanges = false
            }
            self.refreshHistoryUI()
            self.refreshActionButtons()
        }))
        self.present(alert, animated: true, completion: nil)
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

    @objc func didTapLineArtPicker() {
        let picker = KCLineArtPickerViewController(
            items: self.lineArtItems,
            lineArtFeature: self.lineArtFeature,
            registerPressFeedback: { [weak self] control in
                self?.registerPressFeedbackForControl(control)
            },
            selectionHandler: { [weak self] item in
                guard let self = self else { return }
                self.dismiss(animated: true) {
                    self.loadLineArtItem(item)
                }
            }
        )

        let popover = picker.popoverPresentationController
        popover?.sourceView = self.view
        popover?.sourceRect = CGRect(x: self.view.bounds.midX, y: 104.0, width: 1.0, height: 1.0)
        popover?.permittedArrowDirections = .up
        self.present(picker, animated: true, completion: nil)
    }

    func loadLineArtItem(_ item: KCLineArtItem) {
        var canvasSize = self.canvasView.bounds.size
        if canvasSize == .zero {
            canvasSize = CGSize(width: 1024.0, height: 720.0)
        }
        let lineArt = self.lineArtFeature.lineArtImage(for: item, canvasSize: canvasSize)

        let preservedDraft = self.preserveUnsavedActiveSessionDraftIfNeeded()
        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.draftSaveTimer?.invalidate()
        self.draftSaveTimer = nil
        if !preservedDraft {
            self.sessionStore.clearDraft()
        }
        self.canvasView.loadLineArtImage(lineArt)
        self.selectToolMode(.fill)
        self.refreshHistoryUI()
        self.refreshActionButtons()
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

    @objc func didTapHistoryThumb(_ button: UIButton) {
        let index = self.sessionIndexForHistoryThumbIndex(button.tag)
        if index < self.sessions.count {
            let session = self.sessions[index]
            self.selectedHistorySession = session
            self.openSession(session)
        }
    }

    @objc func didTapPreviousHistoryPage() {
        if self.historyPageIndex == 0 {
            return
        }
        self.historyPageIndex -= 1
        self.refreshHistoryUI()
    }

    @objc func didTapNextHistoryPage() {
        if self.historyPageIndex >= self.maxHistoryPageIndex() {
            return
        }
        self.historyPageIndex += 1
        self.refreshHistoryUI()
    }

    @objc func didTapDraftThumb() {
        let draftImage = self.sessionStore.loadDraftImage()
        guard let draftImage = draftImage else {
            return
        }

        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.canvasView.restoreCanvas(with: draftImage)
        self.refreshHistoryUI()
        self.refreshActionButtons()
    }

    @objc func didChangeSizeSlider(_ slider: UISlider) {
        let width = self.clampedBrushWidth(CGFloat(slider.value))
        slider.value = Float(width)
        self.canvasView.currentLineWidth = width
        if self.canvasView.currentToolMode == .brush {
            self.brushWidthsByStyle[self.canvasView.currentBrushStyle.rawValue] = width
        } else if self.canvasView.currentToolMode == .eraser {
            self.eraserSliderValue = width
        }
        self.persistBrushWidthPreferences()
        self.refreshSizePreview()
    }

    func openSession(_ session: KCSessionMetadata) {
        guard let image = self.sessionStore.artworkImage(forSessionId: session.identifier) else {
            return
        }
        let preservedDraft = self.preserveUnsavedActiveSessionDraftIfNeeded()
        self.activeSession = session
        self.selectedHistorySession = session
        self.activeSessionHasUnsavedChanges = false
        self.draftSaveTimer?.invalidate()
        self.draftSaveTimer = nil
        self.suppressNextDraftSave = true
        self.canvasView.restoreCanvas(with: image)
        if !preservedDraft {
            self.sessionStore.clearDraft()
        }
        self.updateHistoryPageForActiveSession()
        self.refreshHistoryUI()
        self.refreshActionButtons()
    }

    func preserveUnsavedActiveSessionDraftIfNeeded() -> Bool {
        if self.activeSession == nil || !self.activeSessionHasUnsavedChanges || !self.canvasFeature.hasVisibleContent(self.canvasView) {
            return false
        }

        self.draftSaveTimer?.invalidate()
        self.draftSaveTimer = nil
        let snapshot = self.canvasView.snapshotImage()
        _ = self.sessionStore.saveDraftImage(snapshot)
        return true
    }

    func updateHistoryPageForActiveSession() {
        if (self.activeSession?.identifier ?? "").isEmpty {
            return
        }

        if let index = self.sessions.firstIndex(where: { $0.identifier == self.activeSession?.identifier }) {
            self.historyPageIndex = index / max(1, self.historyPageSize())
        }
    }

    // MARK: - 画布代理

    func drawingCanvasView(_ canvasView: KCDrawingCanvasView, didPickColor color: UIColor) {
        self.canvasView.currentColor = color
        self.selectColor(color, sender: nil)
        self.addRecentColor(color)
    }

    func drawingCanvasViewSelectionDidChange(_ canvasView: KCDrawingCanvasView) {
        self.refreshStickerEditButtons()
    }

    func drawingCanvasViewContentDidChange(_ canvasView: KCDrawingCanvasView) {
        self.refreshActionButtons()
        if self.suppressNextDraftSave {
            self.suppressNextDraftSave = false
            return
        }
        if self.activeSession != nil {
            self.activeSessionHasUnsavedChanges = true
        }
        self.scheduleDraftSave()
    }

    // MARK: - 图片选择器

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.originalImage] as? UIImage
        let normalizedImage = self.normalizedImageFromImage(image)
        if let normalizedImage = normalizedImage {
            let preservedDraft = self.preserveUnsavedActiveSessionDraftIfNeeded()
            self.activeSession = nil
            self.selectedHistorySession = nil
            self.activeSessionHasUnsavedChanges = false
            self.draftSaveTimer?.invalidate()
            self.draftSaveTimer = nil
            if !preservedDraft {
                self.sessionStore.clearDraft()
            }
            self.canvasView.replaceCanvas(with: normalizedImage)
            self.refreshHistoryUI()
            self.refreshActionButtons()
        } else {
            self.showSaveToastWithSuccess(false)
        }
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        self.canvasView.currentColor = viewController.selectedColor
        self.selectColor(viewController.selectedColor, sender: nil)
    }

    func normalizedImageFromImage(_ image: UIImage?) -> UIImage? {
        guard let image = image, image.size.width > 0.0, image.size.height > 0.0 else {
            return nil
        }

        let maxDimension: CGFloat = 2400.0
        let imageSize = image.size
        let scale = min(1.0, maxDimension / max(imageSize.width, imageSize.height))
        let needsResize = scale < 1.0

        if image.imageOrientation == .up && !needsResize {
            return image
        }

        let targetSize = needsResize ? CGSize(width: imageSize.width * scale, height: imageSize.height * scale) : imageSize
        if targetSize.width <= 0.0 || targetSize.height <= 0.0 {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { (_: UIGraphicsImageRendererContext) in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    // MARK: - 刷新辅助方法

    func refreshEraserShapeButtons() {
        let buttonShapes: [(button: UIButton, shape: KDEraserShape)] = [
            (self.circleEraserButton, .circle),
            (self.cloudEraserButton, .cloud),
            (self.starEraserButton, .star)
        ]
        for item in buttonShapes {
            let active = self.eraserControlsFeature.isShape(item.shape, activeFor: self.canvasView.currentEraserShape)
            self.eraserControlsFeature.applyShapeButtonAppearance(to: item.button, active: active)
        }
        self.refreshSizePreview()
    }

    func refreshStickerEditButtons() {
        let enabled = self.canvasView.hasSelectedSticker()
        self.brushStickerPanelView.applyStickerEditButtonsEnabled(
            frontButton: self.frontStickerButton,
            deleteButton: self.deleteStickerButton,
            enabled: enabled
        )
    }

    func refreshActionButtons() {
        let actionState = self.canvasFeature.actionState(for: self.canvasView)
        self.canvasFeature.applyActionButtonAppearance(
            state: actionState,
            undoButton: self.undoButton,
            redoButton: self.redoButton,
            saveButton: self.saveButton
        )
    }

    // MARK: - 按压反馈

    func registerPressFeedbackForControl(_ control: UIControl) {
        self.pressFeedbackController.register(control)
    }

    // MARK: - 保存提示

    func showSaveToastWithSuccess(_ success: Bool) {
        self.toastPresenter.dismiss(self.saveToastView)
        self.saveToastView = self.toastPresenter.showSaveToast(success: success, in: self.view, anchorView: self.saveButton)
    }

    // MARK: - 草稿自动保存

    func restoreDraftIfNeeded() {
        if self.activeSession != nil {
            return
        }

        guard let draftImage = self.sessionStore.loadDraftImage() else {
            return
        }

        self.canvasView.restoreCanvas(with: draftImage)
        self.refreshHistoryUI()
        self.refreshActionButtons()
    }

    func scheduleDraftSave() {
        self.draftSaveTimer?.invalidate()
        self.draftSaveTimer = Timer.scheduledTimer(timeInterval: 1.2, target: self, selector: #selector(handleDraftSaveTimer(_:)), userInfo: nil, repeats: false)
    }

    @objc func handleDraftSaveTimer(_ timer: Timer) {
        if timer !== self.draftSaveTimer {
            return
        }
        self.saveDraftIfNeeded()
    }

    func saveDraftIfNeeded() {
        self.draftSaveTimer?.invalidate()
        self.draftSaveTimer = nil

        if self.activeSession != nil && !self.activeSessionHasUnsavedChanges {
            self.refreshHistoryUI()
            return
        }

        if !self.canvasFeature.hasVisibleContent(self.canvasView) {
            self.sessionStore.clearDraft()
            self.refreshHistoryUI()
            return
        }

        let snapshot = self.canvasView.snapshotImage()
        _ = self.sessionStore.saveDraftImage(snapshot)
        self.refreshHistoryUI()
    }

    @objc func sceneWillResignActiveNotification(_ notification: Notification) {
        self.saveDraftIfNeeded()
    }

    @objc func sceneDidEnterBackgroundNotification(_ notification: Notification) {
        self.saveDraftIfNeeded()
    }

    deinit {
        self.draftSaveTimer?.invalidate()
        self.toastPresenter.dismiss(self.saveToastView)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 颜色匹配

    func color(_ lhs: UIColor?, matchesColor rhs: UIColor?) -> Bool {
        return KCContentPickerFeature.colorsMatch(lhs, rhs)
    }
}
