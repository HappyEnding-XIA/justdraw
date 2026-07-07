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

// MARK: - KCMainViewController

class KCMainViewController: UIViewController, KDDrawingCanvasViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIColorPickerViewControllerDelegate {

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
    var paletteGridHeightConstraint: NSLayoutConstraint!
    var recentColorRowStack: UIStackView!
    var deleteHistoryButton: UIButton!
    var previousHistoryButton: UIButton!
    var nextHistoryButton: UIButton!
    var undoButton: UIButton!
    var redoButton: UIButton!
    var saveButton: UIButton!
    var saveToastView: UIView?
#if DEBUG
    var runtimeAcceptanceLastSaveToastTitle: String?
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
    private var draftThumbImageIdentity: String?
    private var historyThumbImageIdentities: [String?] = []
    private var cachedLineArtItems: [KCLineArtItem]?
    private var historySessionRefreshGeneration: Int = 0
    private var historyThumbnailRefreshGeneration: Int = 0
    var collapsiblePanels: [UIView] = []
    var collapseToggleButton: UIButton!
    var toolStateChip: UIView!
    var toolStateSwatch: UIView!
    var toolStateLabel: UILabel!
    var historyPageIndex: Int = 0
    var draftSaveTimer: Timer?
    private let sessionEncodingQueue = DispatchQueue(label: "com.kidcanvas.editor.session-encoding", qos: .userInitiated)
    private let artworkLoadingQueue = DispatchQueue(label: "com.kidcanvas.editor.artwork-loading", qos: .userInitiated)
    private let imageImportProcessingQueue = DispatchQueue(label: "com.kidcanvas.editor.image-import-processing", qos: .userInitiated)
    private let draftPersistenceQueue = DispatchQueue(label: "com.kidcanvas.editor.draft-persistence", qos: .utility)
    private let lineArtRenderingQueue = DispatchQueue(label: "com.kidcanvas.editor.line-art-rendering", qos: .userInitiated)
    private let draftGenerationLock = NSLock()
    private static let historyThumbnailImageStates: [UIControl.State] = [.normal, .highlighted, .selected, .disabled]
    private var sessionSaveGeneration: Int = 0
    private var artworkLoadGeneration: Int = 0
    private var imageImportGeneration: Int = 0
    private var draftSaveGeneration: Int = 0
    private var draftProtectionGeneration: Int = 0
    private var lineArtLoadGeneration: Int = 0
    private var didScheduleStartupDeferredWork = false
    private var activeDraftMatchesCanvas: Bool = false
    private var brushWidthPreferenceSaveTimer: Timer?
    var suppressNextDraftSave: Bool = false
    var activeSessionHasUnsavedChanges: Bool = false
    var brushWidthsByStyle: [Int: CGFloat] = [:]
    var eraserSliderValue: CGFloat = 0.0
    var transientToolModeMemory = KCTransientToolModeMemory()
#if DEBUG
    private var runtimeAcceptanceProbeDidRun = false
    private var runtimeAcceptanceImageImportCompletion: (() -> Void)?
#endif

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
        self.reloadPaletteGrid()
        self.reloadStickerButtons()
        self.selectToolMode(.brush)
        self.selectBrushStyle(.pencil)
        self.selectColor(self.contentPicker.palette24.first!, sender: nil)
        self.selectStickerSymbol(self.currentStickerSymbols().first!)
        self.refreshEraserShapeButtons()
        self.refreshStickerEditButtons()
        self.refreshHistoryUI(loadDraftThumbnail: false, preloadThumbnails: false, loadSessions: false)
        self.refreshActionButtons()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.refreshSizePreview()
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
        let safeArea = self.view.safeAreaLayoutGuide

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
            historyPanel.widthAnchor.constraint(equalToConstant: self.rightPanelWidth()),

            bottomDock.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            bottomDock.widthAnchor.constraint(equalToConstant: self.bottomDockWidth()),
            bottomDock.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: self.bottomDockBottomInset()),
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
        self.applyAccessibilityLabel(KCL10n.paletteTitle, identifier: "top.palette", toControl: brandButton)
        self.applyAccessibilityLabel(KCL10n.newCanvasTitle, identifier: "top.new-canvas", toControl: newButton)
        self.applyAccessibilityLabel(KCL10n.undoTitle, identifier: "top.undo", toControl: self.undoButton)
        self.applyAccessibilityLabel(KCL10n.redoTitle, identifier: "top.redo", toControl: self.redoButton)

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

    // MARK: - 历史

    func refreshHistoryUI(loadDraftThumbnail: Bool = true, preloadThumbnails: Bool = true, loadSessions: Bool = true) {
        if loadSessions {
            self.historySessionRefreshGeneration += 1
            self.sessions = self.sessionStore.loadAllSessions()
        }
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

        let draftImage = loadDraftThumbnail ? self.sessionStore.draftThumbnailImage() : self.sessionStore.cachedDraftThumbnailImage()
        let hasDraft = draftImage != nil || self.sessionStore.hasDraft()
        let selectedSession = self.currentSelectedHistorySession()
        let canDeleteHistoryItem = self.history.canDeleteHistory(
            hasSelectedSession: selectedSession != nil,
            sessionCount: self.sessions.count,
            hasDraft: hasDraft
        )
        self.deleteHistoryButton.isEnabled = canDeleteHistoryItem
        self.deleteHistoryButton.alpha = canDeleteHistoryItem ? 1.0 : 0.55

        Self.applyHistoryBackgroundImageIfNeeded(
            draftImage,
            identity: self.historyImageIdentityForDraft(draftImage),
            to: self.draftThumbButton,
            storedIdentity: &self.draftThumbImageIdentity
        )
        Self.setHistoryButtonPlaceholderVisible(draftImage == nil, on: self.draftThumbButton)
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
        self.ensureHistoryThumbImageIdentityCapacity()
        let sessionIds = self.sessions.map(\.identifier)
        let activeSessionId = self.activeSession?.identifier
        let selectedSessionId = selectedSession?.identifier
        var missingVisibleThumbnailIds: [String] = []
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
                Self.applyHistoryBackgroundImageIfNeeded(
                    nil,
                    identity: nil,
                    to: button,
                    storedIdentity: &self.historyThumbImageIdentities[index]
                )
                Self.setHistoryButtonPlaceholderVisible(true, on: button)
                button.isEnabled = false
                button.accessibilityLabel = "\(KCL10n.historyThumbPrefix(status.accessibilityPrefix)) \(index + 1)"
                button.backgroundColor = UIColor(red: 1.0, green: 0.995, blue: 0.98, alpha: 1.0)
                button.transform = .identity
            } else {
                let session = self.sessions[sessionIndex]
                let image = self.sessionStore.cachedThumbnailImage(forSessionId: session.identifier)
                if image == nil {
                    missingVisibleThumbnailIds.append(session.identifier)
                }
                Self.applyHistoryBackgroundImageIfNeeded(
                    image,
                    identity: self.historyImageIdentityForSession(session, image: image),
                    to: button,
                    storedIdentity: &self.historyThumbImageIdentities[index]
                )
                Self.setHistoryButtonPlaceholderVisible(false, on: button)
                button.isEnabled = true
                button.accessibilityLabel = "\(KCL10n.historyThumbPrefix(status.accessibilityPrefix)) \(sessionIndex + 1)"
                button.transform = status.isEmphasized
                    ? CGAffineTransform(scaleX: status.emphasisScale, y: status.emphasisScale)
                    : .identity
            }
        }

        if preloadThumbnails {
            self.preloadVisibleHistoryThumbnailsIfNeeded(missingVisibleThumbnailIds)
            self.preloadAdjacentHistoryThumbnails()
        }
    }

    func refreshHistorySessionsAsync(loadDraftThumbnail: Bool = true, preloadThumbnails: Bool = true) {
        let generation = self.historySessionRefreshGeneration + 1
        self.historySessionRefreshGeneration = generation
        self.sessionStore.loadAllSessionsAsync { [weak self] sessions in
            guard let self else { return }
            guard self.historySessionRefreshGeneration == generation else { return }
            self.sessions = sessions
            self.refreshHistoryUI(
                loadDraftThumbnail: loadDraftThumbnail,
                preloadThumbnails: preloadThumbnails,
                loadSessions: false
            )
        }
    }

    private func preloadVisibleHistoryThumbnailsIfNeeded(_ sessionIds: [String]) {
        let uniqueSessionIds = Array(Set(sessionIds))
        guard !uniqueSessionIds.isEmpty else { return }

        let generation = self.historyThumbnailRefreshGeneration + 1
        self.historyThumbnailRefreshGeneration = generation
        self.sessionStore.preloadThumbnailImages(forSessionIds: uniqueSessionIds) { [weak self] in
            guard let self else { return }
            guard self.historyThumbnailRefreshGeneration == generation else { return }
            self.refreshHistoryUI()
        }
    }

    private func preloadAdjacentHistoryThumbnails() {
        let preloadIndexes = KCHistoryPaging(
            sessionCount: self.sessions.count,
            pageSize: self.historyPageSize(),
            pageIndex: self.historyPageIndex
        ).adjacentPageSessionIndexes()
        guard !preloadIndexes.isEmpty else { return }

        let sessionIds = preloadIndexes.compactMap { index -> String? in
            guard self.sessions.indices.contains(index) else { return nil }
            return self.sessions[index].identifier
        }
        self.sessionStore.preloadThumbnailImages(forSessionIds: sessionIds)
    }

    private func ensureHistoryThumbImageIdentityCapacity() {
        if self.historyThumbImageIdentities.count == self.historyThumbButtons.count {
            return
        }
        self.historyThumbImageIdentities = Array(repeating: nil, count: self.historyThumbButtons.count)
    }

    private func historyImageIdentityForDraft(_ image: UIImage?) -> String? {
        guard let image else { return nil }
        return "draft:\(ObjectIdentifier(image).hashValue)"
    }

    private func historyImageIdentityForSession(_ session: KCSessionMetadata, image: UIImage?) -> String? {
        guard image != nil else { return nil }
        return "session:\(session.identifier):\(session.modifiedAt.timeIntervalSince1970)"
    }

    private static func applyHistoryBackgroundImageIfNeeded(
        _ image: UIImage?,
        identity: String?,
        to button: UIButton,
        storedIdentity: inout String?
    ) {
        if let identity, storedIdentity == identity {
            return
        }

        let currentImage = button.backgroundImage(for: .normal)
        if currentImage == nil && image == nil && storedIdentity == nil {
            return
        }

        Self.setHistoryBackgroundImage(image, to: button)
        storedIdentity = identity
    }

    private static func setHistoryBackgroundImage(_ image: UIImage?, to button: UIButton) {
        for state in Self.historyThumbnailImageStates {
            button.setBackgroundImage(image, for: state)
        }
    }

    private static func setHistoryButtonPlaceholderVisible(_ visible: Bool, on button: UIButton) {
        let image = visible ? Self.historySlotPlaceholderImage() : nil
        for state in Self.historyThumbnailImageStates {
            button.setImage(image, for: state)
        }
        button.imageView?.contentMode = .center
        button.imageView?.isHidden = !visible
    }

    private static func historySlotPlaceholderImage() -> UIImage? {
        KCEditorUIFactory.historySlotPlaceholderImage()
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
        if !self.presentPhotoLibraryPicker(animated: true, completion: nil) {
            self.showSaveToastWithSuccess(false)
        }
    }

    func configuredPhotoLibraryPicker() -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        let popover = picker.popoverPresentationController
        popover?.sourceView = self.view
        popover?.sourceRect = CGRect(x: self.view.bounds.maxX - 110.0, y: 88.0, width: 1.0, height: 1.0)
        popover?.permittedArrowDirections = .up
        return picker
    }

    @discardableResult
    func presentPhotoLibraryPicker(animated: Bool, completion: ((UIImagePickerController) -> Void)?) -> Bool {
        if !UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            return false
        }

        let picker = self.configuredPhotoLibraryPicker()
        self.present(picker, animated: animated) {
            completion?(picker)
        }
        return true
    }

    @objc func didTapSaveSession() {
        if !self.canvasFeature.hasVisibleContent(self.canvasView) {
            self.showSaveToastWithSuccess(false)
            return
        }

        let snapshot = self.canvasView.snapshotImage()
        let existingSessionId = self.activeSession?.identifier
        let generation = self.sessionSaveGeneration + 1
        self.sessionSaveGeneration = generation
        self.sessionEncodingQueue.async { [weak self, snapshot, existingSessionId] in
            guard let self else { return }
            let encodedData = self.sessionStore.encodedArtworkData(from: snapshot)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.sessionSaveGeneration == generation else { return }
                guard let encodedData else {
                    self.showSaveToastWithSuccess(false)
                    return
                }
                self.finishSavingSession(
                    snapshot: snapshot,
                    pngData: encodedData.pngData,
                    thumbnailJPEGData: encodedData.thumbnailJPEGData,
                    existingSessionId: existingSessionId,
                    generation: generation
                )
            }
        }
    }

    private func finishSavingSession(
        snapshot: UIImage,
        pngData: Data,
        thumbnailJPEGData: Data,
        existingSessionId: String?,
        generation: Int
    ) {
        guard self.sessionSaveGeneration == generation else { return }
        guard let savedSession = self.sessionStore.saveArtwork(
            pngData: pngData,
            thumbnailJPEGData: thumbnailJPEGData,
            existingSessionId: existingSessionId
        ) else {
            self.showSaveToastWithSuccess(false)
            return
        }

        self.activeSession = savedSession
        self.selectedHistorySession = savedSession
        self.activeSessionHasUnsavedChanges = false
        self.invalidateDraftSaveTimer()
        self.clearDraftAndInvalidateCurrentDraftMarker()
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
                let deletingActiveSession = self.activeSession?.identifier == session?.identifier
                self.sessionStore.deleteSession(withId: session!.identifier)
                if deletingActiveSession {
                    self.activeSession = nil
                    self.selectedHistorySession = nil
                    self.activeSessionHasUnsavedChanges = false
                    self.invalidateArtworkLoadWork()
                    self.invalidateDraftSaveTimer()
                    self.suppressNextDraftSave = true
                    self.canvasView.startBlankCanvas()
                    self.clearDraftAndInvalidateCurrentDraftMarker()
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

    @objc func didTapLineArtPicker() {
        let picker = KCLineArtPickerViewController(
            items: self.currentLineArtItems(),
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
        self.view.layoutIfNeeded()
        self.canvasView.layoutIfNeeded()
        var canvasSize = self.canvasView.bounds.size
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
        self.refreshHistoryUI()
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
        let generation = self.nextArtworkLoadGeneration()
        self.draftPersistenceQueue.async { [weak self] in
            guard let self else { return }
            guard let data = self.sessionStore.loadDraftData(),
                  let draftImage = UIImage(data: data) else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.artworkLoadGeneration == generation else { return }

                self.sessionStore.cacheLoadedDraftImage(draftImage)
                self.activeSession = nil
                self.selectedHistorySession = nil
                self.activeSessionHasUnsavedChanges = false
                self.suppressNextDraftSave = true
                self.canvasView.restoreCanvas(with: draftImage)
                self.activeDraftMatchesCanvas = true
                self.refreshHistoryUI()
                self.refreshActionButtons()
            }
        }
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
                  let image = UIImage(data: data) else {
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
                self.refreshHistoryUI()
                self.refreshActionButtons()
                completion?(true)
            }
        }
    }

    func preserveUnsavedActiveSessionDraftIfNeeded() -> Bool {
        if self.activeSession != nil && !self.activeSessionHasUnsavedChanges {
            return false
        }

        if self.activeDraftMatchesCanvas && self.sessionStore.hasDraft() {
            return true
        }

        if !self.canvasFeature.hasVisibleContent(self.canvasView) {
            self.activeDraftMatchesCanvas = false
            return false
        }

        self.invalidateDraftSaveTimer()
        let snapshot = self.canvasView.snapshotImage()
        let generation = self.nextDraftProtectionGeneration()
        self.draftPersistenceQueue.async { [weak self, snapshot, generation] in
            guard let self else { return }
            guard let pngData = snapshot.pngData() else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard self.isDraftProtectionGenerationCurrent(generation) else { return }
                    self.refreshHistoryUI(loadSessions: false)
                }
                return
            }

            guard self.isDraftProtectionGenerationCurrent(generation) else { return }

            let saved = self.sessionStore.saveDraftData(pngData: pngData, cachedImage: snapshot)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.isDraftProtectionGenerationCurrent(generation) else { return }
                if !saved {
                    self.activeDraftMatchesCanvas = false
                }
                self.refreshHistoryUI(loadSessions: false)
            }
        }
        return true
    }

    func clearDraftAndInvalidateCurrentDraftMarker() {
        self.nextDraftProtectionGeneration()
        self.sessionStore.clearDraft()
        self.activeDraftMatchesCanvas = false
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

    // MARK: - 图片选择器

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.originalImage] as? UIImage
        self.invalidateArtworkLoadWork()
        let generation = self.imageImportGeneration + 1
        self.imageImportGeneration = generation
        picker.dismiss(animated: true, completion: nil)

        self.imageImportProcessingQueue.async { [weak self, image] in
            guard let self else { return }
            let normalizedImage = self.normalizedImageFromImage(image)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.imageImportGeneration == generation else { return }
                guard let normalizedImage else {
                    self.showSaveToastWithSuccess(false)
#if DEBUG
                    let runtimeCompletion = self.runtimeAcceptanceImageImportCompletion
                    self.runtimeAcceptanceImageImportCompletion = nil
                    runtimeCompletion?()
#endif
                    return
                }
                self.finishImportingImage(normalizedImage)
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.invalidateArtworkLoadWork()
        self.invalidateImageImportWork()
        picker.dismiss(animated: true, completion: nil)
    }

    private func finishImportingImage(_ normalizedImage: UIImage) {
        let preservedDraft = self.preserveUnsavedActiveSessionDraftIfNeeded()
        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.invalidateDraftSaveTimer()
        if !preservedDraft {
            self.clearDraftAndInvalidateCurrentDraftMarker()
        }
        self.canvasView.replaceCanvas(with: normalizedImage)
        self.refreshHistoryUI()
        self.refreshActionButtons()
#if DEBUG
        let runtimeCompletion = self.runtimeAcceptanceImageImportCompletion
        self.runtimeAcceptanceImageImportCompletion = nil
        runtimeCompletion?()
#endif
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
#if DEBUG
        self.runtimeAcceptanceLastSaveToastTitle = success ? KCL10n.saveSuccessToastTitle : KCL10n.saveFailedToastTitle
#endif
        self.toastPresenter.dismiss(self.saveToastView)
        self.saveToastView = self.toastPresenter.showSaveToast(success: success, in: self.view, anchorView: self.saveButton)
    }

#if DEBUG
    // MARK: - 运行时验收探针

    private func runRuntimeAcceptanceProbeIfNeeded() {
        if self.runtimeAcceptanceProbeDidRun {
            return
        }

        let arguments = ProcessInfo.processInfo.arguments
        let shouldRunEmptySaveProbe = arguments.contains("--kc-runtime-empty-save-check")
        let shouldRunLayoutProbe = arguments.contains("--kc-runtime-layout-check")
        let shouldRunStickerProbe = arguments.contains("--kc-runtime-sticker-check")
        let shouldRunSaveHistoryProbe = arguments.contains("--kc-runtime-save-history-check")
        let shouldRunDrawingToolsProbe = arguments.contains("--kc-runtime-drawing-tools-check")
        let shouldRunSystemUIProbe = arguments.contains("--kc-runtime-system-ui-check")
        guard shouldRunEmptySaveProbe
                || shouldRunLayoutProbe
                || shouldRunStickerProbe
                || shouldRunSaveHistoryProbe
                || shouldRunDrawingToolsProbe
                || shouldRunSystemUIProbe else {
            return
        }
        self.runtimeAcceptanceProbeDidRun = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if shouldRunLayoutProbe {
                self?.runLayoutAcceptanceProbe()
            } else if shouldRunStickerProbe {
                self?.runStickerUndoRedoAcceptanceProbe()
            } else if shouldRunSaveHistoryProbe {
                self?.runSaveHistoryAcceptanceProbe()
            } else if shouldRunDrawingToolsProbe {
                self?.runDrawingToolsAcceptanceProbe()
            } else if shouldRunSystemUIProbe {
                self?.runSystemUIPresentationAcceptanceProbe()
            } else {
                self?.runEmptySaveAcceptanceProbe()
            }
        }
    }

    private func runEmptySaveAcceptanceProbe() {
        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.invalidateDraftSaveTimer()
        self.suppressNextDraftSave = true
        self.canvasView.startBlankCanvas()
        self.clearDraftAndInvalidateCurrentDraftMarker()
        self.runtimeAcceptanceLastSaveToastTitle = nil
        self.refreshHistoryUI()
        self.refreshActionButtons()

        let historyCountBefore = self.sessions.count
        let hasVisibleContentBefore = self.canvasFeature.hasVisibleContent(self.canvasView)
        let saveButtonEnabledBeforeTap = self.saveButton.isEnabled
        self.didTapSaveSession()
        let failureToastVisible = self.saveToastView?.accessibilityLabel == KCL10n.saveFailedToastTitle
        let result: [String: Any] = [
            "probe": "empty-save",
            "passed": !hasVisibleContentBefore
                && saveButtonEnabledBeforeTap
                && failureToastVisible
                && self.sessions.count == historyCountBefore,
            "hasVisibleContentBefore": hasVisibleContentBefore,
            "saveButtonEnabledBeforeTap": saveButtonEnabledBeforeTap,
            "failureToastVisible": failureToastVisible,
            "historyCountBefore": historyCountBefore,
            "historyCountAfter": self.sessions.count,
            "expectedToast": KCL10n.saveFailedToastTitle
        ]
        self.writeRuntimeAcceptanceResult(result, fileName: "kc_runtime_acceptance_empty_save.json")
    }

    private func runLayoutAcceptanceProbe() {
        self.view.layoutIfNeeded()

        let safeFrame = self.view.bounds.inset(by: self.view.safeAreaInsets)
        let topLeft = self.collapsiblePanels.indices.contains(0) ? self.collapsiblePanels[0] : nil
        let topRight = self.collapsiblePanels.indices.contains(1) ? self.collapsiblePanels[1] : nil
        let leftRail = self.collapsiblePanels.indices.contains(2) ? self.collapsiblePanels[2] : nil
        let rightPanel = self.collapsiblePanels.indices.contains(3) ? self.collapsiblePanels[3] : nil
        let bottomDock = self.collapsiblePanels.indices.contains(4) ? self.collapsiblePanels[4] : nil

        var checks: [[String: Any]] = []
        checks.append(self.layoutCheckResult(name: "top-left", view: topLeft, boundary: safeFrame, edges: [.left, .top]))
        checks.append(self.layoutCheckResult(name: "top-right", view: topRight, boundary: safeFrame, edges: [.right, .top]))
        checks.append(self.layoutCheckResult(name: "left-rail", view: leftRail, boundary: safeFrame, edges: [.left, .top, .bottom]))
        checks.append(self.layoutCheckResult(name: "right-panel", view: rightPanel, boundary: safeFrame, edges: [.right, .top]))
        checks.append(self.layoutCheckResult(name: "bottom-dock", view: bottomDock, boundary: safeFrame, edges: [.bottom]))
        checks.append(self.layoutCheckResult(name: "collapse-toggle", view: self.collapseToggleButton, boundary: safeFrame, edges: [.right, .bottom]))
        checks.append(self.visibleHeightCheckResult(name: "left-rail-visible-height", view: leftRail, minimumHeight: 220.0))
        checks.append(self.visibleHeightCheckResult(name: "right-panel-visible-height", view: rightPanel, minimumHeight: 190.0))

        let failedChecks = checks.filter { ($0["passed"] as? Bool) != true }
        let result: [String: Any] = [
            "probe": "layout-safe-area",
            "passed": failedChecks.isEmpty,
            "viewBounds": self.dictionary(for: self.view.bounds),
            "safeAreaInsets": [
                "top": self.view.safeAreaInsets.top,
                "left": self.view.safeAreaInsets.left,
                "bottom": self.view.safeAreaInsets.bottom,
                "right": self.view.safeAreaInsets.right
            ],
            "safeFrame": self.dictionary(for: safeFrame),
            "checks": checks
        ]
        self.writeRuntimeAcceptanceResult(result, fileName: "kc_runtime_acceptance_layout.json")
    }

    private func runStickerUndoRedoAcceptanceProbe() {
        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.invalidateDraftSaveTimer()
        self.suppressNextDraftSave = true
        self.canvasView.startBlankCanvas()
        self.clearDraftAndInvalidateCurrentDraftMarker()
        self.refreshHistoryUI()
        self.refreshActionButtons()

        let initialVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let initialCanUndo = self.canvasView.canUndo()
        let initialCanRedo = self.canvasView.canRedo()

        self.canvasView.currentColor = UIColor(red: 0.94, green: 0.43, blue: 0.45, alpha: 1.0)
        self.canvasView.insertStickerSymbol("seal.fill", atNormalizedPoint: CGPoint(x: 0.5, y: 0.5))
        self.refreshActionButtons()

        let afterInsertVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let afterInsertSelected = self.canvasView.hasSelectedSticker()
        let afterInsertCanUndo = self.canvasView.canUndo()
        let saveButtonEnabledAfterInsert = self.saveButton.isEnabled

        self.canvasView.deleteSelectedSticker()
        self.refreshActionButtons()
        let afterDeleteVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let afterDeleteCanUndo = self.canvasView.canUndo()
        let afterDeleteCanRedo = self.canvasView.canRedo()

        self.canvasView.undoLastAction()
        self.refreshActionButtons()
        let afterUndoVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let afterUndoCanRedo = self.canvasView.canRedo()

        self.canvasView.redoLastAction()
        self.refreshActionButtons()
        let afterRedoVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let afterRedoCanUndo = self.canvasView.canUndo()
        let saveButtonEnabledAfterRedo = self.saveButton.isEnabled

        let result: [String: Any] = [
            "probe": "sticker-undo-redo",
            "passed": !initialVisible
                && !initialCanUndo
                && !initialCanRedo
                && afterInsertVisible
                && afterInsertSelected
                && afterInsertCanUndo
                && saveButtonEnabledAfterInsert
                && !afterDeleteVisible
                && afterDeleteCanUndo
                && !afterDeleteCanRedo
                && afterUndoVisible
                && afterUndoCanRedo
                && !afterRedoVisible
                && afterRedoCanUndo
                && saveButtonEnabledAfterRedo,
            "initialVisible": initialVisible,
            "initialCanUndo": initialCanUndo,
            "initialCanRedo": initialCanRedo,
            "afterInsertVisible": afterInsertVisible,
            "afterInsertSelected": afterInsertSelected,
            "afterInsertCanUndo": afterInsertCanUndo,
            "saveButtonEnabledAfterInsert": saveButtonEnabledAfterInsert,
            "afterDeleteVisible": afterDeleteVisible,
            "afterDeleteCanUndo": afterDeleteCanUndo,
            "afterDeleteCanRedo": afterDeleteCanRedo,
            "afterUndoVisible": afterUndoVisible,
            "afterUndoCanRedo": afterUndoCanRedo,
            "afterRedoVisible": afterRedoVisible,
            "afterRedoCanUndo": afterRedoCanUndo,
            "saveButtonEnabledAfterRedo": saveButtonEnabledAfterRedo
        ]
        self.writeRuntimeAcceptanceResult(result, fileName: "kc_runtime_acceptance_sticker.json")
    }

    private func runSaveHistoryAcceptanceProbe() {
        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.invalidateDraftSaveTimer()
        self.suppressNextDraftSave = true
        self.canvasView.startBlankCanvas()
        self.clearDraftAndInvalidateCurrentDraftMarker()
        self.refreshHistoryUI()
        self.refreshActionButtons()

        let initialHistoryCount = self.sessions.count
        let initialVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let initialCanUndo = self.canvasView.canUndo()
        let initialCanRedo = self.canvasView.canRedo()

        self.canvasView.currentColor = UIColor(red: 0.30, green: 0.55, blue: 0.92, alpha: 1.0)
        self.canvasView.currentToolMode = .brush
        self.canvasView.currentBrushStyle = .pen
        self.canvasView.currentLineWidth = 20.0
        self.canvasView.insertRuntimeAcceptanceStroke()
        self.refreshActionButtons()

        let afterDrawVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let afterDrawCanUndo = self.canvasView.canUndo()
        let saveButtonEnabledAfterDraw = self.saveButton.isEnabled

        self.didTapSaveSession()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.finishSaveHistoryAcceptanceProbe(
                initialHistoryCount: initialHistoryCount,
                initialVisible: initialVisible,
                initialCanUndo: initialCanUndo,
                initialCanRedo: initialCanRedo,
                afterDrawVisible: afterDrawVisible,
                afterDrawCanUndo: afterDrawCanUndo,
                saveButtonEnabledAfterDraw: saveButtonEnabledAfterDraw
            )
        }
    }

    private func finishSaveHistoryAcceptanceProbe(
        initialHistoryCount: Int,
        initialVisible: Bool,
        initialCanUndo: Bool,
        initialCanRedo: Bool,
        afterDrawVisible: Bool,
        afterDrawCanUndo: Bool,
        saveButtonEnabledAfterDraw: Bool
    ) {
        let savedSession = self.activeSession
        let afterSaveHistoryCount = self.sessions.count
        let afterSaveActiveSessionId = self.activeSession?.identifier ?? ""
        let afterSaveSelectedSessionId = self.selectedHistorySession?.identifier ?? ""
        let successToastVisible = self.saveToastView?.accessibilityLabel == KCL10n.saveSuccessToastTitle
        let successToastObserved = successToastVisible || self.runtimeAcceptanceLastSaveToastTitle == KCL10n.saveSuccessToastTitle
        let afterSaveCanUndo = self.canvasView.canUndo()
        let afterSaveCanRedo = self.canvasView.canRedo()

        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.suppressNextDraftSave = true
        self.canvasView.startBlankCanvas()
        self.invalidateDraftSaveTimer()
        self.clearDraftAndInvalidateCurrentDraftMarker()
        self.refreshHistoryUI()
        self.refreshActionButtons()
        let afterClearVisible = self.canvasFeature.hasVisibleContent(self.canvasView)

        if let savedSession {
            self.openSession(savedSession) { [weak self] openSucceeded in
                self?.finishSaveHistoryAcceptanceProbeAfterOpen(
                    savedSession: savedSession,
                    openSucceeded: openSucceeded,
                    initialHistoryCount: initialHistoryCount,
                    initialVisible: initialVisible,
                    initialCanUndo: initialCanUndo,
                    initialCanRedo: initialCanRedo,
                    afterDrawVisible: afterDrawVisible,
                    afterDrawCanUndo: afterDrawCanUndo,
                    saveButtonEnabledAfterDraw: saveButtonEnabledAfterDraw,
                    afterSaveHistoryCount: afterSaveHistoryCount,
                    afterSaveActiveSessionId: afterSaveActiveSessionId,
                    afterSaveSelectedSessionId: afterSaveSelectedSessionId,
                    successToastVisible: successToastVisible,
                    successToastObserved: successToastObserved,
                    afterSaveCanUndo: afterSaveCanUndo,
                    afterSaveCanRedo: afterSaveCanRedo,
                    afterClearVisible: afterClearVisible
                )
            }
            return
        }

        self.finishSaveHistoryAcceptanceProbeAfterOpen(
            savedSession: nil,
            openSucceeded: false,
            initialHistoryCount: initialHistoryCount,
            initialVisible: initialVisible,
            initialCanUndo: initialCanUndo,
            initialCanRedo: initialCanRedo,
            afterDrawVisible: afterDrawVisible,
            afterDrawCanUndo: afterDrawCanUndo,
            saveButtonEnabledAfterDraw: saveButtonEnabledAfterDraw,
            afterSaveHistoryCount: afterSaveHistoryCount,
            afterSaveActiveSessionId: afterSaveActiveSessionId,
            afterSaveSelectedSessionId: afterSaveSelectedSessionId,
            successToastVisible: successToastVisible,
            successToastObserved: successToastObserved,
            afterSaveCanUndo: afterSaveCanUndo,
            afterSaveCanRedo: afterSaveCanRedo,
            afterClearVisible: afterClearVisible
        )
    }

    private func finishSaveHistoryAcceptanceProbeAfterOpen(
        savedSession: KCSessionMetadata?,
        openSucceeded: Bool,
        initialHistoryCount: Int,
        initialVisible: Bool,
        initialCanUndo: Bool,
        initialCanRedo: Bool,
        afterDrawVisible: Bool,
        afterDrawCanUndo: Bool,
        saveButtonEnabledAfterDraw: Bool,
        afterSaveHistoryCount: Int,
        afterSaveActiveSessionId: String,
        afterSaveSelectedSessionId: String,
        successToastVisible: Bool,
        successToastObserved: Bool,
        afterSaveCanUndo: Bool,
        afterSaveCanRedo: Bool,
        afterClearVisible: Bool
    ) {
        let afterOpenVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let afterOpenActiveSessionId = self.activeSession?.identifier ?? ""
        let afterOpenSelectedSessionId = self.selectedHistorySession?.identifier ?? ""
        let afterOpenCanUndo = self.canvasView.canUndo()
        let afterOpenCanRedo = self.canvasView.canRedo()

        let result: [String: Any] = [
            "probe": "save-history-restore",
            "passed": !initialVisible
                && !initialCanUndo
                && !initialCanRedo
                && afterDrawVisible
                && afterDrawCanUndo
                && saveButtonEnabledAfterDraw
                && savedSession != nil
                && afterSaveHistoryCount == initialHistoryCount + 1
                && afterSaveActiveSessionId == savedSession?.identifier
                && afterSaveSelectedSessionId == savedSession?.identifier
                && successToastObserved
                && afterSaveCanUndo
                && !afterSaveCanRedo
                && !afterClearVisible
                && openSucceeded
                && afterOpenVisible
                && afterOpenActiveSessionId == savedSession?.identifier
                && afterOpenSelectedSessionId == savedSession?.identifier
                && !afterOpenCanUndo
                && !afterOpenCanRedo,
            "initialHistoryCount": initialHistoryCount,
            "initialVisible": initialVisible,
            "initialCanUndo": initialCanUndo,
            "initialCanRedo": initialCanRedo,
            "afterDrawVisible": afterDrawVisible,
            "afterDrawCanUndo": afterDrawCanUndo,
            "saveButtonEnabledAfterDraw": saveButtonEnabledAfterDraw,
            "afterSaveHistoryCount": afterSaveHistoryCount,
            "afterSaveActiveSessionId": afterSaveActiveSessionId,
            "afterSaveSelectedSessionId": afterSaveSelectedSessionId,
            "successToastVisible": successToastVisible,
            "successToastObserved": successToastObserved,
            "afterSaveCanUndo": afterSaveCanUndo,
            "afterSaveCanRedo": afterSaveCanRedo,
            "afterClearVisible": afterClearVisible,
            "afterOpenVisible": afterOpenVisible,
            "afterOpenActiveSessionId": afterOpenActiveSessionId,
            "afterOpenSelectedSessionId": afterOpenSelectedSessionId,
            "afterOpenCanUndo": afterOpenCanUndo,
            "afterOpenCanRedo": afterOpenCanRedo,
            "openSucceeded": openSucceeded,
            "expectedToast": KCL10n.saveSuccessToastTitle
        ]
        self.writeRuntimeAcceptanceResult(result, fileName: "kc_runtime_acceptance_save_history.json")
    }

    private func runDrawingToolsAcceptanceProbe() {
        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.invalidateDraftSaveTimer()
        self.suppressNextDraftSave = true
        self.canvasView.startBlankCanvas()
        self.clearDraftAndInvalidateCurrentDraftMarker()
        self.didTapPalette24()
        self.refreshHistoryUI()
        self.refreshActionButtons()
        self.view.layoutIfNeeded()

        let initialVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let initialCanUndo = self.canvasView.canUndo()
        let initialCanRedo = self.canvasView.canRedo()

        let palette24Count = self.currentPalette().count
        let palette24ButtonActive = self.palette24Button.backgroundColor == KCEditorVisualStyle.accentColor

        self.didTapPalette36()
        let palette36Count = self.currentPalette().count
        let palette36ButtonActive = self.palette36Button.backgroundColor == KCEditorVisualStyle.accentColor
        let selectedColor = self.currentPalette().last ?? UIColor(red: 0.94, green: 0.43, blue: 0.45, alpha: 1.0)
        self.selectColor(selectedColor, sender: nil)
        let selectedColorApplied = self.color(self.canvasView.currentColor, matchesColor: selectedColor)
        let selectedColorHighlighted = self.activeColorButton != nil

        self.selectToolMode(.brush)
        self.selectBrushStyle(.pen)
        self.canvasView.currentLineWidth = 22.0
        self.canvasView.insertRuntimeAcceptanceStroke()
        self.refreshActionButtons()
        let afterBrushVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let afterBrushCanUndo = self.canvasView.canUndo()
        let afterBrushSnapshot = self.runtimeAcceptanceSnapshotData()

        self.selectToolMode(.eraser)
        self.canvasView.currentLineWidth = 34.0
        self.canvasView.currentEraserShape = .circle
        self.canvasView.insertRuntimeAcceptanceEraserStroke()
        self.refreshActionButtons()
        let afterEraserVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let afterEraserCanUndo = self.canvasView.canUndo()
        let eraserChangedCanvas = self.runtimeAcceptanceSnapshotData() != afterBrushSnapshot

        let lineArtItem = self.currentLineArtItems().first
        let finishProbe: (KCLineArtItem?, Bool) -> Void = { [weak self] lineArtItem, lineArtLoaded in
            guard let self else { return }
            self.view.layoutIfNeeded()
            let afterLineArtVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
            let afterLineArtToolIsFill = self.canvasView.currentToolMode == .fill
            let afterLineArtCanUndo = self.canvasView.canUndo()
            let afterLineArtCanRedo = self.canvasView.canRedo()
            let beforeFillSnapshot = self.runtimeAcceptanceSnapshotData()

            let fillColor = UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0)
            self.selectColor(fillColor, sender: nil)
            let fillSucceeded = self.canvasView.performRuntimeAcceptanceFloodFill(atNormalizedPoint: CGPoint(x: 0.08, y: 0.08))
            self.refreshActionButtons()
            let afterFillVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
            let afterFillCanUndo = self.canvasView.canUndo()
            let fillChangedCanvas = self.runtimeAcceptanceSnapshotData() != beforeFillSnapshot

            self.selectToolMode(.picker)
            let pickedColor = self.canvasView.runtimeAcceptancePickedColor(atNormalizedPoint: CGPoint(x: 0.08, y: 0.08))
            if let pickedColor {
                self.canvasView.currentColor = pickedColor
                self.selectColor(pickedColor, sender: nil)
                self.addRecentColor(pickedColor)
            }
            let pickedColorMatchesFill = self.color(pickedColor, matchesColor: fillColor)
            let currentColorMatchesPicked = self.color(self.canvasView.currentColor, matchesColor: pickedColor)
            let recentColorRecorded = self.contentPicker.recentColors.contains { self.color($0, matchesColor: pickedColor) }

            let result: [String: Any] = [
                "probe": "drawing-tools",
                "passed": !initialVisible
                    && !initialCanUndo
                    && !initialCanRedo
                    && palette24Count == 24
                    && palette24ButtonActive
                    && palette36Count == 36
                    && palette36ButtonActive
                    && selectedColorApplied
                    && selectedColorHighlighted
                    && afterBrushVisible
                    && afterBrushCanUndo
                    && afterEraserVisible
                    && afterEraserCanUndo
                    && eraserChangedCanvas
                    && lineArtItem != nil
                    && lineArtLoaded
                    && afterLineArtVisible
                    && afterLineArtToolIsFill
                    && !afterLineArtCanUndo
                    && !afterLineArtCanRedo
                    && fillSucceeded
                    && afterFillVisible
                    && afterFillCanUndo
                    && fillChangedCanvas
                    && pickedColorMatchesFill
                    && currentColorMatchesPicked
                    && recentColorRecorded,
                "initialVisible": initialVisible,
                "initialCanUndo": initialCanUndo,
                "initialCanRedo": initialCanRedo,
                "palette24Count": palette24Count,
                "palette24ButtonActive": palette24ButtonActive,
                "palette36Count": palette36Count,
                "palette36ButtonActive": palette36ButtonActive,
                "selectedColorApplied": selectedColorApplied,
                "selectedColorHighlighted": selectedColorHighlighted,
                "afterBrushVisible": afterBrushVisible,
                "afterBrushCanUndo": afterBrushCanUndo,
                "afterEraserVisible": afterEraserVisible,
                "afterEraserCanUndo": afterEraserCanUndo,
                "eraserChangedCanvas": eraserChangedCanvas,
                "lineArtItemId": lineArtItem?.id ?? "",
                "lineArtLoaded": lineArtLoaded,
                "afterLineArtVisible": afterLineArtVisible,
                "afterLineArtToolIsFill": afterLineArtToolIsFill,
                "afterLineArtCanUndo": afterLineArtCanUndo,
                "afterLineArtCanRedo": afterLineArtCanRedo,
                "fillSucceeded": fillSucceeded,
                "afterFillVisible": afterFillVisible,
                "afterFillCanUndo": afterFillCanUndo,
                "fillChangedCanvas": fillChangedCanvas,
                "pickedColorMatchesFill": pickedColorMatchesFill,
                "currentColorMatchesPicked": currentColorMatchesPicked,
                "recentColorRecorded": recentColorRecorded
            ]
            self.writeRuntimeAcceptanceResult(result, fileName: "kc_runtime_acceptance_drawing_tools.json")
        }

        if let lineArtItem {
            self.loadLineArtItem(lineArtItem) { loaded in
                finishProbe(lineArtItem, loaded)
            }
        } else {
            finishProbe(nil, false)
        }
    }

    private func runSystemUIPresentationAcceptanceProbe() {
        self.view.layoutIfNeeded()
        let initialColor = self.canvasView.currentColor

        self.presentCustomColorPicker(animated: false) { [weak self] colorPicker in
            self?.finishColorPickerSystemUIProbe(initialColor: initialColor, colorPicker: colorPicker)
        }
    }

    private func finishColorPickerSystemUIProbe(initialColor: UIColor, colorPicker: UIColorPickerViewController) {
        let colorPickerPresented = true
        let colorPickerDelegateSet = colorPicker.delegate != nil
        let colorPickerInitialColorMatches = self.color(colorPicker.selectedColor, matchesColor: initialColor)
        let colorPickerPopoverSourceIsCustomButton = colorPicker.popoverPresentationController?.sourceView === self.customColorButton
        let colorPickerUsesPopoverPresentation = colorPicker.modalPresentationStyle == .popover
        let simulatedSystemColor = UIColor(red: 0.28, green: 0.62, blue: 0.91, alpha: 1.0)
        colorPicker.selectedColor = simulatedSystemColor
        self.colorPickerViewControllerDidSelectColor(colorPicker)
        self.colorPickerViewControllerDidFinish(colorPicker)
        let colorPickerSelectionApplied = self.color(self.canvasView.currentColor, matchesColor: simulatedSystemColor)
        let colorPickerSelectionRecorded = self.contentPicker.recentColors.contains { self.color($0, matchesColor: simulatedSystemColor) }

        self.dismiss(animated: false) { [weak self] in
            guard let self = self else { return }
            let photoLibraryAvailable = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
            if !self.presentPhotoLibraryPicker(animated: false, completion: { [weak self] imagePicker in
                self?.finishSystemUIPresentationAcceptanceProbe(
                    colorPickerPresented: colorPickerPresented,
                    colorPickerDelegateSet: colorPickerDelegateSet,
                    colorPickerInitialColorMatches: colorPickerInitialColorMatches,
                    colorPickerPopoverSourceIsCustomButton: colorPickerPopoverSourceIsCustomButton,
                    colorPickerUsesPopoverPresentation: colorPickerUsesPopoverPresentation,
                    colorPickerSelectionApplied: colorPickerSelectionApplied,
                    colorPickerSelectionRecorded: colorPickerSelectionRecorded,
                    photoLibraryAvailable: photoLibraryAvailable,
                    imagePicker: imagePicker
                )
            }) {
                self.finishSystemUIPresentationAcceptanceProbe(
                    colorPickerPresented: colorPickerPresented,
                    colorPickerDelegateSet: colorPickerDelegateSet,
                    colorPickerInitialColorMatches: colorPickerInitialColorMatches,
                    colorPickerPopoverSourceIsCustomButton: colorPickerPopoverSourceIsCustomButton,
                    colorPickerUsesPopoverPresentation: colorPickerUsesPopoverPresentation,
                    colorPickerSelectionApplied: colorPickerSelectionApplied,
                    colorPickerSelectionRecorded: colorPickerSelectionRecorded,
                    photoLibraryAvailable: photoLibraryAvailable,
                    imagePicker: nil
                )
            }
        }
    }

    private func finishSystemUIPresentationAcceptanceProbe(
        colorPickerPresented: Bool,
        colorPickerDelegateSet: Bool,
        colorPickerInitialColorMatches: Bool,
        colorPickerPopoverSourceIsCustomButton: Bool,
        colorPickerUsesPopoverPresentation: Bool,
        colorPickerSelectionApplied: Bool,
        colorPickerSelectionRecorded: Bool,
        photoLibraryAvailable: Bool,
        imagePicker: UIImagePickerController?
    ) {
        let imagePickerPresented = imagePicker != nil
        let imagePickerUsesPhotoLibrary = imagePicker?.sourceType == .photoLibrary
        let imagePickerDelegateSet = imagePicker?.delegate != nil
        let writeResult: () -> Void = { [weak self] in
            self?.writeSystemUIPresentationAcceptanceResult(
                colorPickerPresented: colorPickerPresented,
                colorPickerDelegateSet: colorPickerDelegateSet,
                colorPickerInitialColorMatches: colorPickerInitialColorMatches,
                colorPickerPopoverSourceIsCustomButton: colorPickerPopoverSourceIsCustomButton,
                colorPickerUsesPopoverPresentation: colorPickerUsesPopoverPresentation,
                colorPickerSelectionApplied: colorPickerSelectionApplied,
                colorPickerSelectionRecorded: colorPickerSelectionRecorded,
                photoLibraryAvailable: photoLibraryAvailable,
                imagePickerPresented: imagePickerPresented,
                imagePickerUsesPhotoLibrary: imagePickerUsesPhotoLibrary,
                imagePickerDelegateSet: imagePickerDelegateSet
            )
        }
        if let imagePicker {
            self.runtimeAcceptanceImageImportCompletion = writeResult
            self.imagePickerController(
                imagePicker,
                didFinishPickingMediaWithInfo: [
                    .originalImage: self.runtimeAcceptanceImportImage()
                ]
            )
        } else {
            writeResult()
        }
    }

    private func writeSystemUIPresentationAcceptanceResult(
        colorPickerPresented: Bool,
        colorPickerDelegateSet: Bool,
        colorPickerInitialColorMatches: Bool,
        colorPickerPopoverSourceIsCustomButton: Bool,
        colorPickerUsesPopoverPresentation: Bool,
        colorPickerSelectionApplied: Bool,
        colorPickerSelectionRecorded: Bool,
        photoLibraryAvailable: Bool,
        imagePickerPresented: Bool,
        imagePickerUsesPhotoLibrary: Bool,
        imagePickerDelegateSet: Bool
    ) {
        let imageImportVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let imageImportActiveSessionCleared = self.activeSession == nil
        let imageImportSelectedHistoryCleared = self.selectedHistorySession == nil
        let imageImportStartsClean = !self.activeSessionHasUnsavedChanges
            && !self.canvasView.canUndo()
            && !self.canvasView.canRedo()

        let result: [String: Any] = [
            "probe": "system-ui",
            "passed": colorPickerPresented
                && colorPickerDelegateSet
                && colorPickerInitialColorMatches
                && colorPickerPopoverSourceIsCustomButton
                && colorPickerUsesPopoverPresentation
                && colorPickerSelectionApplied
                && colorPickerSelectionRecorded
                && photoLibraryAvailable
                && imagePickerPresented
                && imagePickerUsesPhotoLibrary
                && imagePickerDelegateSet
                && imageImportVisible
                && imageImportActiveSessionCleared
                && imageImportSelectedHistoryCleared
                && imageImportStartsClean,
            "colorPickerPresented": colorPickerPresented,
            "colorPickerDelegateSet": colorPickerDelegateSet,
            "colorPickerInitialColorMatches": colorPickerInitialColorMatches,
            "colorPickerPopoverSourceIsCustomButton": colorPickerPopoverSourceIsCustomButton,
            "colorPickerUsesPopoverPresentation": colorPickerUsesPopoverPresentation,
            "colorPickerSelectionApplied": colorPickerSelectionApplied,
            "colorPickerSelectionRecorded": colorPickerSelectionRecorded,
            "photoLibraryAvailable": photoLibraryAvailable,
            "imagePickerPresented": imagePickerPresented,
            "imagePickerUsesPhotoLibrary": imagePickerUsesPhotoLibrary,
            "imagePickerDelegateSet": imagePickerDelegateSet,
            "imageImportVisible": imageImportVisible,
            "imageImportActiveSessionCleared": imageImportActiveSessionCleared,
            "imageImportSelectedHistoryCleared": imageImportSelectedHistoryCleared,
            "imageImportStartsClean": imageImportStartsClean
        ]
        self.writeRuntimeAcceptanceResult(result, fileName: "kc_runtime_acceptance_system_ui.json")
        self.resetRuntimeAcceptanceCanvasState()
        self.dismiss(animated: false, completion: nil)
    }

    private func runtimeAcceptanceImportImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320.0, height: 240.0))
        return renderer.image { context in
            UIColor(red: 0.99, green: 0.88, blue: 0.38, alpha: 1.0).setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 320.0, height: 240.0))
            UIColor(red: 0.24, green: 0.58, blue: 0.92, alpha: 1.0).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 96.0, y: 56.0, width: 128.0, height: 128.0))
        }
    }

    private func resetRuntimeAcceptanceCanvasState() {
        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.invalidateDraftSaveTimer()
        self.suppressNextDraftSave = true
        self.canvasView.startBlankCanvas()
        self.clearDraftAndInvalidateCurrentDraftMarker()
        self.refreshHistoryUI()
        self.refreshActionButtons()
    }

    private func runtimeAcceptanceSnapshotData() -> Data {
        self.view.layoutIfNeeded()
        self.canvasView.layoutIfNeeded()
        return self.canvasView.snapshotImage().pngData() ?? Data()
    }

    private enum LayoutEdge {
        case left
        case right
        case top
        case bottom
    }

    private func layoutCheckResult(name: String, view: UIView?, boundary: CGRect, edges: [LayoutEdge]) -> [String: Any] {
        guard let view = view else {
            return [
                "name": name,
                "passed": false,
                "reason": "missing-view"
            ]
        }

        let frame = view.convert(view.bounds, to: self.view)
        let tolerance: CGFloat = 1.0
        var violations: [String] = []
        for edge in edges {
            switch edge {
            case .left where frame.minX < boundary.minX - tolerance:
                violations.append("left")
            case .right where frame.maxX > boundary.maxX + tolerance:
                violations.append("right")
            case .top where frame.minY < boundary.minY - tolerance:
                violations.append("top")
            case .bottom where frame.maxY > boundary.maxY + tolerance:
                violations.append("bottom")
            default:
                break
            }
        }

        return [
            "name": name,
            "passed": violations.isEmpty,
            "frame": self.dictionary(for: frame),
            "checkedEdges": edges.map { self.name(for: $0) },
            "violations": violations
        ]
    }

    private func visibleHeightCheckResult(name: String, view: UIView?, minimumHeight: CGFloat) -> [String: Any] {
        guard let view = view else {
            return [
                "name": name,
                "passed": false,
                "reason": "missing-view",
                "minimumHeight": minimumHeight
            ]
        }

        let frame = view.convert(view.bounds, to: self.view)
        return [
            "name": name,
            "passed": frame.height >= minimumHeight,
            "frame": self.dictionary(for: frame),
            "minimumHeight": minimumHeight
        ]
    }

    private func dictionary(for rect: CGRect) -> [String: CGFloat] {
        return [
            "x": rect.origin.x,
            "y": rect.origin.y,
            "width": rect.size.width,
            "height": rect.size.height,
            "minX": rect.minX,
            "minY": rect.minY,
            "maxX": rect.maxX,
            "maxY": rect.maxY
        ]
    }

    private func name(for edge: LayoutEdge) -> String {
        switch edge {
        case .left:
            return "left"
        case .right:
            return "right"
        case .top:
            return "top"
        case .bottom:
            return "bottom"
        }
    }

    private func writeRuntimeAcceptanceResult(_ result: [String: Any], fileName: String) {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let resultURL = documentsURL.appendingPathComponent(fileName)
        guard JSONSerialization.isValidJSONObject(result),
              let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? data.write(to: resultURL, options: [.atomic])
    }
#endif

    // MARK: - 草稿自动保存

    func scheduleStartupDeferredWorkIfNeeded() {
        guard !self.didScheduleStartupDeferredWork else { return }
        self.didScheduleStartupDeferredWork = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshHistorySessionsAsync(loadDraftThumbnail: false)
            self.restoreDraftIfNeeded()
        }
    }

    func restoreDraftIfNeeded() {
        if self.activeSession != nil {
            return
        }

        let generation = self.nextArtworkLoadGeneration()
        self.draftPersistenceQueue.async { [weak self] in
            guard let self else { return }
            guard let data = self.sessionStore.loadDraftData(),
                  let draftImage = UIImage(data: data) else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.artworkLoadGeneration == generation else { return }
                guard self.activeSession == nil else { return }
                guard !self.canvasFeature.hasVisibleContent(self.canvasView) else { return }

                self.sessionStore.cacheLoadedDraftImage(draftImage)
                self.suppressNextDraftSave = true
                self.canvasView.restoreCanvas(with: draftImage)
                self.activeDraftMatchesCanvas = true
                self.refreshHistoryUI()
                self.refreshActionButtons()
            }
        }
    }

    func invalidateDraftSaveTimer() {
        self.draftSaveTimer?.invalidate()
        self.draftSaveTimer = nil
        self.nextDraftSaveGeneration()
    }

    @discardableResult
    func nextDraftSaveGeneration() -> Int {
        self.draftGenerationLock.lock()
        defer { self.draftGenerationLock.unlock() }
        self.draftSaveGeneration += 1
        return self.draftSaveGeneration
    }

    @discardableResult
    func nextDraftProtectionGeneration() -> Int {
        self.draftGenerationLock.lock()
        defer { self.draftGenerationLock.unlock() }
        self.draftProtectionGeneration += 1
        return self.draftProtectionGeneration
    }

    func isDraftSaveGenerationCurrent(_ generation: Int) -> Bool {
        self.draftGenerationLock.lock()
        defer { self.draftGenerationLock.unlock() }
        return self.draftSaveGeneration == generation
    }

    func isDraftProtectionGenerationCurrent(_ generation: Int) -> Bool {
        self.draftGenerationLock.lock()
        defer { self.draftGenerationLock.unlock() }
        return self.draftProtectionGeneration == generation
    }

    func invalidateSessionSaveWork() {
        self.sessionSaveGeneration += 1
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

    func scheduleDraftSave() {
        self.invalidateDraftSaveTimer()
        self.draftSaveTimer = Timer.scheduledTimer(timeInterval: 1.2, target: self, selector: #selector(handleDraftSaveTimer(_:)), userInfo: nil, repeats: false)
    }

    @objc func handleDraftSaveTimer(_ timer: Timer) {
        if timer !== self.draftSaveTimer {
            return
        }
        self.saveDraftIfNeeded()
    }

    func saveDraftIfNeeded() {
        self.invalidateDraftSaveTimer()

        if self.activeSession != nil && !self.activeSessionHasUnsavedChanges {
            self.refreshHistoryUI()
            return
        }

        if !self.canvasFeature.hasVisibleContent(self.canvasView) {
            self.clearDraftAndInvalidateCurrentDraftMarker()
            self.refreshHistoryUI()
            return
        }

        let snapshot = self.canvasView.snapshotImage()
        let generation = self.nextDraftSaveGeneration()
        self.draftPersistenceQueue.async { [weak self, snapshot] in
            guard let self else { return }
            let pngData = snapshot.pngData()

            guard self.isDraftSaveGenerationCurrent(generation) else { return }
            guard let pngData else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard self.isDraftSaveGenerationCurrent(generation) else { return }
                    self.refreshHistoryUI()
                }
                return
            }
            let saved = self.sessionStore.saveDraftData(pngData: pngData, cachedImage: snapshot)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.isDraftSaveGenerationCurrent(generation) else { return }
                self.activeDraftMatchesCanvas = saved
                if !saved {
                    self.clearDraftAndInvalidateCurrentDraftMarker()
                }
                self.refreshHistoryUI()
            }
        }
    }

    @objc func sceneWillResignActiveNotification(_ notification: Notification) {
        self.flushBrushWidthPreferenceSave()
        self.contentPicker.flushRecentColorSave()
        self.saveDraftIfNeeded()
    }

    @objc func sceneDidEnterBackgroundNotification(_ notification: Notification) {
        self.flushBrushWidthPreferenceSave()
        self.contentPicker.flushRecentColorSave()
        self.saveDraftIfNeeded()
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
