//
//  KCMainViewController.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/26.
//

import UIKit
import QuartzCore

// MARK: - 按压反馈 associated-object key

private var KDPressBaseTransformKey: UInt8 = 0
private var KDPressBaseAlphaKey: UInt8 = 0

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

// MARK: - KDLineArtItem

class KDLineArtItem: NSObject {
    var title: String
    var drawingBlock: ((CGRect) -> Void)?

    init(title: String, drawingBlock: @escaping (CGRect) -> Void) {
        self.title = title
        self.drawingBlock = drawingBlock
        super.init()
    }

    static func item(title: String, drawingBlock: @escaping (CGRect) -> Void) -> KDLineArtItem {
        KDLineArtItem(title: title, drawingBlock: drawingBlock)
    }
}

// MARK: - KCMainViewController

class KCMainViewController: UIViewController, KDDrawingCanvasViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIColorPickerViewControllerDelegate {

    var canvasContainerView: UIView!
    var canvasView: KCDrawingCanvasView!
    var sizeSlider: UISlider!
    var palette24: [UIColor]!
    var palette36: [UIColor]!
    var recentColors: [UIColor]!
    var stickerSymbolsByCategory: [String: [String]]!
    var stickerCategories: [String]!
    var selectedStickerCategory: String!
    var lineArtItems: [KDLineArtItem]!
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
    var sessions: [KCSessionMetadata] = []
    var activeSession: KCSessionMetadata?
    var selectedHistorySession: KCSessionMetadata?
    var panelsCollapsed: Bool = false
    var collapsiblePanels: [UIView] = []
    var collapseToggleButton: UIButton!
    var toolStateChip: UIView!
    var toolStateSwatch: UIView!
    var toolStateLabel: UILabel!
    var showing36Palette: Bool = false
    var historyPageIndex: Int = 0
    var draftSaveTimer: Timer?
    var suppressNextDraftSave: Bool = false
    var activeSessionHasUnsavedChanges: Bool = false
    var lineArtStrokeScale: CGFloat = 1.0
    var brushWidthsByStyle: [Int: CGFloat] = [:]
    var eraserSliderValue: CGFloat = 0.0

    // MARK: - 视图生命周期

    /// 通过 Composition Root 注入依赖创建。避免控制器内部直接 `KCSessionService.shared`。
    init(sessionService: KCSessionService) {
        self.sessionStore = sessionService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable, message: "Use init(sessionService:) via KCAppCompositionRoot")
    required init?(coder: NSCoder) {
        fatalError("Use init(sessionService:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor(red: 0.97, green: 0.94, blue: 0.89, alpha: 1.0)
        self.lineArtStrokeScale = 1.0
        self.palette24 = self.makePalette24()
        self.palette36 = self.makePalette36()
        self.recentColors = self.loadRecentColors()
        self.stickerCategories = ["Animals", "Nature", "Decor", "Faces"]
        self.selectedStickerCategory = self.stickerCategories.first
        self.stickerSymbolsByCategory = [
            "Animals": ["butterfly.fill", "pawprint.fill", "tortoise.fill", "hare.fill"],
            "Nature": ["leaf.fill", "camera.macro", "sun.max.fill", "cloud.fill"],
            "Decor": ["star.fill", "heart.fill", "moon.stars.fill", "rainbow", "gift.fill"],
            "Faces": ["face.smiling.fill", "figure.2", "hand.thumbsup.fill", "sparkles"]
        ]
        self.lineArtItems = self.makeLineArtItems()
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
        self.selectColor(self.palette24.first!, sender: nil)
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

        self.canvasView = KCDrawingCanvasView()
        self.canvasView.translatesAutoresizingMaskIntoConstraints = false
        self.canvasView.delegate = self
        self.canvasView.clipsToBounds = true
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
        rightScrollView.clipsToBounds = false
        rightStack.axis = .vertical
        rightStack.spacing = 16.0

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
            leftRail.widthAnchor.constraint(equalToConstant: 96.0),

            rightScrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -40.0),
            rightScrollView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 150.0),
            rightScrollView.bottomAnchor.constraint(equalTo: bottomDock.topAnchor, constant: -16.0),
            rightScrollView.widthAnchor.constraint(equalToConstant: 272.0),

            rightStack.leadingAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.leadingAnchor, constant: 12.0),
            rightStack.trailingAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.trailingAnchor, constant: -12.0),
            rightStack.topAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.topAnchor, constant: 12.0),
            rightStack.bottomAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.bottomAnchor, constant: -12.0),
            rightStack.widthAnchor.constraint(equalTo: rightScrollView.frameLayoutGuide.widthAnchor, constant: -24.0),

            colorsPanel.widthAnchor.constraint(equalToConstant: 248.0),
            sizePanel.widthAnchor.constraint(equalToConstant: 248.0),
            historyPanel.widthAnchor.constraint(equalToConstant: 248.0),

            bottomDock.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            bottomDock.widthAnchor.constraint(equalToConstant: 560.0),
            bottomDock.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -22.0),
            bottomDock.heightAnchor.constraint(equalToConstant: 98.0)
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
        toggle.accessibilityLabel = "Hide Tools"
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
        self.panelsCollapsed = !self.panelsCollapsed
        self.applyPanelsCollapsedAnimated(true)
    }

    /// 隐藏或显示浮动面板。切换只改 `hidden`/`alpha`/userInteractionEnabled，
    /// 所有约束保持不变，因此旋转、后台、打开历史都不会让控件错位，
    /// 也不触碰任何工具/颜色/橡皮/贴纸/撤销/保存状态。
    func applyPanelsCollapsedAnimated(_ animated: Bool) {
        self.refreshToolStateChip()

        let icon = UIImage(systemName: self.panelsCollapsed
                           ? "rectangle.expand.vertical"
                           : "rectangle.compress.vertical")
        self.collapseToggleButton.setImage(icon, for: .normal)
        self.collapseToggleButton.accessibilityLabel = self.panelsCollapsed ? "Show Tools" : "Hide Tools"

        // 渐变过程中保留面板在视图层级中（已布局），在完成回调里再切换 hidden。
        // userInteractionEnabled 不可动画，故立即生效——收起的面板会立刻停止
        // 拦截画布触摸。
        for panel in self.collapsiblePanels {
            panel.isHidden = false
        }
        self.toolStateChip.isHidden = false

        let update: () -> Void = {
            for panel in self.collapsiblePanels {
                panel.alpha = self.panelsCollapsed ? 0.0 : 1.0
                panel.isUserInteractionEnabled = !self.panelsCollapsed
            }
            self.toolStateChip.alpha = self.panelsCollapsed ? 1.0 : 0.0
        }

        let finalize: () -> Void = {
            for panel in self.collapsiblePanels {
                panel.isHidden = self.panelsCollapsed
            }
            self.toolStateChip.isHidden = !self.panelsCollapsed
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

        var swatchColor: UIColor = self.canvasView.currentColor ?? UIColor(red: 0.94, green: 0.43, blue: 0.45, alpha: 1.0)
        switch self.canvasView.currentToolMode {
        case .eraser:
            swatchColor = UIColor(white: 1.0, alpha: 1.0)
        case .sticker:
            swatchColor = UIColor(red: 0.96, green: 0.85, blue: 0.48, alpha: 1.0)
        default:
            break
        }

        let title = KCDrawingEngineAdapter.toolStateChipTitle(
            toolMode: self.canvasView.currentToolMode.rawValue,
            brushStyle: self.canvasView.currentBrushStyle.rawValue
        )
        self.toolStateLabel.text = title
        self.toolStateSwatch.backgroundColor = swatchColor
    }

    func floatingPanel() -> UIView {
        let panel = UIView()
        panel.backgroundColor = UIColor.clear
        panel.layer.cornerRadius = 30.0
        panel.layer.shadowColor = UIColor(red: 0.34, green: 0.26, blue: 0.14, alpha: 1.0).cgColor
        panel.layer.shadowOpacity = 0.14
        panel.layer.shadowRadius = 26.0
        panel.layer.shadowOffset = CGSize(width: 0, height: 14)

        let effect = UIBlurEffect(style: .systemThinMaterialLight)
        let blurView = UIVisualEffectView(effect: effect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 30.0
        blurView.layer.masksToBounds = true
        blurView.layer.borderColor = UIColor(white: 1.0, alpha: 0.66).cgColor
        blurView.layer.borderWidth = 1.0
        blurView.contentView.backgroundColor = UIColor(white: 1.0, alpha: 0.28)
        panel.addSubview(blurView)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: panel.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
        ])

        return panel
    }

    func iconButtonWithSymbolName(_ symbolName: String, accentColor: UIColor?) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = accentColor ?? UIColor(white: 1.0, alpha: 0.76)
        button.layer.cornerRadius = 18.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        button.layer.shadowColor = UIColor(red: 0.47, green: 0.40, blue: 0.29, alpha: 1.0).cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 10.0
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        button.tintColor = UIColor(red: 0.19, green: 0.26, blue: 0.33, alpha: 1.0)
        let configuration = UIImage.SymbolConfiguration(pointSize: 20.0, weight: .bold)
        let image = UIImage(systemName: symbolName, withConfiguration: configuration)
        button.setImage(image, for: .normal)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 56.0),
            button.heightAnchor.constraint(equalToConstant: 50.0)
        ])
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
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 20.0
        button.clipsToBounds = true
        button.layer.borderWidth = 2.0
        button.layer.borderColor = UIColor(red: 0.17, green: 0.22, blue: 0.30, alpha: 0.08).cgColor
        button.backgroundColor = UIColor(red: 1.0, green: 0.995, blue: 0.98, alpha: 1.0)
        button.imageView?.contentMode = .scaleAspectFill
        button.layer.shadowColor = UIColor(red: 0.40, green: 0.32, blue: 0.22, alpha: 1.0).cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 10.0
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        let configuration = UIImage.SymbolConfiguration(pointSize: 24.0, weight: .semibold)
        let placeholder = UIImage(systemName: "photo", withConfiguration: configuration)?
            .withTintColor(UIColor(red: 0.62, green: 0.67, blue: 0.74, alpha: 0.52), renderingMode: .alwaysOriginal)
        button.setImage(placeholder, for: .normal)
        button.imageView?.contentMode = .center
        self.registerPressFeedbackForControl(button)
        return button
    }

    func railToolButtonWithSymbolName(_ symbolName: String, slim: Bool) -> KDToolButton {
        let button = KDToolButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = UIColor(red: 0.19, green: 0.26, blue: 0.33, alpha: 1.0)
        button.backgroundColor = slim
            ? UIColor(red: 0.96, green: 0.85, blue: 0.48, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 0.82)
        button.layer.cornerRadius = slim ? 18.0 : 24.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        button.layer.shadowColor = UIColor(red: 0.47, green: 0.40, blue: 0.29, alpha: 1.0).cgColor
        button.layer.shadowOpacity = 0.1
        button.layer.shadowRadius = 10.0
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        let configuration = UIImage.SymbolConfiguration(pointSize: slim ? 18.0 : 22.0, weight: .bold)
        let image = UIImage(systemName: symbolName, withConfiguration: configuration)
        button.setImage(image, for: .normal)

        let height: CGFloat = slim ? 42.0 : 68.0
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 68.0),
            button.heightAnchor.constraint(equalToConstant: height)
        ])
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
        self.applyAccessibilityLabel("Open Latest", identifier: "top.open-latest", toControl: historyButton)
        self.applyAccessibilityLabel("Line Art", identifier: "top.line-art", toControl: lineArtButton)
        self.applyAccessibilityLabel("Import Photo", identifier: "top.import-photo", toControl: importButton)
        self.applyAccessibilityLabel("Save", identifier: "top.save", toControl: self.saveButton)

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
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12.0
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14.0),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14.0),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14.0),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14.0)
        ])

        let items: [(symbol: String, mode: KDToolMode, label: String)] = [
            ("pencil.tip", .brush, "Brush"),
            ("eraser", .eraser, "Eraser"),
            ("paintbrush.pointed", .fill, "Fill"),
            ("star.circle", .sticker, "Sticker"),
            ("eyedropper.halffull", .picker, "Eyedropper")
        ]

        for item in items {
            let slim = item.mode == .picker
            let button = self.railToolButtonWithSymbolName(item.symbol, slim: slim)
            button.toolMode = item.mode
            self.applyAccessibilityLabel(item.label, identifier: "tool.\(item.label.lowercased())", toControl: button)
            button.addTarget(self, action: #selector(didTapToolButton(_:)), for: .touchUpInside)

            self.toolButtons.append(button)
            stack.addArrangedSubview(button)
        }
    }

    func buildColorsPanel(_ panel: UIView) {
        let titleLabel = self.panelTitleLabel("Colors")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)

        let segmentContainer = UIView()
        segmentContainer.translatesAutoresizingMaskIntoConstraints = false
        segmentContainer.backgroundColor = UIColor(white: 1.0, alpha: 0.76)
        segmentContainer.layer.cornerRadius = 18.0
        panel.addSubview(segmentContainer)

        self.palette24Button = self.segmentButtonWithTitle("24", active: true)
        self.palette36Button = self.segmentButtonWithTitle("36", active: false)
        self.applyAccessibilityLabel("24 Colors", identifier: "palette.24", toControl: self.palette24Button)
        self.applyAccessibilityLabel("36 Colors", identifier: "palette.36", toControl: self.palette36Button)
        self.palette24Button.addTarget(self, action: #selector(didTapPalette24), for: .touchUpInside)
        self.palette36Button.addTarget(self, action: #selector(didTapPalette36), for: .touchUpInside)
        segmentContainer.addSubview(self.palette24Button)
        segmentContainer.addSubview(self.palette36Button)

        let grid = UIView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.tag = 701
        panel.addSubview(grid)

        let customButton = UIButton(type: .system)
        self.customColorButton = customButton
        customButton.translatesAutoresizingMaskIntoConstraints = false
        customButton.setTitle("Custom", for: .normal)
        customButton.titleLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: .bold)
        customButton.setTitleColor(UIColor(red: 0.23, green: 0.28, blue: 0.35, alpha: 1.0), for: .normal)
        customButton.backgroundColor = UIColor(white: 1.0, alpha: 0.82)
        customButton.layer.cornerRadius = 18.0
        customButton.layer.borderWidth = 1.0
        customButton.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        self.applyAccessibilityLabel("Custom Color", identifier: "palette.custom-color", toControl: customButton)
        customButton.addTarget(self, action: #selector(didTapCustomColor), for: .touchUpInside)
        self.registerPressFeedbackForControl(customButton)
        panel.addSubview(customButton)

        let recentScrollView = UIScrollView()
        recentScrollView.translatesAutoresizingMaskIntoConstraints = false
        recentScrollView.showsHorizontalScrollIndicator = false
        recentScrollView.alwaysBounceHorizontal = true
        recentScrollView.clipsToBounds = false
        panel.addSubview(recentScrollView)

        let recentRow = UIStackView()
        recentRow.translatesAutoresizingMaskIntoConstraints = false
        recentRow.axis = .horizontal
        recentRow.spacing = 8.0
        recentRow.distribution = .equalSpacing
        recentRow.tag = 702
        recentScrollView.addSubview(recentRow)
        self.recentColorRowStack = recentRow

        let ringView = UIView()
        ringView.translatesAutoresizingMaskIntoConstraints = false
        ringView.layer.cornerRadius = 22.0
        ringView.backgroundColor = UIColor(patternImage: self.colorWheelImage())
        panel.addSubview(ringView)

        let ringHole = UIView()
        ringHole.translatesAutoresizingMaskIntoConstraints = false
        ringHole.backgroundColor = UIColor(white: 1.0, alpha: 0.94)
        ringHole.layer.cornerRadius = 14.0
        ringView.addSubview(ringHole)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18.0),

            segmentContainer.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            segmentContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12.0),
            segmentContainer.widthAnchor.constraint(equalToConstant: 146.0),
            segmentContainer.heightAnchor.constraint(equalToConstant: 42.0),

            self.palette24Button.leadingAnchor.constraint(equalTo: segmentContainer.leadingAnchor, constant: 6.0),
            self.palette24Button.centerYAnchor.constraint(equalTo: segmentContainer.centerYAnchor),
            self.palette24Button.widthAnchor.constraint(equalToConstant: 68.0),
            self.palette24Button.heightAnchor.constraint(equalToConstant: 32.0),

            self.palette36Button.trailingAnchor.constraint(equalTo: segmentContainer.trailingAnchor, constant: -6.0),
            self.palette36Button.centerYAnchor.constraint(equalTo: segmentContainer.centerYAnchor),
            self.palette36Button.widthAnchor.constraint(equalToConstant: 68.0),
            self.palette36Button.heightAnchor.constraint(equalToConstant: 32.0),

            grid.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            grid.topAnchor.constraint(equalTo: segmentContainer.bottomAnchor, constant: 14.0),
            grid.widthAnchor.constraint(equalToConstant: self.paletteGridWidth()),

            customButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            customButton.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 12.0),
            customButton.widthAnchor.constraint(equalToConstant: 92.0),
            customButton.heightAnchor.constraint(equalToConstant: 36.0),

            recentScrollView.leadingAnchor.constraint(equalTo: customButton.trailingAnchor, constant: 12.0),
            recentScrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            recentScrollView.centerYAnchor.constraint(equalTo: customButton.centerYAnchor),
            recentScrollView.heightAnchor.constraint(equalToConstant: 30.0),

            recentRow.leadingAnchor.constraint(equalTo: recentScrollView.contentLayoutGuide.leadingAnchor),
            recentRow.trailingAnchor.constraint(equalTo: recentScrollView.contentLayoutGuide.trailingAnchor),
            recentRow.topAnchor.constraint(equalTo: recentScrollView.contentLayoutGuide.topAnchor),
            recentRow.bottomAnchor.constraint(equalTo: recentScrollView.contentLayoutGuide.bottomAnchor),
            recentRow.heightAnchor.constraint(equalTo: recentScrollView.frameLayoutGuide.heightAnchor),

            ringView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            ringView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            ringView.topAnchor.constraint(equalTo: customButton.bottomAnchor, constant: 12.0),
            ringView.heightAnchor.constraint(equalToConstant: 64.0),
            ringView.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -18.0),

            ringHole.centerXAnchor.constraint(equalTo: ringView.centerXAnchor),
            ringHole.centerYAnchor.constraint(equalTo: ringView.centerYAnchor),
            ringHole.widthAnchor.constraint(equalToConstant: 28.0),
            ringHole.heightAnchor.constraint(equalToConstant: 28.0)
        ])
        self.paletteGridHeightConstraint = grid.heightAnchor.constraint(equalToConstant: self.paletteGridHeightForColorCount(self.palette24.count))
        self.paletteGridHeightConstraint.isActive = true
        self.reloadRecentColorRow()
    }

    func buildSizePanel(_ panel: UIView) {
        let titleLabel = self.panelTitleLabel("Brush / Sticker")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)

        let shell = UIView()
        shell.translatesAutoresizingMaskIntoConstraints = false
        shell.backgroundColor = UIColor(white: 1.0, alpha: 0.58)
        shell.layer.cornerRadius = 24.0
        panel.addSubview(shell)

        self.sizeSlider = UISlider()
        self.sizeSlider.translatesAutoresizingMaskIntoConstraints = false
        self.sizeSlider.minimumValue = 4.0
        self.sizeSlider.maximumValue = 36.0
        self.sizeSlider.value = 12.0
        self.sizeSlider.minimumTrackTintColor = UIColor(red: 0.93, green: 0.83, blue: 0.46, alpha: 1.0)
        self.sizeSlider.maximumTrackTintColor = UIColor(red: 0.91, green: 0.66, blue: 0.45, alpha: 0.42)
        self.sizeSlider.accessibilityLabel = "Brush Size"
        self.sizeSlider.accessibilityIdentifier = "size.slider"
        self.sizeSlider.addTarget(self, action: #selector(didChangeSizeSlider(_:)), for: .valueChanged)
        shell.addSubview(self.sizeSlider)

        self.sizePreviewView = UIView()
        self.sizePreviewView.translatesAutoresizingMaskIntoConstraints = false
        self.sizePreviewView.backgroundColor = UIColor(white: 1.0, alpha: 0.72)
        self.sizePreviewView.layer.cornerRadius = 24.0
        self.sizePreviewView.layer.borderWidth = 1.0
        self.sizePreviewView.layer.borderColor = UIColor(white: 1.0, alpha: 0.74).cgColor
        shell.addSubview(self.sizePreviewView)

        self.sizePreviewShapeLayer = CAShapeLayer()
        self.sizePreviewShapeLayer.lineCap = .round
        self.sizePreviewShapeLayer.lineJoin = .round
        self.sizePreviewView.layer.addSublayer(self.sizePreviewShapeLayer)

        let dots = UIStackView()
        dots.translatesAutoresizingMaskIntoConstraints = false
        dots.axis = .horizontal
        dots.distribution = .equalSpacing
        dots.alignment = .bottom
        shell.addSubview(dots)

        let sizes: [CGFloat] = [8.0, 14.0, 20.0, 28.0]
        for size in sizes {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = UIColor(red: 0.91, green: 0.64, blue: 0.42, alpha: 1.0)
            dot.layer.cornerRadius = size / 2.0
            dot.widthAnchor.constraint(equalToConstant: size).isActive = true
            dot.heightAnchor.constraint(equalToConstant: size).isActive = true
            dots.addArrangedSubview(dot)
        }

        let stickerTitle = self.panelTitleLabel("Stickers")
        stickerTitle.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stickerTitle)

        let stickerCategoryRow = UIStackView()
        stickerCategoryRow.translatesAutoresizingMaskIntoConstraints = false
        stickerCategoryRow.axis = .horizontal
        stickerCategoryRow.spacing = 8.0
        stickerCategoryRow.distribution = .fillEqually
        panel.addSubview(stickerCategoryRow)

        for category in self.stickerCategories {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            let configuration = UIImage.SymbolConfiguration(pointSize: 15.0, weight: .bold)
            let categoryImage = UIImage(systemName: self.stickerCategorySymbolForCategory(category), withConfiguration: configuration) ?? self.safeSystemImageNamed("star.fill")
            button.setImage(categoryImage, for: .normal)
            button.accessibilityLabel = "\(category) Stickers"
            button.accessibilityIdentifier = "sticker.category.\(category.lowercased())"
            button.tintColor = UIColor(red: 0.47, green: 0.52, blue: 0.58, alpha: 1.0)
            button.backgroundColor = UIColor(white: 1.0, alpha: 0.62)
            button.layer.cornerRadius = 15.0
            button.layer.borderWidth = 1.0
            button.layer.borderColor = UIColor(white: 1.0, alpha: 0.70).cgColor
            button.addTarget(self, action: #selector(didTapStickerCategoryButton(_:)), for: .touchUpInside)
            self.registerPressFeedbackForControl(button)
            stickerCategoryRow.addArrangedSubview(button)
            self.stickerCategoryButtons.append(button)
        }

        let stickerScrollView = UIScrollView()
        stickerScrollView.translatesAutoresizingMaskIntoConstraints = false
        stickerScrollView.showsHorizontalScrollIndicator = false
        stickerScrollView.alwaysBounceHorizontal = true
        stickerScrollView.clipsToBounds = false
        panel.addSubview(stickerScrollView)

        let stickerRow = UIStackView()
        stickerRow.translatesAutoresizingMaskIntoConstraints = false
        stickerRow.axis = .horizontal
        stickerRow.spacing = 10.0
        stickerRow.distribution = .fill
        stickerScrollView.addSubview(stickerRow)
        self.stickerRowStack = stickerRow

        let eraserTitle = self.panelTitleLabel("Eraser")
        eraserTitle.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(eraserTitle)

        let eraserRow = UIStackView()
        eraserRow.translatesAutoresizingMaskIntoConstraints = false
        eraserRow.axis = .horizontal
        eraserRow.spacing = 10.0
        eraserRow.distribution = .fillEqually
        panel.addSubview(eraserRow)

        self.circleEraserButton = self.smallToolButtonWithSymbolName("circle.fill", accent: false)
        self.cloudEraserButton = self.smallToolButtonWithSymbolName("cloud.fill", accent: false)
        self.starEraserButton = self.smallToolButtonWithSymbolName("star.fill", accent: false)
        self.applyAccessibilityLabel("Circle Eraser", identifier: "eraser.circle", toControl: self.circleEraserButton)
        self.applyAccessibilityLabel("Cloud Eraser", identifier: "eraser.cloud", toControl: self.cloudEraserButton)
        self.applyAccessibilityLabel("Star Eraser", identifier: "eraser.star", toControl: self.starEraserButton)
        self.circleEraserButton.addTarget(self, action: #selector(didTapCircleEraser), for: .touchUpInside)
        self.cloudEraserButton.addTarget(self, action: #selector(didTapCloudEraser), for: .touchUpInside)
        self.starEraserButton.addTarget(self, action: #selector(didTapStarEraser), for: .touchUpInside)
        eraserRow.addArrangedSubview(self.circleEraserButton)
        eraserRow.addArrangedSubview(self.cloudEraserButton)
        eraserRow.addArrangedSubview(self.starEraserButton)

        let editTitle = self.panelTitleLabel("Sticker Edit")
        editTitle.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(editTitle)

        let editRow = UIStackView()
        editRow.translatesAutoresizingMaskIntoConstraints = false
        editRow.axis = .horizontal
        editRow.spacing = 10.0
        editRow.distribution = .fillEqually
        panel.addSubview(editRow)

        self.frontStickerButton = self.smallToolButtonWithSymbolName("square.2.layers.3d.top.filled", accent: false)
        self.deleteStickerButton = self.smallToolButtonWithSymbolName("trash.fill", accent: false)
        self.applyAccessibilityLabel("Bring Sticker Forward", identifier: "sticker.bring-forward", toControl: self.frontStickerButton)
        self.applyAccessibilityLabel("Delete Sticker", identifier: "sticker.delete", toControl: self.deleteStickerButton)
        self.frontStickerButton.addTarget(self, action: #selector(didTapBringStickerFront), for: .touchUpInside)
        self.deleteStickerButton.addTarget(self, action: #selector(didTapDeleteSticker), for: .touchUpInside)
        editRow.addArrangedSubview(self.frontStickerButton)
        editRow.addArrangedSubview(self.deleteStickerButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18.0),

            shell.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            shell.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            shell.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12.0),

            self.sizeSlider.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14.0),
            self.sizeSlider.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -14.0),
            self.sizeSlider.topAnchor.constraint(equalTo: shell.topAnchor, constant: 18.0),

            self.sizePreviewView.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 16.0),
            self.sizePreviewView.topAnchor.constraint(equalTo: self.sizeSlider.bottomAnchor, constant: 14.0),
            self.sizePreviewView.widthAnchor.constraint(equalToConstant: 50.0),
            self.sizePreviewView.heightAnchor.constraint(equalToConstant: 50.0),

            dots.leadingAnchor.constraint(equalTo: self.sizePreviewView.trailingAnchor, constant: 18.0),
            dots.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -22.0),
            dots.topAnchor.constraint(equalTo: self.sizeSlider.bottomAnchor, constant: 16.0),
            dots.bottomAnchor.constraint(equalTo: shell.bottomAnchor, constant: -14.0),

            stickerTitle.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            stickerTitle.topAnchor.constraint(equalTo: shell.bottomAnchor, constant: 14.0),

            stickerCategoryRow.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            stickerCategoryRow.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            stickerCategoryRow.topAnchor.constraint(equalTo: stickerTitle.bottomAnchor, constant: 9.0),
            stickerCategoryRow.heightAnchor.constraint(equalToConstant: 32.0),

            stickerScrollView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            stickerScrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            stickerScrollView.topAnchor.constraint(equalTo: stickerCategoryRow.bottomAnchor, constant: 10.0),
            stickerScrollView.heightAnchor.constraint(equalToConstant: 48.0),

            stickerRow.leadingAnchor.constraint(equalTo: stickerScrollView.contentLayoutGuide.leadingAnchor),
            stickerRow.trailingAnchor.constraint(equalTo: stickerScrollView.contentLayoutGuide.trailingAnchor),
            stickerRow.topAnchor.constraint(equalTo: stickerScrollView.contentLayoutGuide.topAnchor),
            stickerRow.bottomAnchor.constraint(equalTo: stickerScrollView.contentLayoutGuide.bottomAnchor),
            stickerRow.heightAnchor.constraint(equalTo: stickerScrollView.frameLayoutGuide.heightAnchor),

            eraserTitle.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            eraserTitle.topAnchor.constraint(equalTo: stickerScrollView.bottomAnchor, constant: 14.0),

            eraserRow.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            eraserRow.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            eraserRow.topAnchor.constraint(equalTo: eraserTitle.bottomAnchor, constant: 10.0),

            editTitle.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            editTitle.topAnchor.constraint(equalTo: eraserRow.bottomAnchor, constant: 14.0),

            editRow.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            editRow.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            editRow.topAnchor.constraint(equalTo: editTitle.bottomAnchor, constant: 10.0),
            editRow.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -18.0)
        ])
    }

    func buildHistoryPanel(_ panel: UIView) {
        let titleLabel = self.panelTitleLabel("History")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)

        let draftLabel = UILabel()
        draftLabel.translatesAutoresizingMaskIntoConstraints = false
        draftLabel.text = "Draft"
        draftLabel.font = UIFont.systemFont(ofSize: 12.0, weight: .semibold)
        draftLabel.textColor = UIColor(red: 0.47, green: 0.52, blue: 0.58, alpha: 1.0)
        panel.addSubview(draftLabel)

        self.draftThumbButton = self.historyThumbButton()
        self.applyAccessibilityLabel("Draft Thumbnail", identifier: "history.draft", toControl: self.draftThumbButton)
        self.draftThumbButton.addTarget(self, action: #selector(didTapDraftThumb), for: .touchUpInside)
        panel.addSubview(self.draftThumbButton)

        let savedLabel = UILabel()
        savedLabel.translatesAutoresizingMaskIntoConstraints = false
        savedLabel.text = "Saved"
        savedLabel.font = UIFont.systemFont(ofSize: 12.0, weight: .semibold)
        savedLabel.textColor = UIColor(red: 0.47, green: 0.52, blue: 0.58, alpha: 1.0)
        panel.addSubview(savedLabel)

        for index in 0..<4 {
            let thumb = self.historyThumbButton()
            thumb.tag = index
            self.applyAccessibilityLabel("Saved Thumbnail \(index + 1)", identifier: "history.saved.\(index + 1)", toControl: thumb)
            thumb.addTarget(self, action: #selector(didTapHistoryThumb(_:)), for: .touchUpInside)
            panel.addSubview(thumb)
            self.historyThumbButtons.append(thumb)
        }

        self.previousHistoryButton = self.smallToolButtonWithSymbolName("chevron.left", accent: false)
        self.nextHistoryButton = self.smallToolButtonWithSymbolName("chevron.right", accent: false)
        self.applyAccessibilityLabel("Previous History Page", identifier: "history.previous-page", toControl: self.previousHistoryButton)
        self.applyAccessibilityLabel("Next History Page", identifier: "history.next-page", toControl: self.nextHistoryButton)
        self.previousHistoryButton.translatesAutoresizingMaskIntoConstraints = false
        self.nextHistoryButton.translatesAutoresizingMaskIntoConstraints = false
        self.previousHistoryButton.addTarget(self, action: #selector(didTapPreviousHistoryPage), for: .touchUpInside)
        self.nextHistoryButton.addTarget(self, action: #selector(didTapNextHistoryPage), for: .touchUpInside)
        panel.addSubview(self.previousHistoryButton)
        panel.addSubview(self.nextHistoryButton)

        let openButton = self.historyActionButtonWithTitle("Open", accent: false)
        let importButton = self.historyActionButtonWithTitle("Import", accent: true)
        self.deleteHistoryButton = self.historyActionButtonWithTitle("Delete", accent: false)
        self.applyAccessibilityLabel("Open Latest", identifier: "history.open-latest", toControl: openButton)
        self.applyAccessibilityLabel("Import Photo", identifier: "history.import-photo", toControl: importButton)
        self.applyAccessibilityLabel("Delete Latest", identifier: "history.delete-latest", toControl: self.deleteHistoryButton)
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

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18.0),

            draftLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            draftLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12.0),

            self.draftThumbButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            self.draftThumbButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            self.draftThumbButton.topAnchor.constraint(equalTo: draftLabel.bottomAnchor, constant: 8.0),
            self.draftThumbButton.heightAnchor.constraint(equalToConstant: 86.0),

            savedLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            savedLabel.topAnchor.constraint(equalTo: self.draftThumbButton.bottomAnchor, constant: 12.0),

            thumbOne.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            thumbOne.topAnchor.constraint(equalTo: savedLabel.bottomAnchor, constant: 8.0),
            thumbOne.widthAnchor.constraint(equalToConstant: 92.0),
            thumbOne.heightAnchor.constraint(equalToConstant: 92.0),

            thumbTwo.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            thumbTwo.topAnchor.constraint(equalTo: savedLabel.bottomAnchor, constant: 8.0),
            thumbTwo.widthAnchor.constraint(equalToConstant: 92.0),
            thumbTwo.heightAnchor.constraint(equalToConstant: 92.0),

            thumbThree.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            thumbThree.topAnchor.constraint(equalTo: thumbOne.bottomAnchor, constant: 10.0),
            thumbThree.widthAnchor.constraint(equalToConstant: 92.0),
            thumbThree.heightAnchor.constraint(equalToConstant: 92.0),

            thumbFour.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            thumbFour.topAnchor.constraint(equalTo: thumbTwo.bottomAnchor, constant: 10.0),
            thumbFour.widthAnchor.constraint(equalToConstant: 92.0),
            thumbFour.heightAnchor.constraint(equalToConstant: 92.0),

            self.previousHistoryButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            self.previousHistoryButton.topAnchor.constraint(equalTo: thumbThree.bottomAnchor, constant: 12.0),
            self.previousHistoryButton.widthAnchor.constraint(equalToConstant: 46.0),

            self.nextHistoryButton.leadingAnchor.constraint(equalTo: self.previousHistoryButton.trailingAnchor, constant: 8.0),
            self.nextHistoryButton.topAnchor.constraint(equalTo: thumbThree.bottomAnchor, constant: 12.0),
            self.nextHistoryButton.widthAnchor.constraint(equalToConstant: 46.0),

            openButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18.0),
            openButton.topAnchor.constraint(equalTo: self.previousHistoryButton.bottomAnchor, constant: 10.0),
            openButton.widthAnchor.constraint(equalToConstant: 68.0),
            openButton.heightAnchor.constraint(equalToConstant: 38.0),

            importButton.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 8.0),
            importButton.topAnchor.constraint(equalTo: self.previousHistoryButton.bottomAnchor, constant: 10.0),
            importButton.widthAnchor.constraint(equalToConstant: 78.0),
            importButton.heightAnchor.constraint(equalToConstant: 38.0),

            self.deleteHistoryButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            self.deleteHistoryButton.topAnchor.constraint(equalTo: self.nextHistoryButton.bottomAnchor, constant: 10.0),
            self.deleteHistoryButton.widthAnchor.constraint(equalToConstant: 78.0),
            self.deleteHistoryButton.heightAnchor.constraint(equalToConstant: 38.0),
            self.deleteHistoryButton.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -18.0)
        ])
    }

    func buildBottomDock(_ panel: UIView) {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Brushes"
        label.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
        label.textColor = UIColor(red: 0.34, green: 0.39, blue: 0.45, alpha: 1.0)
        panel.addSubview(label)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = false
        panel.addSubview(scrollView)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12.0
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 22.0),
            label.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 88.0),

            scrollView.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8.0),
            scrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18.0),
            scrollView.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12.0),
            scrollView.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12.0),

            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let brushItems: [(title: String, style: KDBrushStyle, mode: KDToolMode, brush: Bool, symbol: String, accent: UIColor)] = [
            ("Pencil", .pencil, .brush, true, "pencil.tip", self.brushColorForTitle("Pencil")),
            ("Pen", .pen, .brush, true, "pencil", self.brushColorForTitle("Pen")),
            ("Crayon", .crayon, .brush, true, "paintbrush.pointed.fill", self.brushColorForTitle("Crayon"))
        ]

        for (index, item) in brushItems.enumerated() {
            let button = self.toolCardButtonWithSymbolName(item.symbol, accentColor: item.accent, title: item.title)
            button.brushStyle = item.style
            button.toolMode = item.mode
            button.representsBrushStyle = item.brush
            button.tag = index
            self.applyAccessibilityLabel(item.title, identifier: "dock.\(item.title.lowercased())", toControl: button)
            button.addTarget(self, action: #selector(didTapBrushButton(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            self.brushButtons.append(button)
        }
    }

    func addCanvasBadges() {
        let leftBadge = self.badgeLabelWithText("Canvas")
        let rightBadge = self.badgeLabelWithText("Line Art")
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
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 15.0, weight: .semibold)
        label.textColor = UIColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 1.0)
        return label
    }

    func strokePath(_ path: UIBezierPath, width: CGFloat) {
        path.lineWidth = width * self.lineArtStrokeScale
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    func segmentButtonWithTitle(_ title: String, active: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: .bold)
        button.setTitleColor(active ? UIColor(red: 0.39, green: 0.26, blue: 0.0, alpha: 1.0) : UIColor(red: 0.49, green: 0.53, blue: 0.59, alpha: 1.0), for: .normal)
        button.backgroundColor = active ? UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0) : UIColor.clear
        button.layer.cornerRadius = 16.0
        button.layer.borderWidth = active ? 1.0 : 0.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.76).cgColor
        self.registerPressFeedbackForControl(button)
        return button
    }

    func historyActionButtonWithTitle(_ title: String, accent: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: .bold)
        button.setTitleColor(accent ? UIColor(red: 0.39, green: 0.26, blue: 0.0, alpha: 1.0) : UIColor(red: 0.23, green: 0.28, blue: 0.35, alpha: 1.0), for: .normal)
        button.backgroundColor = accent ? UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0) : UIColor(white: 1.0, alpha: 0.82)
        button.layer.cornerRadius = 18.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        self.registerPressFeedbackForControl(button)
        return button
    }

    func smallToolButtonWithSymbolName(_ symbolName: String, accent: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = accent
            ? UIColor(red: 0.39, green: 0.26, blue: 0.0, alpha: 1.0)
            : UIColor(red: 0.23, green: 0.28, blue: 0.35, alpha: 1.0)
        button.backgroundColor = accent
            ? UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 0.82)
        button.layer.cornerRadius = 16.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        let configuration = UIImage.SymbolConfiguration(pointSize: 16.0, weight: .bold)
        let image = UIImage(systemName: symbolName, withConfiguration: configuration)
        button.setImage(image, for: .normal)
        button.heightAnchor.constraint(equalToConstant: 36.0).isActive = true
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
        let labels: [String: String] = [
            "star.fill": "Star Sticker",
            "heart.fill": "Heart Sticker",
            "sun.max.fill": "Sun Sticker",
            "leaf.fill": "Leaf Sticker",
            "cloud.fill": "Cloud Sticker",
            "moon.stars.fill": "Moon Sticker",
            "rainbow": "Rainbow Sticker",
            "camera.macro": "Flower Sticker",
            "butterfly.fill": "Butterfly Sticker",
            "pawprint.fill": "Paw Sticker",
            "gift.fill": "Gift Sticker",
            "face.smiling.fill": "Smile Sticker"
        ]
        return labels[symbol] ?? "Sticker"
    }

    func stickerCategorySymbolForCategory(_ category: String) -> String {
        let symbols: [String: String] = [
            "Animals": "pawprint.fill",
            "Nature": "leaf.fill",
            "Decor": "sparkles",
            "Faces": "face.smiling.fill"
        ]
        return symbols[category] ?? "star.fill"
    }

    func toolCardButtonWithSymbolName(_ symbolName: String, accentColor: UIColor, title: String) -> KDBrushButton {
        let button = KDBrushButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.84)
        button.layer.cornerRadius = 28.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        button.layer.shadowColor = UIColor(red: 0.47, green: 0.40, blue: 0.29, alpha: 1.0).cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 10.0
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        button.widthAnchor.constraint(equalToConstant: 126.0).isActive = true
        button.heightAnchor.constraint(equalToConstant: 68.0).isActive = true

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let configuration = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .bold)
        iconView.image = UIImage(systemName: symbolName, withConfiguration: configuration)?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = accentColor
        iconView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        label.textColor = UIColor(red: 0.16, green: 0.22, blue: 0.28, alpha: 1.0)

        let halo = UIView()
        halo.translatesAutoresizingMaskIntoConstraints = false
        halo.backgroundColor = accentColor.withAlphaComponent(0.16)
        halo.layer.cornerRadius = 18.0

        button.addSubview(halo)
        button.addSubview(iconView)
        button.addSubview(label)

        NSLayoutConstraint.activate([
            halo.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14.0),
            halo.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            halo.widthAnchor.constraint(equalToConstant: 36.0),
            halo.heightAnchor.constraint(equalToConstant: 36.0),
            iconView.centerXAnchor.constraint(equalTo: halo.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: halo.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22.0),
            iconView.heightAnchor.constraint(equalToConstant: 22.0),
            label.leadingAnchor.constraint(equalTo: halo.trailingAnchor, constant: 14.0),
            label.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])

        self.registerPressFeedbackForControl(button)
        return button
    }

    func brushColorForTitle(_ title: String) -> UIColor {
        if title == "Pencil" {
            return UIColor(red: 0.94, green: 0.43, blue: 0.45, alpha: 1.0)
        }
        if title == "Pen" {
            return UIColor(red: 0.45, green: 0.73, blue: 0.97, alpha: 1.0)
        }
        if title == "Crayon" {
            return UIColor(red: 0.93, green: 0.62, blue: 0.41, alpha: 1.0)
        }
        if title == "Eraser" {
            return UIColor(white: 0.88, alpha: 1.0)
        }
        if title == "Fill" {
            return UIColor(red: 0.95, green: 0.80, blue: 0.41, alpha: 1.0)
        }
        if title == "Picker" {
            return UIColor(red: 0.55, green: 0.54, blue: 0.95, alpha: 1.0)
        }
        return UIColor(red: 0.56, green: 0.84, blue: 0.63, alpha: 1.0)
    }

    // MARK: - 线稿项

    func makeLineArtItems() -> [KDLineArtItem] {
        weak var weakSelf = self
        let bunny = KDLineArtItem.item(title: "Bunny", drawingBlock: { (rect: CGRect) in
            let centerX = rect.midX
            let centerY = rect.midY + 18.0

            let leftEar = UIBezierPath(roundedRect: CGRect(x: centerX - 132.0, y: centerY - 220.0, width: 54.0, height: 150.0), cornerRadius: 28.0)
            let rightEar = UIBezierPath(roundedRect: CGRect(x: centerX + 78.0, y: centerY - 220.0, width: 54.0, height: 150.0), cornerRadius: 28.0)
            weakSelf?.strokePath(leftEar, width: 12.0)
            weakSelf?.strokePath(rightEar, width: 12.0)

            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: centerX - 138.0, y: centerY - 108.0, width: 276.0, height: 216.0)), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: centerX - 80.0, y: centerY - 18.0, width: 160.0, height: 120.0)), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: centerX - 88.0, y: centerY + 82.0, width: 72.0, height: 52.0)), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: centerX + 16.0, y: centerY + 82.0, width: 72.0, height: 52.0)), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: centerX - 86.0, y: centerY - 20.0, width: 36.0, height: 48.0)), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: centerX + 50.0, y: centerY - 20.0, width: 36.0, height: 48.0)), width: 12.0)

            let nose = UIBezierPath()
            nose.move(to: CGPoint(x: centerX, y: centerY + 20.0))
            nose.addLine(to: CGPoint(x: centerX - 24.0, y: centerY + 46.0))
            nose.addLine(to: CGPoint(x: centerX + 24.0, y: centerY + 46.0))
            nose.close()
            weakSelf?.strokePath(nose, width: 12.0)

            let mouth = UIBezierPath()
            mouth.move(to: CGPoint(x: centerX, y: centerY + 46.0))
            mouth.addCurve(to: CGPoint(x: centerX - 34.0, y: centerY + 72.0), controlPoint1: CGPoint(x: centerX - 2.0, y: centerY + 63.0), controlPoint2: CGPoint(x: centerX - 18.0, y: centerY + 76.0))
            mouth.move(to: CGPoint(x: centerX, y: centerY + 46.0))
            mouth.addCurve(to: CGPoint(x: centerX + 34.0, y: centerY + 72.0), controlPoint1: CGPoint(x: centerX + 2.0, y: centerY + 63.0), controlPoint2: CGPoint(x: centerX + 18.0, y: centerY + 76.0))
            weakSelf?.strokePath(mouth, width: 12.0)
        })

        let car = KDLineArtItem.item(title: "Car", drawingBlock: { (rect: CGRect) in
            let baseY = rect.maxY - 90.0
            let leftX = rect.minX + 80.0

            let body = UIBezierPath()
            body.move(to: CGPoint(x: leftX, y: baseY))
            body.addLine(to: CGPoint(x: leftX + 92.0, y: baseY - 94.0))
            body.addLine(to: CGPoint(x: leftX + 250.0, y: baseY - 94.0))
            body.addLine(to: CGPoint(x: leftX + 334.0, y: baseY))
            body.addLine(to: CGPoint(x: leftX + 402.0, y: baseY))
            body.addCurve(to: CGPoint(x: leftX + 456.0, y: baseY + 38.0), controlPoint1: CGPoint(x: leftX + 430.0, y: baseY), controlPoint2: CGPoint(x: leftX + 456.0, y: baseY + 10.0))
            body.addLine(to: CGPoint(x: leftX + 456.0, y: baseY + 86.0))
            body.addLine(to: CGPoint(x: leftX - 10.0, y: baseY + 86.0))
            body.addLine(to: CGPoint(x: leftX - 10.0, y: baseY + 24.0))
            body.addCurve(to: CGPoint(x: leftX, y: baseY), controlPoint1: CGPoint(x: leftX - 10.0, y: baseY + 10.0), controlPoint2: CGPoint(x: leftX - 4.0, y: baseY))
            body.close()
            weakSelf?.strokePath(body, width: 12.0)

            weakSelf?.strokePath(UIBezierPath(roundedRect: CGRect(x: leftX + 110.0, y: baseY - 78.0, width: 112.0, height: 76.0), cornerRadius: 18.0), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(roundedRect: CGRect(x: leftX + 232.0, y: baseY - 78.0, width: 90.0, height: 76.0), cornerRadius: 18.0), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: leftX + 52.0, y: baseY + 32.0, width: 96.0, height: 96.0)), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: leftX + 296.0, y: baseY + 32.0, width: 96.0, height: 96.0)), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: leftX + 76.0, y: baseY + 56.0, width: 48.0, height: 48.0)), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: leftX + 320.0, y: baseY + 56.0, width: 48.0, height: 48.0)), width: 12.0)
        })

        let fish = KDLineArtItem.item(title: "Fish", drawingBlock: { (rect: CGRect) in
            let centerX = rect.midX
            let centerY = rect.midY

            let body = UIBezierPath()
            body.move(to: CGPoint(x: centerX - 160.0, y: centerY))
            body.addCurve(to: CGPoint(x: centerX + 74.0, y: centerY - 118.0), controlPoint1: CGPoint(x: centerX - 126.0, y: centerY - 122.0), controlPoint2: CGPoint(x: centerX + 8.0, y: centerY - 150.0))
            body.addCurve(to: CGPoint(x: centerX + 74.0, y: centerY + 118.0), controlPoint1: CGPoint(x: centerX + 148.0, y: centerY - 80.0), controlPoint2: CGPoint(x: centerX + 148.0, y: centerY + 80.0))
            body.addCurve(to: CGPoint(x: centerX - 160.0, y: centerY), controlPoint1: CGPoint(x: centerX + 8.0, y: centerY + 150.0), controlPoint2: CGPoint(x: centerX - 126.0, y: centerY + 122.0))
            body.close()
            weakSelf?.strokePath(body, width: 12.0)

            let tail = UIBezierPath()
            tail.move(to: CGPoint(x: centerX + 74.0, y: centerY))
            tail.addLine(to: CGPoint(x: centerX + 208.0, y: centerY - 122.0))
            tail.addLine(to: CGPoint(x: centerX + 208.0, y: centerY + 122.0))
            tail.close()
            weakSelf?.strokePath(tail, width: 12.0)

            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: centerX - 96.0, y: centerY - 24.0, width: 46.0, height: 46.0)), width: 12.0)

            let fin = UIBezierPath()
            fin.move(to: CGPoint(x: centerX - 18.0, y: centerY - 26.0))
            fin.addCurve(to: CGPoint(x: centerX + 48.0, y: centerY - 118.0), controlPoint1: CGPoint(x: centerX - 12.0, y: centerY - 90.0), controlPoint2: CGPoint(x: centerX + 26.0, y: centerY - 112.0))
            fin.addCurve(to: CGPoint(x: centerX + 92.0, y: centerY - 30.0), controlPoint1: CGPoint(x: centerX + 74.0, y: centerY - 116.0), controlPoint2: CGPoint(x: centerX + 98.0, y: centerY - 72.0))
            fin.close()
            weakSelf?.strokePath(fin, width: 12.0)

            let smile = UIBezierPath()
            smile.move(to: CGPoint(x: centerX - 130.0, y: centerY + 18.0))
            smile.addCurve(to: CGPoint(x: centerX - 74.0, y: centerY + 42.0), controlPoint1: CGPoint(x: centerX - 116.0, y: centerY + 42.0), controlPoint2: CGPoint(x: centerX - 90.0, y: centerY + 54.0))
            weakSelf?.strokePath(smile, width: 12.0)
        })

        let flower = KDLineArtItem.item(title: "Flower", drawingBlock: { (rect: CGRect) in
            let centerX = rect.midX
            let centerY = rect.midY - 24.0
            let petalCenters: [CGPoint] = [
                CGPoint(x: centerX, y: centerY - 114.0),
                CGPoint(x: centerX + 94.0, y: centerY - 34.0),
                CGPoint(x: centerX + 58.0, y: centerY + 86.0),
                CGPoint(x: centerX - 58.0, y: centerY + 86.0),
                CGPoint(x: centerX - 94.0, y: centerY - 34.0)
            ]
            for point in petalCenters {
                weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: point.x - 54.0, y: point.y - 62.0, width: 108.0, height: 124.0)), width: 12.0)
            }

            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: centerX - 52.0, y: centerY - 52.0, width: 104.0, height: 104.0)), width: 12.0)

            let stem = UIBezierPath()
            stem.move(to: CGPoint(x: centerX, y: centerY + 54.0))
            stem.addCurve(to: CGPoint(x: centerX - 12.0, y: rect.maxY - 18.0), controlPoint1: CGPoint(x: centerX + 8.0, y: centerY + 136.0), controlPoint2: CGPoint(x: centerX - 18.0, y: centerY + 222.0))
            weakSelf?.strokePath(stem, width: 12.0)

            let leftLeaf = UIBezierPath()
            leftLeaf.move(to: CGPoint(x: centerX - 8.0, y: centerY + 166.0))
            leftLeaf.addCurve(to: CGPoint(x: centerX - 136.0, y: centerY + 136.0), controlPoint1: CGPoint(x: centerX - 38.0, y: centerY + 118.0), controlPoint2: CGPoint(x: centerX - 110.0, y: centerY + 112.0))
            leftLeaf.addCurve(to: CGPoint(x: centerX - 8.0, y: centerY + 166.0), controlPoint1: CGPoint(x: centerX - 114.0, y: centerY + 186.0), controlPoint2: CGPoint(x: centerX - 44.0, y: centerY + 194.0))
            leftLeaf.close()
            weakSelf?.strokePath(leftLeaf, width: 12.0)

            let rightLeaf = UIBezierPath()
            rightLeaf.move(to: CGPoint(x: centerX - 4.0, y: centerY + 232.0))
            rightLeaf.addCurve(to: CGPoint(x: centerX + 124.0, y: centerY + 198.0), controlPoint1: CGPoint(x: centerX + 26.0, y: centerY + 188.0), controlPoint2: CGPoint(x: centerX + 96.0, y: centerY + 174.0))
            rightLeaf.addCurve(to: CGPoint(x: centerX - 4.0, y: centerY + 232.0), controlPoint1: CGPoint(x: centerX + 104.0, y: centerY + 244.0), controlPoint2: CGPoint(x: centerX + 38.0, y: centerY + 258.0))
            rightLeaf.close()
            weakSelf?.strokePath(rightLeaf, width: 12.0)
        })

        let house = KDLineArtItem.item(title: "House", drawingBlock: { (rect: CGRect) in
            let centerX = rect.midX
            let baseY = rect.maxY - 56.0
            let houseWidth = min(rect.width - 120.0, 360.0)
            let leftX = centerX - houseWidth / 2.0
            let wallTop = baseY - 190.0

            let roof = UIBezierPath()
            roof.move(to: CGPoint(x: leftX - 24.0, y: wallTop + 18.0))
            roof.addLine(to: CGPoint(x: centerX, y: wallTop - 130.0))
            roof.addLine(to: CGPoint(x: leftX + houseWidth + 24.0, y: wallTop + 18.0))
            roof.close()
            weakSelf?.strokePath(roof, width: 12.0)

            weakSelf?.strokePath(UIBezierPath(roundedRect: CGRect(x: leftX, y: wallTop, width: houseWidth, height: 190.0), cornerRadius: 22.0), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(roundedRect: CGRect(x: centerX - 42.0, y: baseY - 104.0, width: 84.0, height: 104.0), cornerRadius: 18.0), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(roundedRect: CGRect(x: leftX + 38.0, y: wallTop + 46.0, width: 84.0, height: 72.0), cornerRadius: 18.0), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(roundedRect: CGRect(x: leftX + houseWidth - 122.0, y: wallTop + 46.0, width: 84.0, height: 72.0), cornerRadius: 18.0), width: 12.0)
        })

        let rocket = KDLineArtItem.item(title: "Rocket", drawingBlock: { (rect: CGRect) in
            let centerX = rect.midX
            let topY = rect.minY + 32.0
            let bottomY = rect.maxY - 54.0

            let body = UIBezierPath()
            body.move(to: CGPoint(x: centerX, y: topY))
            body.addCurve(to: CGPoint(x: centerX + 74.0, y: topY + 150.0), controlPoint1: CGPoint(x: centerX + 58.0, y: topY + 38.0), controlPoint2: CGPoint(x: centerX + 86.0, y: topY + 96.0))
            body.addLine(to: CGPoint(x: centerX + 54.0, y: bottomY - 78.0))
            body.addCurve(to: CGPoint(x: centerX - 54.0, y: bottomY - 78.0), controlPoint1: CGPoint(x: centerX + 24.0, y: bottomY - 42.0), controlPoint2: CGPoint(x: centerX - 24.0, y: bottomY - 42.0))
            body.addLine(to: CGPoint(x: centerX - 74.0, y: topY + 150.0))
            body.addCurve(to: CGPoint(x: centerX, y: topY), controlPoint1: CGPoint(x: centerX - 86.0, y: topY + 96.0), controlPoint2: CGPoint(x: centerX - 58.0, y: topY + 38.0))
            body.close()
            weakSelf?.strokePath(body, width: 12.0)

            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: centerX - 34.0, y: topY + 116.0, width: 68.0, height: 68.0)), width: 12.0)

            let leftFin = UIBezierPath()
            leftFin.move(to: CGPoint(x: centerX - 58.0, y: bottomY - 112.0))
            leftFin.addLine(to: CGPoint(x: centerX - 142.0, y: bottomY - 38.0))
            leftFin.addLine(to: CGPoint(x: centerX - 44.0, y: bottomY - 44.0))
            leftFin.close()
            weakSelf?.strokePath(leftFin, width: 12.0)

            let rightFin = UIBezierPath()
            rightFin.move(to: CGPoint(x: centerX + 58.0, y: bottomY - 112.0))
            rightFin.addLine(to: CGPoint(x: centerX + 142.0, y: bottomY - 38.0))
            rightFin.addLine(to: CGPoint(x: centerX + 44.0, y: bottomY - 44.0))
            rightFin.close()
            weakSelf?.strokePath(rightFin, width: 12.0)

            let flame = UIBezierPath()
            flame.move(to: CGPoint(x: centerX - 30.0, y: bottomY - 40.0))
            flame.addCurve(to: CGPoint(x: centerX, y: bottomY + 34.0), controlPoint1: CGPoint(x: centerX - 14.0, y: bottomY - 4.0), controlPoint2: CGPoint(x: centerX - 6.0, y: bottomY + 12.0))
            flame.addCurve(to: CGPoint(x: centerX + 30.0, y: bottomY - 40.0), controlPoint1: CGPoint(x: centerX + 8.0, y: bottomY + 10.0), controlPoint2: CGPoint(x: centerX + 16.0, y: bottomY - 6.0))
            flame.close()
            weakSelf?.strokePath(flame, width: 12.0)
        })

        let cupcake = KDLineArtItem.item(title: "Cupcake", drawingBlock: { (rect: CGRect) in
            let centerX = rect.midX
            let centerY = rect.midY + 20.0

            let frosting = UIBezierPath()
            frosting.move(to: CGPoint(x: centerX - 142.0, y: centerY - 18.0))
            frosting.addCurve(to: CGPoint(x: centerX - 78.0, y: centerY - 112.0), controlPoint1: CGPoint(x: centerX - 150.0, y: centerY - 82.0), controlPoint2: CGPoint(x: centerX - 112.0, y: centerY - 116.0))
            frosting.addCurve(to: CGPoint(x: centerX, y: centerY - 136.0), controlPoint1: CGPoint(x: centerX - 58.0, y: centerY - 168.0), controlPoint2: CGPoint(x: centerX - 18.0, y: centerY - 168.0))
            frosting.addCurve(to: CGPoint(x: centerX + 78.0, y: centerY - 112.0), controlPoint1: CGPoint(x: centerX + 18.0, y: centerY - 168.0), controlPoint2: CGPoint(x: centerX + 58.0, y: centerY - 168.0))
            frosting.addCurve(to: CGPoint(x: centerX + 142.0, y: centerY - 18.0), controlPoint1: CGPoint(x: centerX + 112.0, y: centerY - 116.0), controlPoint2: CGPoint(x: centerX + 150.0, y: centerY - 82.0))
            frosting.addCurve(to: CGPoint(x: centerX - 142.0, y: centerY - 18.0), controlPoint1: CGPoint(x: centerX + 84.0, y: centerY + 16.0), controlPoint2: CGPoint(x: centerX - 84.0, y: centerY + 16.0))
            frosting.close()
            weakSelf?.strokePath(frosting, width: 12.0)

            let cup = UIBezierPath()
            cup.move(to: CGPoint(x: centerX - 118.0, y: centerY))
            cup.addLine(to: CGPoint(x: centerX + 118.0, y: centerY))
            cup.addLine(to: CGPoint(x: centerX + 82.0, y: centerY + 158.0))
            cup.addLine(to: CGPoint(x: centerX - 82.0, y: centerY + 158.0))
            cup.close()
            weakSelf?.strokePath(cup, width: 12.0)

            for index in -1...1 {
                weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: centerX + CGFloat(index) * 58.0 - 12.0, y: centerY - 70.0 + (index == 0 ? -24.0 : 0.0), width: 24.0, height: 24.0)), width: 8.0)
            }
        })

        let dino = KDLineArtItem.item(title: "Dino", drawingBlock: { (rect: CGRect) in
            let centerX = rect.midX
            let centerY = rect.midY + 28.0

            let body = UIBezierPath()
            body.move(to: CGPoint(x: centerX - 176.0, y: centerY + 16.0))
            body.addCurve(to: CGPoint(x: centerX - 44.0, y: centerY - 96.0), controlPoint1: CGPoint(x: centerX - 166.0, y: centerY - 68.0), controlPoint2: CGPoint(x: centerX - 104.0, y: centerY - 112.0))
            body.addLine(to: CGPoint(x: centerX + 72.0, y: centerY - 96.0))
            body.addCurve(to: CGPoint(x: centerX + 178.0, y: centerY - 28.0), controlPoint1: CGPoint(x: centerX + 132.0, y: centerY - 96.0), controlPoint2: CGPoint(x: centerX + 178.0, y: centerY - 70.0))
            body.addCurve(to: CGPoint(x: centerX + 120.0, y: centerY + 84.0), controlPoint1: CGPoint(x: centerX + 178.0, y: centerY + 40.0), controlPoint2: CGPoint(x: centerX + 156.0, y: centerY + 82.0))
            body.addLine(to: CGPoint(x: centerX - 64.0, y: centerY + 84.0))
            body.addCurve(to: CGPoint(x: centerX - 176.0, y: centerY + 16.0), controlPoint1: CGPoint(x: centerX - 118.0, y: centerY + 84.0), controlPoint2: CGPoint(x: centerX - 160.0, y: centerY + 60.0))
            body.close()
            weakSelf?.strokePath(body, width: 12.0)

            weakSelf?.strokePath(UIBezierPath(ovalIn: CGRect(x: centerX + 94.0, y: centerY - 54.0, width: 28.0, height: 28.0)), width: 9.0)

            let tail = UIBezierPath()
            tail.move(to: CGPoint(x: centerX - 162.0, y: centerY + 20.0))
            tail.addLine(to: CGPoint(x: centerX - 252.0, y: centerY - 44.0))
            tail.addLine(to: CGPoint(x: centerX - 184.0, y: centerY + 64.0))
            tail.close()
            weakSelf?.strokePath(tail, width: 12.0)

            let spikes = UIBezierPath()
            for i in 0..<4 {
                let x = centerX - 56.0 + CGFloat(i) * 52.0
                spikes.move(to: CGPoint(x: x, y: centerY - 96.0))
                spikes.addLine(to: CGPoint(x: x + 26.0, y: centerY - 142.0))
                spikes.addLine(to: CGPoint(x: x + 52.0, y: centerY - 96.0))
            }
            weakSelf?.strokePath(spikes, width: 12.0)

            weakSelf?.strokePath(UIBezierPath(roundedRect: CGRect(x: centerX - 52.0, y: centerY + 78.0, width: 42.0, height: 88.0), cornerRadius: 16.0), width: 12.0)
            weakSelf?.strokePath(UIBezierPath(roundedRect: CGRect(x: centerX + 58.0, y: centerY + 78.0, width: 42.0, height: 88.0), cornerRadius: 16.0), width: 12.0)
        })

        return [bunny, car, fish, flower, house, rocket, cupcake, dino]
    }

    // MARK: - 调色板

    func makePalette24() -> [UIColor] {
        return [
            UIColor(red: 0.94, green: 0.43, blue: 0.45, alpha: 1.0),
            UIColor(red: 0.94, green: 0.55, blue: 0.36, alpha: 1.0),
            UIColor(red: 0.96, green: 0.71, blue: 0.34, alpha: 1.0),
            UIColor(red: 0.95, green: 0.80, blue: 0.41, alpha: 1.0),
            UIColor(red: 0.75, green: 0.84, blue: 0.39, alpha: 1.0),
            UIColor(red: 0.56, green: 0.84, blue: 0.63, alpha: 1.0),
            UIColor(red: 0.43, green: 0.79, blue: 0.70, alpha: 1.0),
            UIColor(red: 0.45, green: 0.73, blue: 0.97, alpha: 1.0),
            UIColor(red: 0.55, green: 0.54, blue: 0.95, alpha: 1.0),
            UIColor(red: 0.70, green: 0.49, blue: 0.93, alpha: 1.0),
            UIColor(red: 0.94, green: 0.63, blue: 0.74, alpha: 1.0),
            UIColor(red: 0.91, green: 0.39, blue: 0.65, alpha: 1.0),
            UIColor(red: 0.88, green: 0.26, blue: 0.38, alpha: 1.0),
            UIColor(red: 0.70, green: 0.22, blue: 0.27, alpha: 1.0),
            UIColor(red: 0.66, green: 0.44, blue: 0.22, alpha: 1.0),
            UIColor(red: 0.81, green: 0.64, blue: 0.34, alpha: 1.0),
            UIColor(red: 0.59, green: 0.47, blue: 0.87, alpha: 1.0),
            UIColor(red: 0.38, green: 0.58, blue: 0.95, alpha: 1.0),
            UIColor(red: 0.22, green: 0.54, blue: 0.82, alpha: 1.0),
            UIColor(red: 0.20, green: 0.63, blue: 0.57, alpha: 1.0),
            UIColor(red: 0.26, green: 0.52, blue: 0.34, alpha: 1.0),
            UIColor(red: 0.37, green: 0.35, blue: 0.31, alpha: 1.0),
            UIColor(white: 0.63, alpha: 1.0),
            UIColor(red: 0.14, green: 0.16, blue: 0.19, alpha: 1.0)
        ]
    }

    func makePalette36() -> [UIColor] {
        var colors = self.makePalette24()
        colors.append(contentsOf: [
            UIColor(red: 0.98, green: 0.81, blue: 0.81, alpha: 1.0),
            UIColor(red: 0.99, green: 0.90, blue: 0.76, alpha: 1.0),
            UIColor(red: 0.86, green: 0.93, blue: 0.73, alpha: 1.0),
            UIColor(red: 0.75, green: 0.92, blue: 0.89, alpha: 1.0),
            UIColor(red: 0.80, green: 0.89, blue: 0.99, alpha: 1.0),
            UIColor(red: 0.89, green: 0.83, blue: 0.98, alpha: 1.0),
            UIColor(red: 0.97, green: 0.82, blue: 0.91, alpha: 1.0),
            UIColor(red: 0.89, green: 0.69, blue: 0.56, alpha: 1.0),
            UIColor(red: 0.63, green: 0.72, blue: 0.79, alpha: 1.0),
            UIColor(white: 0.86, alpha: 1.0),
            UIColor(white: 0.96, alpha: 1.0),
            UIColor(white: 0.05, alpha: 1.0)
        ])
        return colors
    }

    func currentPalette() -> [UIColor] {
        return self.showing36Palette ? self.palette36 : self.palette24
    }

    func paletteGridColumns() -> Int {
        return 6
    }

    func paletteColorButtonSize() -> CGFloat {
        return 30.0
    }

    func paletteColorButtonSpacing() -> CGFloat {
        return 8.0
    }

    func paletteGridWidth() -> CGFloat {
        let columns = self.paletteGridColumns()
        return CGFloat(columns) * self.paletteColorButtonSize() + CGFloat(columns - 1) * self.paletteColorButtonSpacing()
    }

    func paletteGridHeightForColorCount(_ colorCount: Int) -> CGFloat {
        let columns = self.paletteGridColumns()
        let rows = (colorCount + columns - 1) / columns
        let spacingCount = max(0, rows - 1)
        return CGFloat(rows) * self.paletteColorButtonSize() + CGFloat(spacingCount) * self.paletteColorButtonSpacing()
    }

    var colorWheelCachedImage: UIImage?
    static var colorWheelCacheOnce: Bool = false

    func colorWheelImage() -> UIImage {
        if KCMainViewController.colorWheelCacheOnce {
            return self.colorWheelCachedImage!
        }
        KCMainViewController.colorWheelCacheOnce = true
        let size = CGSize(width: 44.0, height: 44.0)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { (_: UIGraphicsImageRendererContext) in
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            let outerRadius = size.width * 0.5
            let innerRadius: CGFloat = 14.0
            let sliceCount = 120

            for index in 0..<sliceCount {
                let startAngle = (CGFloat(index) / CGFloat(sliceCount)) * CGFloat.pi * 2.0 - CGFloat.pi / 2.0
                let endAngle = (CGFloat(index + 1) / CGFloat(sliceCount)) * CGFloat.pi * 2.0 - CGFloat.pi / 2.0
                let segmentColor = UIColor(hue: CGFloat(index) / CGFloat(sliceCount), saturation: 0.9, brightness: 1.0, alpha: 1.0)
                let segment = UIBezierPath()
                segment.addArc(withCenter: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                segment.addArc(withCenter: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: false)
                segment.close()
                segmentColor.setFill()
                segment.fill()
            }
        }
        self.colorWheelCachedImage = image
        return image
    }

    func reloadPaletteGrid() {
        let grid = self.view.viewWithTag(701)!
        for subview in grid.subviews {
            subview.removeFromSuperview()
        }
        self.colorButtons.removeAll()

        let palette = self.currentPalette()
        let buttonSize = self.paletteColorButtonSize()
        let spacing = self.paletteColorButtonSpacing()
        let columns = self.paletteGridColumns()
        self.paletteGridHeightConstraint.constant = self.paletteGridHeightForColorCount(palette.count)

        for index in 0..<palette.count {
            let colorButton = UIButton(type: .custom)
            colorButton.translatesAutoresizingMaskIntoConstraints = false
            colorButton.backgroundColor = palette[index]
            colorButton.layer.cornerRadius = 13.0
            colorButton.layer.borderWidth = 3.0
            colorButton.layer.borderColor = UIColor(white: 1.0, alpha: 0.92).cgColor
            colorButton.tag = index
            colorButton.accessibilityLabel = "Color \(index + 1)"
            colorButton.accessibilityIdentifier = "palette.color.\(index + 1)"
            colorButton.addTarget(self, action: #selector(didTapColorButton(_:)), for: .touchUpInside)
            self.registerPressFeedbackForControl(colorButton)
            grid.addSubview(colorButton)
            self.colorButtons.append(colorButton)

            let row = index / columns
            let column = index % columns
            NSLayoutConstraint.activate([
                colorButton.leadingAnchor.constraint(equalTo: grid.leadingAnchor, constant: CGFloat(column) * (buttonSize + spacing)),
                colorButton.topAnchor.constraint(equalTo: grid.topAnchor, constant: CGFloat(row) * (buttonSize + spacing)),
                colorButton.widthAnchor.constraint(equalToConstant: buttonSize),
                colorButton.heightAnchor.constraint(equalToConstant: buttonSize)
            ])
        }

        if self.canvasView.currentColor != nil {
            self.selectColor(self.canvasView.currentColor, sender: nil)
        }
    }

    func reloadRecentColorRow() {
        let recentRow: UIView? = self.recentColorRowStack ?? self.view.viewWithTag(702)
        guard let recentStack = recentRow as? UIStackView else {
            return
        }

        for view in recentStack.arrangedSubviews {
            recentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        self.recentColorButtons.removeAll()

        for index in 0..<self.recentColors.count {
            let button = UIButton(type: .custom)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.backgroundColor = self.recentColors[index]
            button.layer.cornerRadius = 13.0
            button.layer.borderWidth = 3.0
            button.layer.borderColor = UIColor(white: 1.0, alpha: 0.92).cgColor
            button.tag = index
            button.accessibilityLabel = "Recent Color \(index + 1)"
            button.accessibilityIdentifier = "palette.recent.\(index + 1)"
            button.addTarget(self, action: #selector(didTapRecentColorButton(_:)), for: .touchUpInside)
            self.registerPressFeedbackForControl(button)
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 30.0),
                button.heightAnchor.constraint(equalToConstant: 30.0)
            ])
            recentStack.addArrangedSubview(button)
            self.recentColorButtons.append(button)
        }
    }

    func currentStickerSymbols() -> [String] {
        let symbols = self.stickerSymbolsByCategory[self.selectedStickerCategory] ?? []
        if symbols.count > 0 {
            return symbols
        }
        return self.stickerSymbolsByCategory[self.stickerCategories.first ?? ""] ?? []
    }

    func reloadStickerButtons() {
        for view in self.stickerRowStack.arrangedSubviews {
            self.stickerRowStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        self.stickerButtons.removeAll()

        for symbol in self.currentStickerSymbols() {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setImage(self.safeSystemImageNamed(symbol), for: .normal)
            button.tintColor = UIColor(red: 0.24, green: 0.29, blue: 0.35, alpha: 1.0)
            button.backgroundColor = UIColor(white: 1.0, alpha: 0.76)
            button.layer.cornerRadius = 18.0
            button.layer.borderWidth = 1.0
            button.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
            button.widthAnchor.constraint(equalToConstant: 44.0).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44.0).isActive = true
            button.accessibilityIdentifier = symbol
            button.accessibilityLabel = self.stickerAccessibilityLabelForSymbol(symbol)
            button.addTarget(self, action: #selector(didTapStickerButton(_:)), for: .touchUpInside)
            self.registerPressFeedbackForControl(button)
            self.stickerRowStack.addArrangedSubview(button)
            self.stickerButtons.append(button)
        }

        self.refreshStickerCategoryButtons()
        self.selectStickerSymbol(self.canvasView.currentStickerSymbol ?? self.currentStickerSymbols().first!)
    }

    func refreshStickerCategoryButtons() {
        for button in self.stickerCategoryButtons {
            let category = self.stickerCategoryFromButton(button)
            let active = category == self.selectedStickerCategory
            button.backgroundColor = active
                ? UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0)
                : UIColor(white: 1.0, alpha: 0.62)
            button.tintColor = active
                ? UIColor(red: 0.39, green: 0.26, blue: 0.0, alpha: 1.0)
                : UIColor(red: 0.47, green: 0.52, blue: 0.58, alpha: 1.0)
            button.layer.borderColor = (active
                ? UIColor(white: 1.0, alpha: 0.92)
                : UIColor(white: 1.0, alpha: 0.70)).cgColor
        }
    }

    func stickerCategoryFromButton(_ button: UIButton) -> String? {
        let prefix = "sticker.category."
        let identifier = button.accessibilityIdentifier ?? ""
        if !identifier.hasPrefix(prefix) {
            return nil
        }

        let slug = String(identifier.dropFirst(prefix.count))
        for category in self.stickerCategories {
            if category.lowercased() == slug {
                return category
            }
        }
        return nil
    }

    func addRecentColor(_ color: UIColor?) {
        guard let color = color else {
            return
        }

        for index in stride(from: self.recentColors.count - 1, through: 0, by: -1) {
            if self.color(self.recentColors[index], matchesColor: color) {
                self.recentColors.remove(at: index)
            }
        }

        self.recentColors.insert(color, at: 0)
        while self.recentColors.count > 8 {
            self.recentColors.removeLast()
        }

        self.persistRecentColors()
        self.reloadRecentColorRow()
    }

    func loadRecentColors() -> [UIColor] {
        let storedColors = UserDefaults.standard.array(forKey: "KDRecentColors") as? [[String: Any]] ?? []
        var colors: [UIColor] = []
        for components in storedColors {
            guard let red = components["r"] as? Double,
                  let green = components["g"] as? Double,
                  let blue = components["b"] as? Double,
                  let alpha = components["a"] as? Double else {
                continue
            }
            colors.append(UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha)))
        }
        return colors
    }

    func persistRecentColors() {
        var storedColors: [[String: Any]] = []
        storedColors.reserveCapacity(self.recentColors.count)
        for color in self.recentColors {
            var red: CGFloat = 0.0
            var green: CGFloat = 0.0
            var blue: CGFloat = 0.0
            var alpha: CGFloat = 0.0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
                continue
            }
            storedColors.append(["r": Double(red), "g": Double(green), "b": Double(blue), "a": Double(alpha)])
        }
        UserDefaults.standard.set(storedColors, forKey: "KDRecentColors")
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
        let palette36 = self.showing36Palette
        self.palette24Button.setTitleColor(palette36 ? UIColor(red: 0.49, green: 0.53, blue: 0.59, alpha: 1.0) : UIColor(red: 0.39, green: 0.26, blue: 0.0, alpha: 1.0), for: .normal)
        self.palette24Button.backgroundColor = palette36 ? UIColor.clear : UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0)
        self.palette24Button.layer.borderWidth = palette36 ? 0.0 : 1.0
        self.palette36Button.setTitleColor(palette36 ? UIColor(red: 0.39, green: 0.26, blue: 0.0, alpha: 1.0) : UIColor(red: 0.49, green: 0.53, blue: 0.59, alpha: 1.0), for: .normal)
        self.palette36Button.backgroundColor = palette36 ? UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0) : UIColor.clear
        self.palette36Button.layer.borderWidth = palette36 ? 1.0 : 0.0
    }

    // MARK: - 历史

    func refreshHistoryUI() {
        self.sessions = self.sessionStore.loadAllSessions()
        let maxPageIndex = self.maxHistoryPageIndex()
        self.historyPageIndex = KCDrawingEngineAdapter.historyClampedPageIndex(
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
        let canDeleteHistoryItem = selectedSession != nil || self.sessions.count > 0 || draftImage != nil
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

        for index in 0..<self.historyThumbButtons.count {
            let button = self.historyThumbButtons[index]
            let sessionIndex = self.sessionIndexForHistoryThumbIndex(index)
            if sessionIndex < self.sessions.count {
                let session = self.sessions[sessionIndex]
                let image = self.sessionStore.thumbnailImage(forSessionId: session.identifier)
                button.setBackgroundImage(image, for: .normal)
                button.imageView?.isHidden = image != nil
                button.isEnabled = true
                button.accessibilityLabel = "Saved Thumbnail \(sessionIndex + 1)"
                let isActiveSession = self.activeSession != nil &&
                    self.activeSession?.identifier == session.identifier
                let isSelectedSession = selectedSession != nil &&
                    selectedSession?.identifier == session.identifier
                let isDirtyActiveSession = isActiveSession && self.activeSessionHasUnsavedChanges
                if isDirtyActiveSession {
                    button.accessibilityLabel = "Unsaved Saved Thumbnail \(sessionIndex + 1)"
                } else if isSelectedSession {
                    button.accessibilityLabel = "Selected Saved Thumbnail \(sessionIndex + 1)"
                }
                var borderColor = UIColor(red: 0.17, green: 0.22, blue: 0.30, alpha: 0.08)
                if isDirtyActiveSession {
                    borderColor = UIColor(red: 0.97, green: 0.70, blue: 0.25, alpha: 0.94)
                } else if isSelectedSession {
                    borderColor = UIColor(red: 0.50, green: 0.78, blue: 0.56, alpha: 0.90)
                } else if isActiveSession {
                    borderColor = UIColor(red: 0.45, green: 0.73, blue: 0.97, alpha: 0.82)
                }
                button.layer.borderColor = borderColor.cgColor
                button.layer.borderWidth = isDirtyActiveSession ? 3.0 : 2.0
                let emphasized = isActiveSession || isSelectedSession
                button.transform = emphasized ? CGAffineTransform(scaleX: isDirtyActiveSession ? 1.05 : 1.03, y: isDirtyActiveSession ? 1.05 : 1.03) : .identity
            } else {
                button.setBackgroundImage(nil, for: .normal)
                button.imageView?.isHidden = false
                button.isEnabled = false
                button.accessibilityLabel = "Empty Saved Thumbnail \(index + 1)"
                button.backgroundColor = UIColor(red: 1.0, green: 0.995, blue: 0.98, alpha: 1.0)
                button.layer.borderColor = UIColor(red: 0.17, green: 0.22, blue: 0.30, alpha: 0.08).cgColor
                button.layer.borderWidth = 2.0
                button.transform = .identity
            }
        }
    }

    func historyPageSize() -> Int {
        return self.historyThumbButtons.count
    }

    func maxHistoryPageIndex() -> Int {
        // 历史分页计算在 Swift KCHistoryPaging Feature 模型中。
        return KCDrawingEngineAdapter.historyMaxPageIndex(sessionCount: self.sessions.count,
                                                         pageSize: self.historyPageSize())
    }

    func sessionIndexForHistoryThumbIndex(_ thumbIndex: Int) -> Int {
        // 历史分页计算在 Swift KCHistoryPaging Feature 模型中。
        return KCDrawingEngineAdapter.historySessionIndex(
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
            let active = button.toolMode == mode
            button.backgroundColor = active
                ? UIColor(red: 0.66, green: 0.89, blue: 0.72, alpha: 1.0)
                : (button.toolMode == .picker
                    ? UIColor(red: 0.96, green: 0.85, blue: 0.48, alpha: 1.0)
                    : UIColor(white: 1.0, alpha: 0.82))
            button.layer.borderColor = (active
                ? UIColor(white: 1.0, alpha: 0.92)
                : UIColor(white: 1.0, alpha: 0.72)).cgColor
            button.layer.shadowOpacity = active ? 0.18 : 0.10
            button.transform = active ? CGAffineTransform(scaleX: 1.04, y: 1.04) : .identity
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
        var fillColor: UIColor = self.canvasView.currentColor ?? UIColor(red: 0.94, green: 0.43, blue: 0.45, alpha: 1.0)
        var strokeColor: UIColor = UIColor(white: 1.0, alpha: 0.92)
        var alpha: CGFloat = 1.0

        if self.canvasView.currentToolMode == .eraser {
            previewDiameter = min(38.0, max(16.0, CGFloat(self.sizeSlider.value) * 1.08))
            path = self.previewPathForEraserShape(self.canvasView.currentEraserShape, center: center, size: previewDiameter)
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

    func previewPathForEraserShape(_ shape: KDEraserShape, center: CGPoint, size: CGFloat) -> UIBezierPath {
        let radius = size / 2.0
        if shape == .circle {
            return UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: size, height: size))
        }

        if shape == .cloud {
            let path = UIBezierPath()
            path.append(UIBezierPath(ovalIn: CGRect(x: center.x - radius * 1.05, y: center.y - radius * 0.32, width: radius * 0.95, height: radius * 0.74)))
            path.append(UIBezierPath(ovalIn: CGRect(x: center.x - radius * 0.42, y: center.y - radius * 0.78, width: radius * 1.02, height: radius * 0.98)))
            path.append(UIBezierPath(ovalIn: CGRect(x: center.x + radius * 0.18, y: center.y - radius * 0.28, width: radius * 0.90, height: radius * 0.70)))
            return path
        }

        let star = UIBezierPath()
        let points = 5
        let innerRadius = radius * 0.45
        for i in 0..<(points * 2) {
            let angle = (-CGFloat.pi / 2.0) + CGFloat(i) * (CGFloat.pi / CGFloat(points))
            let currentRadius = (i % 2 == 0) ? radius : innerRadius
            let point = CGPoint(x: center.x + currentRadius * cos(angle), y: center.y + currentRadius * sin(angle))
            if i == 0 {
                star.move(to: point)
            } else {
                star.addLine(to: point)
            }
        }
        star.close()
        return star
    }

    func refreshBrushDockSelection() {
        for button in self.brushButtons {
            let active = button.representsBrushStyle
                ? (self.canvasView.currentToolMode == .brush && button.brushStyle == self.canvasView.currentBrushStyle)
                : (button.toolMode == self.canvasView.currentToolMode)
            button.backgroundColor = active ? UIColor(red: 0.66, green: 0.89, blue: 0.72, alpha: 1.0) : UIColor(white: 1.0, alpha: 0.84)
            button.layer.borderColor = (active
                ? UIColor(white: 1.0, alpha: 0.94)
                : UIColor(white: 1.0, alpha: 0.72)).cgColor
            button.layer.shadowOpacity = active ? 0.20 : 0.12
            button.transform = active ? CGAffineTransform(scaleX: 1.03, y: 1.03) : .identity
            if active {
                self.scrollBrushDockToButton(button)
            }
        }
    }

    func scrollBrushDockToToolMode(_ mode: KDToolMode) {
        for button in self.brushButtons {
            let matches = button.representsBrushStyle
                ? (mode == .brush && button.brushStyle == self.canvasView.currentBrushStyle)
                : (button.toolMode == mode)
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
        if let activeColorButton = self.activeColorButton {
            activeColorButton.layer.borderColor = UIColor(white: 1.0, alpha: 0.92).cgColor
        }
        if let sender = sender {
            sender.layer.borderColor = UIColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 0.18).cgColor
            self.activeColorButton = sender
            return
        }

        self.activeColorButton = nil
        for colorButton in self.colorButtons {
            let palette = self.currentPalette()
            if colorButton.tag >= palette.count {
                continue
            }
            let paletteColor = palette[colorButton.tag]
            if self.color(paletteColor, matchesColor: color) {
                colorButton.layer.borderColor = UIColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 0.18).cgColor
                self.activeColorButton = colorButton
                break
            }
        }

        for button in self.recentColorButtons {
            if button.tag < self.recentColors.count && self.color(self.recentColors[button.tag], matchesColor: color) {
                button.layer.borderColor = UIColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 0.18).cgColor
                self.activeColorButton = button
                break
            }
        }
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
        self.showing36Palette = false
        self.updatePaletteButtons()
        self.reloadPaletteGrid()
    }

    @objc func didTapPalette36() {
        self.showing36Palette = true
        self.updatePaletteButtons()
        self.reloadPaletteGrid()
    }

    @objc func didTapCustomColor() {
        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.selectedColor = self.canvasView.currentColor ?? UIColor.systemRed
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
        let alert = UIAlertController(title: "Clear Canvas", message: "Start a fresh drawing?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive, handler: { [weak self] (_: UIAlertAction) in
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
        if !self.canvasView.hasVisibleContent() {
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
        let title = shouldDeleteDraft ? "Delete Draft" : "Delete Session"
        let message = shouldDeleteDraft ? "Remove this draft artwork?" : "Remove this saved artwork?"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] (_: UIAlertAction) in
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
        let picker = UIViewController()
        picker.modalPresentationStyle = .popover
        picker.preferredContentSize = CGSize(width: 450.0, height: 420.0)
        picker.view.accessibilityIdentifier = "line-art.picker"

        let panel = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.layer.cornerRadius = 28.0
        panel.clipsToBounds = true
        picker.view.addSubview(panel)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        panel.contentView.addSubview(scrollView)

        let grid = UIStackView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.axis = .vertical
        grid.spacing = 14.0
        grid.distribution = .fill
        scrollView.addSubview(grid)

        let columns = 2
        let rows = (self.lineArtItems.count + columns - 1) / columns
        for row in 0..<rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 14.0
            rowStack.distribution = .fillEqually
            grid.addArrangedSubview(rowStack)
            rowStack.heightAnchor.constraint(equalToConstant: 132.0).isActive = true

            for column in 0..<columns {
                let index = row * columns + column
                if index >= self.lineArtItems.count {
                    let spacer = UIView()
                    rowStack.addArrangedSubview(spacer)
                    continue
                }

                let item = self.lineArtItems[index]
                let button = self.lineArtPreviewButtonForItem(item, index: index)
                button.addTarget(self, action: #selector(didTapLineArtPreviewButton(_:)), for: .touchUpInside)
                rowStack.addArrangedSubview(button)
            }
        }

        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: picker.view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: picker.view.trailingAnchor),
            panel.topAnchor.constraint(equalTo: picker.view.topAnchor),
            panel.bottomAnchor.constraint(equalTo: picker.view.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 18.0),
            scrollView.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -18.0),
            scrollView.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 18.0),
            scrollView.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -18.0),

            grid.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            grid.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            grid.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            grid.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        let popover = picker.popoverPresentationController
        popover?.sourceView = self.view
        popover?.sourceRect = CGRect(x: self.view.bounds.midX, y: 104.0, width: 1.0, height: 1.0)
        popover?.permittedArrowDirections = .up
        self.present(picker, animated: true, completion: nil)
    }

    func lineArtPreviewButtonForItem(_ item: KDLineArtItem, index: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(red: 1.0, green: 0.995, blue: 0.98, alpha: 0.96)
        button.layer.cornerRadius = 24.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.76).cgColor
        button.layer.shadowColor = UIColor(red: 0.40, green: 0.32, blue: 0.22, alpha: 1.0).cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 10.0
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        button.tag = index
        button.setImage(self.thumbnailImageForLineArtItem(item), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.imageEdgeInsets = UIEdgeInsets(top: 14.0, left: 18.0, bottom: 14.0, right: 18.0)
        self.applyAccessibilityLabel(item.title, identifier: "line-art.\(item.title.lowercased())", toControl: button)
        self.registerPressFeedbackForControl(button)
        return button
    }

    @objc func didTapLineArtPreviewButton(_ button: UIButton) {
        let index = button.tag
        if index >= self.lineArtItems.count {
            return
        }

        let item = self.lineArtItems[index]
        self.dismiss(animated: true) {
            self.loadLineArtItem(item)
        }
    }

    func thumbnailImageForLineArtItem(_ item: KDLineArtItem) -> UIImage {
        let size = CGSize(width: 160.0, height: 112.0)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { (_: UIGraphicsImageRendererContext) in
            UIColor(red: 1.0, green: 0.995, blue: 0.98, alpha: 1.0).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.18, green: 0.23, blue: 0.30, alpha: 1.0).setStroke()

            let drawingRect = CGRect(origin: .zero, size: size).insetBy(dx: 22.0, dy: 18.0)
            let context = UIGraphicsGetCurrentContext()
            context?.saveGState()
            let scale = min(drawingRect.size.width / 520.0, drawingRect.size.height / 420.0)
            let previousStrokeScale = self.lineArtStrokeScale
            self.lineArtStrokeScale = 0.22
            defer {
                self.lineArtStrokeScale = previousStrokeScale
            }
            context?.translateBy(x: drawingRect.midX, y: drawingRect.midY)
            context?.scaleBy(x: scale, y: scale)
            context?.translateBy(x: -260.0, y: -210.0)
            item.drawingBlock?(CGRect(x: 0.0, y: 0.0, width: 520.0, height: 420.0))
            context?.restoreGState()
        }
    }

    func loadLineArtItem(_ item: KDLineArtItem) {
        var canvasSize = self.canvasView.bounds.size
        if canvasSize == .zero {
            canvasSize = CGSize(width: 1024.0, height: 720.0)
        }
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let lineArt = renderer.image { (rendererContext: UIGraphicsImageRendererContext) in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvasSize))
            let context = rendererContext.cgContext
            context.setLineWidth(12.0)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(UIColor.black.cgColor)

            let drawingRect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: 110.0, dy: 90.0)
            item.drawingBlock?(drawingRect)
        }

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
        if button.tag < self.recentColors.count {
            self.selectColor(self.recentColors[button.tag], sender: button)
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
        if self.stickerSymbolsByCategory[category] == nil {
            return
        }

        self.selectedStickerCategory = category
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
        if self.activeSession == nil || !self.activeSessionHasUnsavedChanges || !self.canvasView.hasVisibleContent() {
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
        let buttons: [UIButton] = [self.circleEraserButton, self.cloudEraserButton, self.starEraserButton]
        for index in 0..<buttons.count {
            let button = buttons[index]
            let active = index == self.canvasView.currentEraserShape.rawValue
            button.backgroundColor = active
                ? UIColor(red: 0.97, green: 0.86, blue: 0.48, alpha: 1.0)
                : UIColor(white: 1.0, alpha: 0.82)
            button.layer.borderColor = (active
                ? UIColor(white: 1.0, alpha: 0.92)
                : UIColor(white: 1.0, alpha: 0.72)).cgColor
            button.transform = active ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
        }
        self.refreshSizePreview()
    }

    func refreshStickerEditButtons() {
        let enabled = self.canvasView.hasSelectedSticker()
        self.frontStickerButton.isEnabled = enabled
        self.deleteStickerButton.isEnabled = enabled
        self.frontStickerButton.alpha = enabled ? 1.0 : 0.55
        self.deleteStickerButton.alpha = enabled ? 1.0 : 0.55
        self.frontStickerButton.backgroundColor = enabled
            ? UIColor(white: 1.0, alpha: 0.82)
            : UIColor(white: 1.0, alpha: 0.62)
        self.deleteStickerButton.backgroundColor = enabled
            ? UIColor(white: 1.0, alpha: 0.82)
            : UIColor(white: 1.0, alpha: 0.62)
    }

    func refreshActionButtons() {
        self.undoButton.isEnabled = self.canvasView.canUndo()
        self.redoButton.isEnabled = self.canvasView.canRedo()
        self.saveButton.isEnabled = self.canvasView.hasVisibleContent()

        self.undoButton.alpha = self.undoButton.isEnabled ? 1.0 : 0.55
        self.redoButton.alpha = self.redoButton.isEnabled ? 1.0 : 0.55
        self.saveButton.alpha = self.saveButton.isEnabled ? 1.0 : 0.6
        self.undoButton.backgroundColor = self.undoButton.isEnabled
            ? UIColor(white: 1.0, alpha: 0.76)
            : UIColor(white: 1.0, alpha: 0.62)
        self.redoButton.backgroundColor = self.redoButton.isEnabled
            ? UIColor(white: 1.0, alpha: 0.76)
            : UIColor(white: 1.0, alpha: 0.62)
        self.saveButton.backgroundColor = self.saveButton.isEnabled
            ? UIColor(red: 0.54, green: 0.80, blue: 0.98, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 0.72)
        self.saveButton.tintColor = self.saveButton.isEnabled
            ? UIColor(red: 0.19, green: 0.26, blue: 0.33, alpha: 1.0)
            : UIColor(red: 0.55, green: 0.60, blue: 0.67, alpha: 0.7)
    }

    // MARK: - 按压反馈

    func registerPressFeedbackForControl(_ control: UIControl) {
        control.addTarget(self, action: #selector(handleControlPressDown(_:)), for: .touchDown)
        control.addTarget(self, action: #selector(handleControlPressDown(_:)), for: .touchDragEnter)
        control.addTarget(self, action: #selector(handleControlPressRelease(_:)), for: .touchUpInside)
        control.addTarget(self, action: #selector(handleControlPressRelease(_:)), for: .touchUpOutside)
        control.addTarget(self, action: #selector(handleControlPressRelease(_:)), for: .touchCancel)
        control.addTarget(self, action: #selector(handleControlPressRelease(_:)), for: .touchDragExit)
    }

    @objc func handleControlPressDown(_ control: UIControl) {
        if !control.isEnabled || objc_getAssociatedObject(control, &KDPressBaseTransformKey) != nil {
            return
        }

        objc_setAssociatedObject(control, &KDPressBaseTransformKey, NSValue(cgAffineTransform: control.transform), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(control, &KDPressBaseAlphaKey, NSNumber(value: Double(control.alpha)), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let pressedTransform = control.transform.scaledBy(x: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.16,
                       delay: 0.0,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: {
            control.transform = pressedTransform
            control.alpha = max(0.72, control.alpha * 0.92)
        }, completion: nil)
    }

    @objc func handleControlPressRelease(_ control: UIControl) {
        guard let storedTransform = objc_getAssociatedObject(control, &KDPressBaseTransformKey) as? NSValue else {
            return
        }
        let storedAlpha = objc_getAssociatedObject(control, &KDPressBaseAlphaKey) as? NSNumber

        let baseTransform = storedTransform.cgAffineTransformValue
        let baseAlpha: CGFloat = storedAlpha != nil ? CGFloat(storedAlpha!.doubleValue) : 1.0
        objc_setAssociatedObject(control, &KDPressBaseTransformKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(control, &KDPressBaseAlphaKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        UIView.animate(withDuration: 0.18,
                       delay: 0.0,
                       usingSpringWithDamping: 0.68,
                       initialSpringVelocity: 0.0,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: {
            control.transform = baseTransform
            control.alpha = baseAlpha
        }, completion: nil)
    }

    // MARK: - 保存提示

    func showSaveToastWithSuccess(_ success: Bool) {
        self.saveToastView?.removeFromSuperview()

        let toast = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.layer.cornerRadius = 24.0
        toast.clipsToBounds = true
        toast.layer.borderWidth = 1.0
        toast.layer.borderColor = UIColor(white: 1.0, alpha: 0.72).cgColor
        toast.alpha = 0.0
        toast.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
        self.view.addSubview(toast)
        self.saveToastView = toast

        let configuration = UIImage.SymbolConfiguration(pointSize: 24.0, weight: .bold)
        let symbolName = success ? "checkmark" : "exclamationmark.triangle.fill"
        let iconView = UIImageView(image: UIImage(systemName: symbolName, withConfiguration: configuration))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = success
            ? UIColor(red: 0.23, green: 0.58, blue: 0.34, alpha: 1.0)
            : UIColor(red: 0.83, green: 0.36, blue: 0.24, alpha: 1.0)
        toast.contentView.addSubview(iconView)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: self.saveButton.centerXAnchor),
            toast.topAnchor.constraint(equalTo: self.saveButton.bottomAnchor, constant: 14.0),
            toast.widthAnchor.constraint(equalToConstant: 64.0),
            toast.heightAnchor.constraint(equalToConstant: 52.0),
            iconView.centerXAnchor.constraint(equalTo: toast.contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: toast.contentView.centerYAnchor)
        ])

        UIView.animate(withDuration: 0.18,
                       delay: 0.0,
                       usingSpringWithDamping: 0.72,
                       initialSpringVelocity: 0.0,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: {
            toast.alpha = 1.0
            toast.transform = .identity
        }, completion: { _ in
            UIView.animate(withDuration: 0.22,
                           delay: 0.85,
                           options: [.beginFromCurrentState, .allowUserInteraction],
                           animations: {
                toast.alpha = 0.0
                toast.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            }, completion: { _ in
                if self.saveToastView === toast {
                    toast.removeFromSuperview()
                    self.saveToastView = nil
                }
            })
        })
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

        if !self.canvasView.hasVisibleContent() {
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
        self.saveToastView?.removeFromSuperview()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 颜色匹配

    func color(_ lhs: UIColor?, matchesColor rhs: UIColor?) -> Bool {
        guard let lhs = lhs, let rhs = rhs else {
            return false
        }

        var lhsRed: CGFloat = 0.0
        var lhsGreen: CGFloat = 0.0
        var lhsBlue: CGFloat = 0.0
        var lhsAlpha: CGFloat = 0.0
        var rhsRed: CGFloat = 0.0
        var rhsGreen: CGFloat = 0.0
        var rhsBlue: CGFloat = 0.0
        var rhsAlpha: CGFloat = 0.0

        if !lhs.getRed(&lhsRed, green: &lhsGreen, blue: &lhsBlue, alpha: &lhsAlpha) {
            return lhs == rhs
        }
        if !rhs.getRed(&rhsRed, green: &rhsGreen, blue: &rhsBlue, alpha: &rhsAlpha) {
            return lhs == rhs
        }

        let tolerance: CGFloat = 0.01
        return abs(lhsRed - rhsRed) < tolerance &&
            abs(lhsGreen - rhsGreen) < tolerance &&
            abs(lhsBlue - rhsBlue) < tolerance &&
            abs(lhsAlpha - rhsAlpha) < tolerance
    }
}
