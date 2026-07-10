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
import KCDrawingEngine

enum KCStartupDeferredDelay {
    static let restoreDraft: TimeInterval = 0.30
    static let colorControls: TimeInterval = 0.50
    static let historySessions: TimeInterval = 0.80
    static let stickerButtons: TimeInterval = 1.10
}

// MARK: - KCMainViewController

class KCMainViewController: UIViewController, KDDrawingCanvasViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIColorPickerViewControllerDelegate, UIScrollViewDelegate {

    var canvasContainerView: UIView!
    var canvasView: KCDrawingCanvasView!
    var sizeSlider: UISlider!
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
    var paletteGridView: UIView!
    var paletteGridHeightConstraint: NSLayoutConstraint!
    var recentColorRowStack: UIStackView!
    var deleteHistoryButton: UIButton!
    var previousHistoryButton: UIButton!
    var nextHistoryButton: UIButton!
    var undoButton: UIButton!
    var redoButton: UIButton!
    var saveButton: UIButton!
    var saveToastView: UIView?
    var rightPanelScrollView: UIScrollView!
    var rightPanelFadeMaskLayer: CAGradientLayer!
#if DEBUG
    var runtimeAcceptanceLastSaveToastTitle: String?
    var runtimeAcceptanceLastPhotoExportToastTitle: String?
#endif
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
    let photoLibraryService: KCPhotoLibraryServicing
    /// T099：我的线稿本地服务（保存/读取/删除，独立于历史作品）。
    let customLineArtService: KCCustomLineArtService
    /// T100：图片导入策略服务（相册/相机可用性与权限决策）。
    let imageImportService: KCImageImportServicing
    /// T100：顶栏右导入按钮（动作表 popover 锚点）。
    var importButton: UIButton!
    /// T101：离线线稿生成器（CoreImage pipeline）。
    private(set) lazy var lineArtExtractor: KCLineArtExtracting = KCLineArtExtractor()
    /// T101：当前图片导入意图（作为画布底图 / 生成线稿）。
    var pendingImageImportIntent: KCImageImportIntent = .asCanvas
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
    /// 内容库 Feature（面板可见性 + 分区切换决策），T098 抽出。
    private(set) lazy var contentLibrary: KCContentLibraryFeature = KCContentLibraryFeature()
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
    var draftThumbImageIdentity: String?
    var historyThumbImageIdentities: [String?] = []
    var historyThumbSessionIdentifiers: [String?] = []
    private var cachedLineArtItems: [KCLineArtItem]?
    var historySessionRefreshGeneration: Int = 0
    var historyThumbnailRefreshGeneration: Int = 0
    var collapsiblePanels: [UIView] = []
    var collapseToggleButton: UIButton!
    /// T097：画布“恢复视图”按钮，仅在画布偏离默认视图时显示。
    var restoreViewportButton: UIButton!
    /// T098：顶栏右“内容库”入口按钮，按需展开内容库浮层。
    var contentLibraryButton: UIButton!
    /// T098：内容库浮层面板（按需显示）。
    var contentLibraryPanelView: KCContentLibraryPanelView?
    /// T098：内嵌在内容库“官方线稿”分区的线稿选择控制器。
    var contentLibraryLineArtPicker: KCLineArtPickerViewController?
    /// T099：内容库“我的线稿”分区网格视图。
    var myLineArtGridView: KCMyLineArtGridView?
    /// T098/T102：迁入内容库历史分区的历史面板视图引用（用于空态切换）。
    var historyPanelView: UIView!
    var toolStateChip: UIView!
    var toolStateSwatch: UIView!
    var toolStateLabel: UILabel!
    var historyPageIndex: Int = 0
    var draftSaveTimer: Timer?
    let sessionPersistenceQueue = DispatchQueue(label: "com.kidcanvas.editor.session-persistence", qos: .userInitiated)
    private let artworkLoadingQueue = DispatchQueue(label: "com.kidcanvas.editor.artwork-loading", qos: .userInitiated)
    let imageImportProcessingQueue = DispatchQueue(label: "com.kidcanvas.editor.image-import-processing", qos: .userInitiated)
    let draftPersistenceQueue = DispatchQueue(label: "com.kidcanvas.editor.draft-persistence", qos: .utility)
    private let lineArtRenderingQueue = DispatchQueue(label: "com.kidcanvas.editor.line-art-rendering", qos: .userInitiated)
    let draftGenerationLock = NSLock()
    static let historyThumbnailImageStates: [UIControl.State] = [
        .normal,
        .highlighted,
        .selected,
        .disabled,
        .focused,
        .highlighted.union(.selected),
        .highlighted.union(.focused),
        .selected.union(.focused),
        .disabled.union(.selected),
        .disabled.union(.highlighted),
        .disabled.union(.focused),
        .highlighted.union(.selected).union(.focused)
    ]
    static let historyPlaceholderViewTag = 2_026_070_801
    let sessionSaveGenerationLock = NSLock()
    var sessionSaveGeneration: Int = 0
    var artworkLoadGeneration: Int = 0
    var imageImportGeneration: Int = 0
    var draftSaveGeneration: Int = 0
    var draftProtectionGeneration: Int = 0
    private var lineArtLoadGeneration: Int = 0
    private var appliedCanvasActionState: KCCanvasFeature.ActionState?
    var didScheduleStartupDeferredWork = false
    private var didLoadPaletteGrid = false
    private var didLoadRecentColors = false
    private var didLoadStickerButtons = false
    var activeDraftMatchesCanvas: Bool = false
    private var brushWidthPreferenceSaveTimer: Timer?
    var suppressNextDraftSave: Bool = false
    var activeSessionHasUnsavedChanges: Bool = false
    var brushWidthsByStyle: [Int: CGFloat] = [:]
    var eraserSliderValue: CGFloat = 0.0
    var transientToolModeMemory = KCTransientToolModeMemory()
#if DEBUG
    var runtimeAcceptanceProbeDidRun = false
    var runtimeAcceptanceImageImportCompletion: (() -> Void)?
#endif

    // MARK: - 视图生命周期

    /// 通过 Composition Root 注入依赖创建。避免控制器内部直接 `KCSessionService.shared`。
    /// 内容目录（色盘 / 贴纸 / 线稿元数据）也由 Composition Root 注入，控制器不再硬编码。
    init(
        sessionService: KCSessionService,
        contentCatalog: KCBundledContentCatalog,
        drawingEngine: KCDrawingEngineProviding,
        photoLibraryService: KCPhotoLibraryServicing,
        customLineArtService: KCCustomLineArtService,
        imageImportService: KCImageImportServicing
    ) {
        self.sessionStore = sessionService
        self.contentCatalog = contentCatalog
        self.drawingEngine = drawingEngine
        self.photoLibraryService = photoLibraryService
        self.customLineArtService = customLineArtService
        self.imageImportService = imageImportService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable, message: "Use init(sessionService:contentCatalog:drawingEngine:photoLibraryService:customLineArtService:imageImportService:) via KCAppCompositionRoot")
    required init?(coder: NSCoder) {
        fatalError("Use init(sessionService:contentCatalog:drawingEngine:photoLibraryService:customLineArtService:imageImportService:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor(red: 0.97, green: 0.94, blue: 0.89, alpha: 1.0)
        // 最近色、色盘按钮网格、历史读盘都延后到首帧后，降低启动同步工作。
        self.colorButtons = []
        self.recentColorButtons = []
        self.toolButtons = []
        self.brushButtons = []
        self.historyThumbButtons = []
        self.stickerButtons = []
        self.stickerCategoryButtons = []
        self.loadBrushWidthPreferences()

        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillResignActiveNotification(_:)), name: UIScene.willDeactivateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidEnterBackgroundNotification(_:)), name: UIScene.didEnterBackgroundNotification, object: nil)

        self.buildInterface()
        self.updatePaletteButtons()
        self.selectToolMode(.brush)
        self.selectColor(self.contentPicker.palette24.first!, sender: nil)
        self.selectStickerSymbol(self.currentStickerSymbols().first!)
        self.refreshEraserShapeButtons()
        self.refreshStickerCategoryButtons()
        self.refreshStickerEditButtons()
        self.refreshHistoryUI(loadDraftThumbnail: false, preloadThumbnails: false, loadSessions: false, checkDraftExistence: false)
        self.refreshActionButtons()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.refreshSizePreview()
        self.updateRightPanelFadeMask()
        // 把面板感知的“安全创作区”注入画布 viewport，使默认视图按创作区居中、
        // 缩放/平移按创作区边界钳制。每次布局（含面板收起/展开）都重新计算。
        self.canvasView.applyViewportRect(self.canvasCreationRect())
        self.refreshRestoreViewportButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.scheduleStartupDeferredWorkIfNeeded()
#if DEBUG
        self.runRuntimeAcceptanceProbeIfNeeded()
#endif
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    // MARK: - 界面构建

    func buildInterface() {
        let canvasContainer = UIView()
        canvasContainer.translatesAutoresizingMaskIntoConstraints = false
        // 工作台底色与画布 view 内部背景保持一致，避免布局切换时露出纯白底。
        canvasContainer.backgroundColor = UIColor(red: 0.935, green: 0.945, blue: 0.925, alpha: 1.0)
        self.view.addSubview(canvasContainer)
        self.canvasContainerView = canvasContainer

        self.canvasView = self.canvasFeature.makeCanvasView(delegate: self)
        canvasContainer.addSubview(self.canvasView)
        self.installCanvasGesturesOnView(self.canvasView)

        let topLeft = self.floatingPanel()
        let topRight = self.floatingPanel()
        let leftRail = self.floatingPanel(cornerRadius: KCEditorVisualStyle.leftRailCornerRadius)
        let colorsPanel = self.floatingPanel()
        let sizePanel = self.floatingPanel()
        let historyPanel = self.floatingPanel()
        let bottomDock = self.floatingPanel(cornerRadius: KCEditorVisualStyle.bottomDockCornerRadius)
        let rightScrollView = UIScrollView()
        let rightStack = UIStackView()
        self.historyPanelView = historyPanel

        topLeft.translatesAutoresizingMaskIntoConstraints = false
        topRight.translatesAutoresizingMaskIntoConstraints = false
        leftRail.translatesAutoresizingMaskIntoConstraints = false
        bottomDock.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.translatesAutoresizingMaskIntoConstraints = false
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.showsVerticalScrollIndicator = false
        rightScrollView.alwaysBounceVertical = true
        rightScrollView.clipsToBounds = true
        rightScrollView.delegate = self
        self.rightPanelScrollView = rightScrollView
        self.installRightPanelFadeMask(on: rightScrollView)
        rightStack.axis = .vertical
        rightStack.spacing = self.rightPanelStackSpacing()

        self.view.addSubview(topLeft)
        self.view.addSubview(topRight)
        self.view.addSubview(leftRail)
        self.view.addSubview(rightScrollView)
        rightScrollView.addSubview(rightStack)
        rightStack.addArrangedSubview(colorsPanel)
        rightStack.addArrangedSubview(sizePanel)
        self.view.addSubview(bottomDock)

        // T097：画布“恢复视图”按钮，仅在画布缩放/平移偏离默认视图时显示。
        // 右下角常驻工具隐藏按钮也在此区域，因此恢复按钮固定上移一格，避免触控重叠。
        self.restoreViewportButton = self.editorUIFactory.restoreViewportButton(symbolName: "arrow.down.right.and.arrow.up.left")
        self.restoreViewportButton.translatesAutoresizingMaskIntoConstraints = false
        self.restoreViewportButton.isHidden = true
        self.applyAccessibilityLabel(KCL10n.restoreViewportTitle, identifier: "canvas.restore-viewport", toControl: self.restoreViewportButton)
        self.restoreViewportButton.addTarget(self, action: #selector(didTapRestoreViewport), for: .touchUpInside)
        self.view.addSubview(self.restoreViewportButton)

        // 收起按钮一起隐藏的 5 组浮动面板，用于在小屏上释放画布空间。
        // 右侧 rightScrollView 现仅承载 colorsPanel/sizePanel（工具参数）；
        // historyPanel 已迁入内容库浮层的“历史作品”分区（T098）。
        self.collapsiblePanels = [topLeft, topRight, leftRail, rightScrollView, bottomDock]
        let safeArea = self.view.safeAreaLayoutGuide

        // T098：内容库浮层（按需显示）。historyPanel 装入其历史分区。
        self.setupContentLibraryPanel(historyPanel: historyPanel)

        NSLayoutConstraint.activate([
            canvasContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            canvasContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            canvasContainer.topAnchor.constraint(equalTo: self.view.topAnchor),
            canvasContainer.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.canvasView.leadingAnchor.constraint(equalTo: canvasContainer.leadingAnchor),
            self.canvasView.trailingAnchor.constraint(equalTo: canvasContainer.trailingAnchor),
            self.canvasView.topAnchor.constraint(equalTo: canvasContainer.topAnchor),
            self.canvasView.bottomAnchor.constraint(equalTo: canvasContainer.bottomAnchor),

            topLeft.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 24.0),
            topLeft.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 24.0),

            topRight.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -24.0),
            topRight.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 24.0),

            leftRail.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 24.0),
            leftRail.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: self.leftRailTopOffset()),
            leftRail.widthAnchor.constraint(equalToConstant: 80.0),
            leftRail.heightAnchor.constraint(equalTo: safeArea.heightAnchor, multiplier: self.leftRailHeightMultiplier()),

            rightScrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: self.rightPanelTrailingOffset()),
            rightScrollView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: self.rightPanelTopOffset()),
            rightScrollView.bottomAnchor.constraint(equalTo: bottomDock.topAnchor, constant: self.rightPanelBottomGap()),
            rightScrollView.widthAnchor.constraint(equalToConstant: self.rightPanelOuterWidth()),

            rightStack.leadingAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.leadingAnchor, constant: 12.0),
            rightStack.trailingAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.trailingAnchor, constant: -12.0),
            rightStack.topAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.topAnchor, constant: 12.0),
            rightStack.bottomAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.bottomAnchor, constant: -12.0),
            rightStack.widthAnchor.constraint(equalTo: rightScrollView.frameLayoutGuide.widthAnchor, constant: -24.0),

            colorsPanel.widthAnchor.constraint(equalToConstant: self.rightPanelWidth()),
            sizePanel.widthAnchor.constraint(equalToConstant: self.rightPanelWidth()),

            bottomDock.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            bottomDock.widthAnchor.constraint(equalToConstant: self.bottomDockWidth()),
            bottomDock.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: self.bottomDockBottomInset()),
            bottomDock.heightAnchor.constraint(equalToConstant: self.bottomDockHeight()),

            self.restoreViewportButton.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -24.0),
            self.restoreViewportButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -88.0),
            self.restoreViewportButton.widthAnchor.constraint(equalToConstant: 52.0),
            self.restoreViewportButton.heightAnchor.constraint(equalToConstant: 52.0)
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

    func floatingPanel(cornerRadius: CGFloat = KCEditorVisualStyle.floatingPanelCornerRadius) -> UIView {
        return self.editorUIFactory.floatingPanel(cornerRadius: cornerRadius)
    }

    func installRightPanelFadeMask(on scrollView: UIScrollView) {
        let maskLayer = CAGradientLayer()
        maskLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor
        ]
        maskLayer.locations = [0.0, 0.025, 0.965, 1.0]
        maskLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        maskLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        scrollView.layer.mask = maskLayer
        self.rightPanelFadeMaskLayer = maskLayer
    }

    func updateRightPanelFadeMask() {
        guard let scrollView = self.rightPanelScrollView,
              let maskLayer = self.rightPanelFadeMaskLayer else {
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = scrollView.bounds
        CATransaction.commit()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === self.rightPanelScrollView {
            self.updateRightPanelFadeMask()
        }
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
        let buttonSize = self.leftRailButtonSize()
        let iconSize = self.leftRailIconPointSize()
        let button = self.editorUIFactory.railToolButton(
            symbolName: symbolName,
            slim: slim,
            size: buttonSize,
            iconPointSize: iconSize
        )
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

        let paletteButton = self.iconButtonWithSymbolName("paintpalette.fill", accentColor: UIColor(red: 0.96, green: 0.85, blue: 0.48, alpha: 1.0))
        let newButton = self.iconButtonWithSymbolName("plus", accentColor: nil)
        self.undoButton = self.iconButtonWithSymbolName("arrow.uturn.backward", accentColor: nil)
        self.redoButton = self.iconButtonWithSymbolName("arrow.uturn.forward", accentColor: nil)
        self.applyAccessibilityLabel(KCL10n.paletteTitle, identifier: "top.palette", toControl: paletteButton)
        self.applyAccessibilityLabel(KCL10n.newCanvasTitle, identifier: "top.new-canvas", toControl: newButton)
        self.applyAccessibilityLabel(KCL10n.undoTitle, identifier: "top.undo", toControl: self.undoButton)
        self.applyAccessibilityLabel(KCL10n.redoTitle, identifier: "top.redo", toControl: self.redoButton)

        newButton.addTarget(self, action: #selector(didTapNewCanvas), for: .touchUpInside)
        self.undoButton.addTarget(self, action: #selector(didTapUndo), for: .touchUpInside)
        self.redoButton.addTarget(self, action: #selector(didTapRedo), for: .touchUpInside)

        stack.addArrangedSubview(paletteButton)
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

        self.contentLibraryButton = self.iconButtonWithSymbolName("books.vertical.fill", accentColor: nil)
        let importButton = self.iconButtonWithSymbolName("photo.on.rectangle", accentColor: nil)
        self.importButton = importButton
        self.saveButton = self.iconButtonWithSymbolName("square.and.arrow.down.fill", accentColor: UIColor(red: 0.54, green: 0.80, blue: 0.98, alpha: 1.0))
        self.applyAccessibilityLabel(KCL10n.contentLibraryTitle, identifier: "top.content-library", toControl: self.contentLibraryButton)
        self.applyAccessibilityLabel(KCL10n.importPhotoTitle, identifier: "top.import-photo", toControl: importButton)
        self.applyAccessibilityLabel(KCL10n.saveTitle, identifier: "top.save", toControl: self.saveButton)

        self.contentLibraryButton.addTarget(self, action: #selector(didTapContentLibrary), for: .touchUpInside)
        importButton.addTarget(self, action: #selector(didTapImportImage), for: .touchUpInside)
        self.saveButton.addTarget(self, action: #selector(didTapSaveSession), for: .touchUpInside)

        stack.addArrangedSubview(self.contentLibraryButton)
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
        stack.alignment = .center
        stack.spacing = self.leftRailStackSpacing()
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
            stack.widthAnchor.constraint(greaterThanOrEqualTo: toolScrollView.frameLayoutGuide.widthAnchor)
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
        self.paletteGridView = renderedPanel.paletteGridView
        self.paletteGridHeightConstraint = renderedPanel.paletteGridHeightConstraint
        self.recentColorRowStack = renderedPanel.recentColorRowStack
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
        self.sizeSlider.addTarget(self, action: #selector(didFinishChangingSizeSlider(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
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
        panel.backgroundColor = .clear
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

        let savedThumbGrid = UIStackView()
        savedThumbGrid.translatesAutoresizingMaskIntoConstraints = false
        savedThumbGrid.axis = .horizontal
        savedThumbGrid.alignment = .center
        savedThumbGrid.distribution = .equalSpacing
        savedThumbGrid.spacing = self.isCompactPhoneLayout ? 10.0 : 14.0
        panel.addSubview(savedThumbGrid)

        for index in 0..<4 {
            let thumb = self.historyThumbButton()
            thumb.tag = index
            self.applyAccessibilityLabel(KCL10n.savedThumbAccessibility(index + 1), identifier: "history.saved.\(index + 1)", toControl: thumb)
            thumb.addTarget(self, action: #selector(didTapHistoryThumb(_:)), for: .touchUpInside)
            savedThumbGrid.addArrangedSubview(thumb)
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
        let pageStack = UIStackView(arrangedSubviews: [self.previousHistoryButton, self.nextHistoryButton])
        pageStack.translatesAutoresizingMaskIntoConstraints = false
        pageStack.axis = .horizontal
        pageStack.alignment = .center
        pageStack.spacing = 8.0
        panel.addSubview(pageStack)

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

        let actionStack = UIStackView(arrangedSubviews: [openButton, importButton, self.deleteHistoryButton])
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.axis = .horizontal
        actionStack.alignment = .center
        actionStack.distribution = .fillEqually
        actionStack.spacing = self.isCompactPhoneLayout ? 8.0 : 12.0
        panel.addSubview(actionStack)

        let inset: CGFloat = self.isCompactPhoneLayout ? 18.0 : 24.0
        let draftWidth: CGFloat = self.isCompactPhoneLayout ? 220.0 : 286.0
        let draftHeight: CGFloat = self.isCompactPhoneLayout ? 136.0 : 176.0
        let thumbSize: CGFloat = self.isCompactPhoneLayout ? 104.0 : 128.0
        let actionButtonHeight: CGFloat = self.isCompactPhoneLayout ? 34.0 : 38.0
        let pageButtonWidth: CGFloat = self.isCompactPhoneLayout ? 42.0 : 46.0

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: inset),

            draftLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            draftLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12.0),

            self.draftThumbButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            self.draftThumbButton.topAnchor.constraint(equalTo: draftLabel.bottomAnchor, constant: 8.0),
            self.draftThumbButton.widthAnchor.constraint(equalToConstant: draftWidth),
            self.draftThumbButton.heightAnchor.constraint(equalToConstant: draftHeight),

            savedLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            savedLabel.topAnchor.constraint(equalTo: self.draftThumbButton.bottomAnchor, constant: 16.0),

            savedThumbGrid.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            savedThumbGrid.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor, constant: -inset),
            savedThumbGrid.topAnchor.constraint(equalTo: savedLabel.bottomAnchor, constant: 10.0),

            self.historyThumbButtons[0].widthAnchor.constraint(equalToConstant: thumbSize),
            self.historyThumbButtons[0].heightAnchor.constraint(equalToConstant: thumbSize),
            self.historyThumbButtons[1].widthAnchor.constraint(equalToConstant: thumbSize),
            self.historyThumbButtons[1].heightAnchor.constraint(equalToConstant: thumbSize),
            self.historyThumbButtons[2].widthAnchor.constraint(equalToConstant: thumbSize),
            self.historyThumbButtons[2].heightAnchor.constraint(equalToConstant: thumbSize),
            self.historyThumbButtons[3].widthAnchor.constraint(equalToConstant: thumbSize),
            self.historyThumbButtons[3].heightAnchor.constraint(equalToConstant: thumbSize),

            pageStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: inset),
            pageStack.topAnchor.constraint(equalTo: savedThumbGrid.bottomAnchor, constant: 14.0),
            self.previousHistoryButton.widthAnchor.constraint(equalToConstant: pageButtonWidth),
            self.nextHistoryButton.widthAnchor.constraint(equalToConstant: pageButtonWidth),

            actionStack.leadingAnchor.constraint(equalTo: pageStack.trailingAnchor, constant: 16.0),
            actionStack.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor, constant: -inset),
            actionStack.centerYAnchor.constraint(equalTo: pageStack.centerYAnchor),

            openButton.heightAnchor.constraint(equalToConstant: actionButtonHeight),
            importButton.heightAnchor.constraint(equalToConstant: actionButtonHeight),
            self.deleteHistoryButton.heightAnchor.constraint(equalToConstant: actionButtonHeight),
            self.deleteHistoryButton.bottomAnchor.constraint(lessThanOrEqualTo: panel.bottomAnchor, constant: -inset)
        ])
    }

    func buildBottomDock(_ panel: UIView) {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = true
        panel.addSubview(scrollView)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = self.bottomDockStackSpacing()
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: self.bottomDockHorizontalInset()),
            scrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -self.bottomDockHorizontalInset()),
            scrollView.topAnchor.constraint(equalTo: panel.topAnchor, constant: self.bottomDockVerticalInset()),
            scrollView.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -self.bottomDockVerticalInset()),

            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)
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
        let image = KCEditorUIFactory.cachedSystemImage(symbolName: symbolName)
        return image ?? KCEditorUIFactory.cachedSystemImage(symbolName: "star.fill")!
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
        return self.isCompactPhoneLayout ? 24.0 : self.contentPicker.paletteColorButtonSize
    }

    func paletteColorButtonSpacing() -> CGFloat {
        return self.isCompactPhoneLayout ? 5.0 : self.contentPicker.paletteColorButtonSpacing
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
        guard let grid = self.paletteGridView else {
            return
        }
        self.didLoadPaletteGrid = true
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
        guard let recentStack = self.recentColorRowStack else {
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

    func loadRecentColorsIfNeeded() {
        guard !self.didLoadRecentColors else { return }
        self.didLoadRecentColors = true
        self.contentPicker.loadRecentColors()
    }

    func loadColorControlsAfterStartupIfNeeded() {
        self.loadRecentColorsIfNeeded()
        self.reloadRecentColorRow()
        guard !self.didLoadPaletteGrid else { return }
        self.reloadPaletteGrid()
    }

    func currentStickerSymbols() -> [String] {
        return self.contentPicker.currentStickerSymbols()
    }

    func reloadStickerButtons() {
        guard let stickerRowStack = self.stickerRowStack else { return }
        self.didLoadStickerButtons = true
        self.stickerButtons = self.brushStickerPanelView.reloadStickerButtons(
            in: stickerRowStack,
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

    func loadStickerButtonsAfterStartupIfNeeded() {
        guard !self.didLoadStickerButtons else { return }
        self.reloadStickerButtons()
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
        self.loadRecentColorsIfNeeded()
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

    func scheduleBrushWidthPreferenceSave() {
        self.brushWidthPreferenceSaveTimer?.invalidate()
        self.brushWidthPreferenceSaveTimer = Timer.scheduledTimer(timeInterval: 0.35, target: self, selector: #selector(handleBrushWidthPreferenceSaveTimer(_:)), userInfo: nil, repeats: false)
    }

    func flushBrushWidthPreferenceSave() {
        guard self.brushWidthPreferenceSaveTimer != nil else {
            return
        }
        self.brushWidthPreferenceSaveTimer?.invalidate()
        self.brushWidthPreferenceSaveTimer = nil
        self.persistBrushWidthPreferences()
    }

    @objc func handleBrushWidthPreferenceSaveTimer(_ timer: Timer) {
        self.flushBrushWidthPreferenceSave()
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

    // MARK: - 按钮动作

    @objc func didTapNewCanvas() {
        let alert = UIAlertController(title: KCL10n.clearCanvasAlertTitle, message: KCL10n.clearCanvasAlertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: KCL10n.cancelTitle, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: KCL10n.clearTitle, style: .destructive, handler: { [weak self] (_: UIAlertAction) in
            guard let self = self else { return }
            self.activeSession = nil
            self.selectedHistorySession = nil
            self.activeSessionHasUnsavedChanges = false
            self.invalidateArtworkLoadWork()
            self.invalidateDraftSaveTimer()
            self.suppressNextDraftSave = true
            self.canvasView.startBlankCanvas()
            self.clearDraftAndInvalidateCurrentDraftMarker()
            self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
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

    @objc func didTapOpenLatestSession() {
        if self.sessions.count == 0 {
            return
        }
        let session = self.sessions.first!
        self.performCanvasReplacementAfterUserConfirmation { [weak self] in
            self?.openSession(session)
        }
    }

    @objc func didTapDeleteLatestSession() {
        let hasDraft = self.sessionStore.hasDraft()
        let selectedSession = self.currentSelectedHistorySession()
        let shouldDeleteDraft = selectedSession == nil && self.activeSession == nil && hasDraft
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
                self.invalidateArtworkLoadWork()
                self.invalidateDraftSaveTimer()
                self.clearDraftAndInvalidateCurrentDraftMarker()
                if self.activeSession == nil {
                    self.suppressNextDraftSave = true
                    self.canvasView.startBlankCanvas()
                    self.clearDraftAndInvalidateCurrentDraftMarker()
                }
            } else {
                guard let session else { return }
                self.deleteSavedHistorySession(session)
                return
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

    func deleteSavedHistorySession(_ session: KCSessionMetadata) {
        let deletingActiveSession = self.activeSession?.identifier == session.identifier
        if deletingActiveSession {
            self.activeSession = nil
            self.selectedHistorySession = nil
            self.activeSessionHasUnsavedChanges = false
            self.invalidateArtworkLoadWork()
            self.invalidateDraftSaveTimer()
            self.suppressNextDraftSave = true
            self.canvasView.startBlankCanvas()
            self.clearDraftAndInvalidateCurrentDraftMarker()
        } else if self.selectedHistorySession?.identifier == session.identifier {
            self.selectedHistorySession = nil
        }

        self.removeLoadedHistorySession(withId: session.identifier)
        self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
        self.refreshActionButtons()

        let sessionId = session.identifier
        self.sessionPersistenceQueue.async { [weak self, sessionId] in
            self?.sessionStore.deleteSession(withId: sessionId)
        }
    }

    // MARK: - 内容库（T098）

    @objc func didTapContentLibrary() {
        self.setContentLibraryPanelVisible(!self.contentLibrary.isPanelVisible)
    }

    /// 显示/隐藏内容库浮层（带淡入淡出，置顶）。
    func setContentLibraryPanelVisible(_ visible: Bool) {
        guard let panel = self.contentLibraryPanelView else { return }
        let changed = visible ? self.contentLibrary.show() : self.contentLibrary.hide()
        guard changed else { return }
        if visible {
            panel.isHidden = false
            self.view.bringSubviewToFront(panel)
            panel.alpha = 0.0
            UIView.animate(withDuration: 0.18) { panel.alpha = 1.0 }
            // 打开时刷新我的线稿（数据可能在关闭期间变化）。
            self.refreshCustomLineArt()
        } else {
            UIView.animate(withDuration: 0.15, animations: { panel.alpha = 0.0 }) { _ in
                panel.isHidden = true
            }
        }
    }

    /// 装配内容库浮层：分段标题、官方线稿网格、历史分区容器与回调。
    func setupContentLibraryPanel(historyPanel: UIView) {
        let panel = KCContentLibraryPanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.isHidden = true
        panel.alpha = 0.0
        self.view.addSubview(panel)
        self.contentLibraryPanelView = panel

        historyPanel.translatesAutoresizingMaskIntoConstraints = false
        panel.historyContainer.addSubview(historyPanel)

        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: self.view.topAnchor),
            panel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            historyPanel.topAnchor.constraint(equalTo: panel.historyContainer.topAnchor),
            historyPanel.leadingAnchor.constraint(equalTo: panel.historyContainer.leadingAnchor),
            historyPanel.trailingAnchor.constraint(equalTo: panel.historyContainer.trailingAnchor),
            historyPanel.bottomAnchor.constraint(equalTo: panel.historyContainer.bottomAnchor)
        ])

        for (index, partition) in KCContentLibraryPartition.defaultOrder.enumerated() {
            panel.setSegmentTitle(self.contentLibrarySegmentTitle(for: partition), forPartitionAt: index)
        }

        self.embedLineArtPickerInContentLibrary(panel: panel)
        self.embedMyLineArtGridInContentLibrary(panel: panel)
        self.refreshCustomLineArt()

        panel.onPartitionChange = { [weak self, weak panel] index in
            guard let self, let panel,
                  KCContentLibraryPartition.defaultOrder.indices.contains(index) else { return }
            let partition = KCContentLibraryPartition.defaultOrder[index]
            if self.contentLibrary.selectPartition(partition) {
                panel.showPartition(index: index)
            }
        }
        panel.onClose = { [weak self] in
            self?.setContentLibraryPanelVisible(false)
        }

        panel.showPartition(index: 0)
    }

    private func embedLineArtPickerInContentLibrary(panel: KCContentLibraryPanelView) {
        let picker = KCLineArtPickerViewController(
            items: self.currentLineArtItems(),
            lineArtFeature: self.lineArtFeature,
            registerPressFeedback: { [weak self] control in
                self?.registerPressFeedbackForControl(control)
            },
            selectionHandler: { [weak self] item in
                guard let self = self else { return }
                // 选线稿 = 替换画布；先收起内容库，再按需确认替换。
                self.setContentLibraryPanelVisible(false)
                self.performCanvasReplacementAfterUserConfirmation { [weak self] in
                    self?.loadLineArtItem(item)
                }
            }
        )
        self.addChild(picker)
        picker.view.translatesAutoresizingMaskIntoConstraints = false
        panel.officialLineArtContainer.addSubview(picker.view)
        NSLayoutConstraint.activate([
            picker.view.topAnchor.constraint(equalTo: panel.officialLineArtContainer.topAnchor),
            picker.view.leadingAnchor.constraint(equalTo: panel.officialLineArtContainer.leadingAnchor),
            picker.view.trailingAnchor.constraint(equalTo: panel.officialLineArtContainer.trailingAnchor),
            picker.view.bottomAnchor.constraint(equalTo: panel.officialLineArtContainer.bottomAnchor)
        ])
        picker.didMove(toParent: self)
        self.contentLibraryLineArtPicker = picker
    }

    func contentLibrarySegmentTitle(for partition: KCContentLibraryPartition) -> String {
        switch partition {
        case .officialLineArt: return KCL10n.libraryOfficialLineArtTitle
        case .myLineArt: return KCL10n.libraryMyLineArtTitle
        case .history: return KCL10n.libraryHistoryTitle
        case .imports: return KCL10n.libraryImportsTitle
        }
    }

    // MARK: - 我的线稿（T099）

    /// 装配“我的线稿”分区网格（保存入口 + 缩略图网格 + 空态），装入 `myLineArtContainer`。
    private func embedMyLineArtGridInContentLibrary(panel: KCContentLibraryPanelView) {
        let grid = KCMyLineArtGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        panel.myLineArtContainer.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: panel.myLineArtContainer.topAnchor),
            grid.leadingAnchor.constraint(equalTo: panel.myLineArtContainer.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: panel.myLineArtContainer.trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: panel.myLineArtContainer.bottomAnchor)
        ])
        grid.onSaveAsLineArt = { [weak self] in self?.didTapSaveAsLineArt() }
        grid.onGenerateFromPhoto = { [weak self] in self?.didTapGenerateLineArtFromPhoto() }
        grid.onOpen = { [weak self] identifier in self?.loadCustomLineArt(withIdentifier: identifier) }
        grid.onDelete = { [weak self] identifier, title in
            self?.confirmDeleteCustomLineArt(withIdentifier: identifier, title: title)
        }
        self.myLineArtGridView = grid
    }

    /// 刷新“我的线稿”分区：读取列表、配置网格、后台预热缩略图后回主线程再刷新一次。
    func refreshCustomLineArt() {
        let items = self.customLineArtService.loadAll()
        let provider: (String) -> UIImage? = { [weak self] id in
            self?.customLineArtService.cachedThumbnailImage(forId: id)
        }
        let saveTitle = KCL10n.saveAsLineArtTitle
        let generateTitle = KCL10n.generateLineArtFromPhotoTitle
        let emptyText = KCL10n.libraryMyLineArtEmptyTitle
        self.myLineArtGridView?.configure(items: items, saveTitle: saveTitle, generateTitle: generateTitle, emptyText: emptyText, thumbnailProvider: provider)
        let ids = items.map { $0.identifier }
        guard !ids.isEmpty else { return }
        self.customLineArtService.preloadThumbnailImages(forIds: ids) { [weak self] in
            self?.myLineArtGridView?.configure(items: items, saveTitle: saveTitle, generateTitle: generateTitle, emptyText: emptyText, thumbnailProvider: provider)
        }
    }

    /// “保存当前为线稿”：先做最小笔画与数量上限校验，再把用户笔画线稿化后保存。
    @objc func didTapSaveAsLineArt() {
        let minStrokes = 3
        guard self.canvasView.hasVisibleContent(), self.canvasView.strokeCount >= minStrokes else {
            self.showCustomLineArtToast(title: KCL10n.saveAsLineArtTooFewStrokesTitle,
                                        symbol: "hand.draw.fill",
                                        tint: .systemOrange)
            return
        }
        guard !self.customLineArtService.hasReachedCap() else {
            self.showCustomLineArtToast(title: KCL10n.saveAsLineArtCapReachedTitle,
                                        symbol: "exclamationmark.triangle.fill",
                                        tint: .systemOrange)
            return
        }
        let image = self.canvasView.lineArtImage()
        let activeId = (self.activeSession as KCSessionMetadata?)?.identifier
        self.setContentLibraryPanelVisible(false)
        self.customLineArtService.saveLineArt(image: image, sourceKind: 0, sourceSessionId: activeId) { [weak self] saved in
            guard let self else { return }
            if saved != nil {
                self.showCustomLineArtToast(title: KCL10n.saveAsLineArtSuccessTitle,
                                            symbol: "checkmark.circle.fill",
                                            tint: .systemGreen)
            } else {
                self.showSaveToastWithSuccess(false)
            }
            self.refreshCustomLineArt()
        }
    }

    /// 打开一条我的线稿：加载位图并替换画布（按需确认替换），切到填色工具。
    func loadCustomLineArt(withIdentifier identifier: String) {
        guard let image = self.customLineArtService.lineArtImage(forId: identifier) else { return }
        self.setContentLibraryPanelVisible(false)
        self.performCanvasReplacementAfterUserConfirmation { [weak self] in
            self?.finishLoadingLineArtImage(image, completion: nil)
        }
    }

    /// 删除一条我的线稿（二次确认）。只删线稿库条目，不影响历史作品。
    func confirmDeleteCustomLineArt(withIdentifier identifier: String, title: String) {
        let alert = UIAlertController(title: KCL10n.deleteCustomLineArtAlertTitle,
                                      message: KCL10n.deleteCustomLineArtAlertMessage,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: KCL10n.cancelTitle, style: .cancel))
        alert.addAction(UIAlertAction(title: KCL10n.deleteTitle, style: .destructive) { [weak self] _ in
            self?.customLineArtService.deleteLineArt(withIdentifier: identifier)
            self?.refreshCustomLineArt()
        })
        self.present(alert, animated: true)
    }

    /// 我的线稿相关通用文案 toast（锚定内容库入口按钮）。
    func showCustomLineArtToast(title: String, symbol: String, tint: UIColor) {
#if DEBUG
        self.runtimeAcceptanceLastSaveToastTitle = title
#endif
        self.toastPresenter.dismiss(self.saveToastView)
        self.saveToastView = self.toastPresenter.showMessageToast(
            title: title,
            symbolName: symbol,
            tintColor: tint,
            in: self.view,
            anchorView: self.contentLibraryButton
        )
    }

    /// T102：内容库历史分区空态。历史真正为空（无已保存会话且无草稿）时显示“还没有历史作品”引导，
    /// 并隐藏 historyPanel 栅格；非空时恢复栅格。空态文案走本地化，可见性由数据驱动。
    func refreshContentLibraryHistoryEmpty(hasDraft: Bool) {
        let empty = self.sessions.isEmpty && !hasDraft
        self.contentLibraryPanelView?.setHistoryEmptyVisible(empty, text: KCL10n.libraryHistoryEmptyTitle)
        self.historyPanelView?.isHidden = empty
    }

    func currentLineArtItems() -> [KCLineArtItem] {
        if let cachedLineArtItems {
            return cachedLineArtItems
        }

        let items = self.lineArtFeature.makeLineArtItems()
        self.cachedLineArtItems = items
        return items
    }

    func loadLineArtItem(_ item: KCLineArtItem, completion: ((Bool) -> Void)? = nil) {
        self.invalidateArtworkLoadWork()
        var canvasSize = self.canvasView.bounds.size
        if canvasSize == .zero {
            self.view.layoutIfNeeded()
            self.canvasView.layoutIfNeeded()
            canvasSize = self.canvasView.bounds.size
        }
        if canvasSize == .zero {
            canvasSize = CGSize(width: 1024.0, height: 720.0)
        }
        let drawingRect = self.visibleLineArtDrawingRect(forCanvasSize: canvasSize)
        let generation = self.lineArtLoadGeneration + 1
        self.lineArtLoadGeneration = generation

        self.lineArtRenderingQueue.async { [weak self, item, canvasSize, drawingRect] in
            guard let self else { return }
            let lineArt = self.lineArtFeature.lineArtImage(for: item, canvasSize: canvasSize, drawingRect: drawingRect)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.lineArtLoadGeneration == generation else {
                    completion?(false)
                    return
                }
                self.finishLoadingLineArtImage(lineArt, completion: completion)
            }
        }
    }

    private func finishLoadingLineArtImage(_ lineArt: UIImage, completion: ((Bool) -> Void)?) {
        let preservedDraft = self.preserveUnsavedActiveSessionDraftIfNeeded()
        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.invalidateDraftSaveTimer()
        if !preservedDraft {
            self.clearDraftAndInvalidateCurrentDraftMarker()
        }
        self.canvasView.loadLineArtImage(lineArt)
        self.selectToolMode(.fill)
        self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
        self.refreshActionButtons()
        completion?(true)
    }

    func visibleLineArtDrawingRect(forCanvasSize canvasSize: CGSize) -> CGRect {
        let fallbackRect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: 110.0, dy: 90.0)
        guard canvasSize.width > 0.0, canvasSize.height > 0.0, self.canvasView.bounds.size != .zero else {
            return fallbackRect
        }

        var visibleRect = self.view.safeAreaLayoutGuide.layoutFrame
        if visibleRect.isEmpty {
            visibleRect = self.view.bounds
        }

        let leftRail = self.collapsiblePanels.indices.contains(2) ? self.collapsiblePanels[2] : nil
        let rightPanel = self.collapsiblePanels.indices.contains(3) ? self.collapsiblePanels[3] : nil
        let bottomDock = self.collapsiblePanels.indices.contains(4) ? self.collapsiblePanels[4] : nil
        let padding: CGFloat = 24.0

        if let leftRail, !leftRail.isHidden {
            let frame = leftRail.convert(leftRail.bounds, to: self.view)
            visibleRect.origin.x = max(visibleRect.minX, frame.maxX + padding)
        }

        if let rightPanel, !rightPanel.isHidden {
            let frame = rightPanel.convert(rightPanel.bounds, to: self.view)
            visibleRect.size.width = min(visibleRect.maxX, frame.minX - padding) - visibleRect.minX
        }

        if let bottomDock, !bottomDock.isHidden {
            let frame = bottomDock.convert(bottomDock.bounds, to: self.view)
            visibleRect.size.height = min(visibleRect.maxY, frame.minY - padding) - visibleRect.minY
        }

        let canvasRect = self.view.convert(visibleRect, to: self.canvasView).intersection(self.canvasView.bounds)
        if canvasRect.width < 260.0 || canvasRect.height < 220.0 {
            return fallbackRect
        }

        return canvasRect.insetBy(dx: 42.0, dy: 36.0)
    }

    @objc func didTapHistoryThumb(_ button: UIButton) {
        let index = self.sessionIndexForHistoryThumbIndex(button.tag)
        if index < self.sessions.count {
            let session = self.sessions[index]
            self.performCanvasReplacementAfterUserConfirmation { [weak self] in
                guard let self else { return }
                self.selectedHistorySession = session
                self.openSession(session)
            }
        }
    }

    @objc func didTapPreviousHistoryPage() {
        if self.historyPageIndex == 0 {
            return
        }
        self.historyPageIndex -= 1
        self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
    }

    @objc func didTapNextHistoryPage() {
        if self.historyPageIndex >= self.maxHistoryPageIndex() {
            return
        }
        self.historyPageIndex += 1
        self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
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
        self.scheduleBrushWidthPreferenceSave()
        self.refreshSizePreview()
    }

    @objc func didFinishChangingSizeSlider(_ slider: UISlider) {
        self.flushBrushWidthPreferenceSave()
    }

    func openSession(_ session: KCSessionMetadata, completion: ((Bool) -> Void)? = nil) {
        let generation = self.nextArtworkLoadGeneration()
        self.artworkLoadingQueue.async { [weak self, session] in
            guard let self else { return }
            guard let data = self.sessionStore.artworkData(forSession: session),
                  let image = self.sessionStore.displayDecodedImage(from: data) else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard self.artworkLoadGeneration == generation else { return }
                    completion?(false)
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.artworkLoadGeneration == generation else {
                    completion?(false)
                    return
                }

                let preservedDraft = self.preserveUnsavedActiveSessionDraftIfNeeded()
                self.activeSession = session
                self.selectedHistorySession = session
                self.activeSessionHasUnsavedChanges = false
                self.invalidateDraftSaveTimer()
                self.suppressNextDraftSave = true
                self.canvasView.restoreCanvas(with: image)
                if !preservedDraft {
                    self.clearDraftAndInvalidateCurrentDraftMarker()
                }
                self.updateHistoryPageForActiveSession()
                self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
                self.refreshActionButtons()
                completion?(true)
            }
        }
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
        let restoreMode = KDToolMode(domainToolMode: self.transientToolModeMemory.toolModeAfterCompletingTransientTool())
        self.selectToolMode(restoreMode)
    }

    func drawingCanvasViewDidInsertSticker(_ canvasView: KCDrawingCanvasView) {
        let restoreMode = KDToolMode(domainToolMode: self.transientToolModeMemory.toolModeAfterCompletingTransientTool())
        self.selectToolMode(restoreMode)
    }

    func drawingCanvasViewSelectionDidChange(_ canvasView: KCDrawingCanvasView) {
        self.refreshStickerEditButtons()
    }

    func drawingCanvasViewContentDidChange(_ canvasView: KCDrawingCanvasView) {
        self.activeDraftMatchesCanvas = false
        self.invalidateArtworkLoadWork()
        self.invalidateSessionSaveWork()
        self.invalidateImageImportWork()
        self.invalidateLineArtLoadWork()
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

    func drawingCanvasViewportDidChange(_ canvasView: KCDrawingCanvasView) {
        self.refreshRestoreViewportButton()
    }

    // MARK: - 画布视口（T097）

    /// 计算“安全创作区”矩形：`view.bounds` 扣除系统安全区与可见浮动面板
    /// （顶栏、左工具轨、右侧面板、底部 Dock）的遮挡范围。面板收起后不计入，
    /// 创作区随之扩大；该矩形作为画布 viewport 的默认居中锚点与平移钳制边界。
    func canvasCreationRect() -> CGRect {
        let bounds = self.view.bounds
        guard !bounds.isEmpty else { return .zero }

        let insets = self.view.safeAreaInsets
        var topInset = insets.top
        var leftInset = insets.left
        var rightInset = insets.right
        var bottomInset = insets.bottom

        func extendInsets(for panel: UIView) {
            guard !panel.isHidden, panel.alpha > 0.0 else { return }
            let frame = panel.convert(panel.bounds, to: self.view)
            guard !frame.isEmpty, frame.intersects(bounds) else { return }
            // 仅按面板在 bounds 内的遮挡边扩展对应内边距。
            leftInset = max(leftInset, frame.maxX - bounds.minX)
            rightInset = max(rightInset, bounds.maxX - frame.minX)
            topInset = max(topInset, frame.maxY - bounds.minY)
            bottomInset = max(bottomInset, bounds.maxY - frame.minY)
        }

        for panel in self.collapsiblePanels {
            extendInsets(for: panel)
        }
        if let toggle = self.collapseToggleButton {
            extendInsets(for: toggle)
        }

        let horizontal = leftInset + rightInset
        let vertical = topInset + bottomInset
        guard horizontal < bounds.width, vertical < bounds.height else { return bounds }

        let creationRect = CGRect(
            x: bounds.minX + leftInset,
            y: bounds.minY + topInset,
            width: bounds.width - horizontal,
            height: bounds.height - vertical
        )
        return creationRect.isEmpty ? bounds : creationRect
    }

    /// “恢复视图”按钮仅在画布偏离默认视图时显示。
    func refreshRestoreViewportButton() {
        self.restoreViewportButton?.isHidden = self.canvasView.viewportIsAtDefault
    }

    @objc func didTapRestoreViewport() {
        self.canvasView.restoreDefaultViewport()
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
        if self.appliedCanvasActionState == actionState {
            return
        }
        self.appliedCanvasActionState = actionState
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
#if DEBUG
        self.runtimeAcceptanceLastSaveToastTitle = success ? KCL10n.saveSuccessToastTitle : KCL10n.saveFailedToastTitle
#endif
        self.toastPresenter.dismiss(self.saveToastView)
        self.saveToastView = self.toastPresenter.showSaveToast(success: success, in: self.view, anchorView: self.saveButton)
    }

    func showEmptyCanvasSaveToast() {
#if DEBUG
        self.runtimeAcceptanceLastSaveToastTitle = KCL10n.emptySaveToastTitle
#endif
        self.toastPresenter.dismiss(self.saveToastView)
        self.saveToastView = self.toastPresenter.showEmptyCanvasSaveToast(in: self.view, anchorView: self.saveButton)
    }

    func showPhotoExportFailedToast() {
        self.toastPresenter.dismiss(self.saveToastView)
        self.saveToastView = self.toastPresenter.showPhotoExportFailedToast(in: self.view, anchorView: self.saveButton)
#if DEBUG
        self.runtimeAcceptanceLastPhotoExportToastTitle = self.saveToastView?.accessibilityLabel
#endif
    }

    func invalidateArtworkLoadWork() {
        self.artworkLoadGeneration += 1
    }

    func nextArtworkLoadGeneration() -> Int {
        self.artworkLoadGeneration += 1
        return self.artworkLoadGeneration
    }

    func invalidateImageImportWork() {
        self.imageImportGeneration += 1
    }

    func invalidateLineArtLoadWork() {
        self.lineArtLoadGeneration += 1
    }

    deinit {
        self.flushBrushWidthPreferenceSave()
        self.contentPicker.flushRecentColorSave()
        self.invalidateDraftSaveTimer()
        self.toastPresenter.dismiss(self.saveToastView)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 颜色匹配

    func color(_ lhs: UIColor?, matchesColor rhs: UIColor?) -> Bool {
        return KCContentPickerFeature.colorsMatch(lhs, rhs)
    }
}
