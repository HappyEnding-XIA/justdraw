//
//  KCContentLibraryPanelView.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/09.
//

import UIKit
import KCDomain

/// 内容库按需浮层面板（T098）：分段控件切换「官方线稿 / 我的线稿 / 历史作品」三分区，
/// 每分区一个容器，由 `KCMainViewController` 装配实际内容：
/// - 官方线稿：内嵌 `KCLineArtPickerViewController` 的网格；
/// - 我的线稿：空态文案（真实数据源 T099 接入）；
/// - 历史作品：承载从右侧迁移过来的 `historyPanel`（草稿 + 已保存缩略图 + 翻页 + 打开/删除）。
///
/// 本视图只负责面板外观、分段切换与容器显隐；分区能力、空态判定等纯逻辑由
/// `KCContentLibraryFeature` / KCDomain 承担，数据装配与打开/删除事件协调留控制器。
final class KCContentLibraryPanelView: UIView {

    /// 分区切换回调（参数为 `KCContentLibraryPartition.defaultOrder` 中的下标）。
    var onPartitionChange: ((Int) -> Void)?

    /// 关闭回调（点按关闭按钮或背景时触发）。
    var onClose: (() -> Void)?

    /// 官方线稿分区容器（控制器内嵌线稿网格）。
    private(set) lazy var officialLineArtContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    /// 我的线稿分区容器（本轮为空态）。
    private(set) lazy var myLineArtContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    /// 历史作品分区容器（控制器把 `historyPanel` 装入此处）。
    private(set) lazy var historyContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private let backdropView = UIView()
    private let cardView = UIView()
    private let segmentedControl = UISegmentedControl()
    private let closeButton = UIButton(type: .system)
    private let myLineArtEmptyLabel = UILabel()
    private let historyEmptyLabel = UILabel()
    private var cardTopConstraint: NSLayoutConstraint?
    private var cardLeadingConstraint: NSLayoutConstraint?
    private var cardTrailingConstraint: NSLayoutConstraint?
    private var cardBottomConstraint: NSLayoutConstraint?
    private var cardCenterXConstraint: NSLayoutConstraint?
    private var cardCenterYConstraint: NSLayoutConstraint?
    private var cardWidthConstraint: NSLayoutConstraint?
    private var cardHeightConstraint: NSLayoutConstraint?
    private var cardMaxWidthConstraint: NSLayoutConstraint?
    private var cardMaxHeightConstraint: NSLayoutConstraint?
    private var suppressSegmentCallback = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildInterface()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildInterface()
    }

    private func buildInterface() {
        backgroundColor = .clear

        backdropView.backgroundColor = UIColor(white: 0.0, alpha: 0.28)
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdropView)
        let backdropTap = UITapGestureRecognizer(target: self, action: #selector(handleClose))
        backdropView.addGestureRecognizer(backdropTap)

        cardView.backgroundColor = .clear
        cardView.layer.cornerRadius = 26.0
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = KCEditorVisualStyle.glassShadowColor
        cardView.layer.shadowOpacity = 0.14
        cardView.layer.shadowRadius = 18.0
        cardView.layer.shadowOffset = CGSize(width: 0.0, height: 8.0)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        // T109 G2：内容库卡片由"假玻璃"（实色 0.96 + 描边）改为统一玻璃入口（`makeGlassEffectView`）：
        // `cardView` 自身只承载阴影形状与圆角；玻璃效果由 `cardGlass`（系统液态玻璃 / 降级模糊 + 暖底 + 白高光描边）
        // 作为子视图铺底，置于最底层；既有分段/关闭/内容子控件原样叠在玻璃之上，玻璃在边距与圆角处可见。
        // 顺带解开 `historyPanel` 嵌套遮挡：父层不再是不透明 0.96 实色，子层历史玻璃可见。
        let cardGlass = KCEditorVisualStyle.makeGlassEffectView()
        KCEditorVisualStyle.applyGlassSurface(to: cardGlass, cornerRadius: 26.0)
        cardGlass.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(cardGlass)
        cardView.sendSubviewToBack(cardGlass)
        NSLayoutConstraint.activate([
            cardGlass.topAnchor.constraint(equalTo: cardView.topAnchor),
            cardGlass.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            cardGlass.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            cardGlass.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        ])

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        for (index, partition) in KCContentLibraryPartition.defaultOrder.enumerated() {
            segmentedControl.insertSegment(withTitle: "", at: index, animated: false)
            segmentedControl.setEnabled(true, forSegmentAt: index)
            segmentedControl.accessibilityLabel = partition.localizationKey
        }
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(handleSegmentChange), for: .valueChanged)
        cardView.addSubview(segmentedControl)

        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = KCEditorVisualStyle.mutedInkColor
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        cardView.addSubview(closeButton)

        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.backgroundColor = .clear
        cardView.addSubview(contentContainer)

        for container in [officialLineArtContainer, myLineArtContainer, historyContainer] {
            container.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview(container)
        }

        myLineArtEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        myLineArtEmptyLabel.textColor = KCEditorVisualStyle.mutedInkColor
        myLineArtEmptyLabel.font = .systemFont(ofSize: 16.0, weight: .medium)
        myLineArtEmptyLabel.textAlignment = .center
        myLineArtEmptyLabel.numberOfLines = 0
        myLineArtContainer.addSubview(myLineArtEmptyLabel)

        historyEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        historyEmptyLabel.textColor = KCEditorVisualStyle.mutedInkColor
        historyEmptyLabel.font = .systemFont(ofSize: 16.0, weight: .medium)
        historyEmptyLabel.textAlignment = .center
        historyEmptyLabel.numberOfLines = 0
        historyEmptyLabel.isHidden = true
        historyContainer.addSubview(historyEmptyLabel)

        let cardTopConstraint = cardView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16.0)
        let cardLeadingConstraint = cardView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16.0)
        let cardTrailingConstraint = cardView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16.0)
        let cardBottomConstraint = cardView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16.0)
        let cardCenterXConstraint = cardView.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor)
        let cardCenterYConstraint = cardView.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor)
        let cardWidthConstraint = cardView.widthAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor, multiplier: 0.82)
        let cardHeightConstraint = cardView.heightAnchor.constraint(equalTo: safeAreaLayoutGuide.heightAnchor, multiplier: 0.78)
        let cardMaxWidthConstraint = cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 980.0)
        let cardMaxHeightConstraint = cardView.heightAnchor.constraint(lessThanOrEqualToConstant: 640.0)
        self.cardTopConstraint = cardTopConstraint
        self.cardLeadingConstraint = cardLeadingConstraint
        self.cardTrailingConstraint = cardTrailingConstraint
        self.cardBottomConstraint = cardBottomConstraint
        self.cardCenterXConstraint = cardCenterXConstraint
        self.cardCenterYConstraint = cardCenterYConstraint
        self.cardWidthConstraint = cardWidthConstraint
        self.cardHeightConstraint = cardHeightConstraint
        self.cardMaxWidthConstraint = cardMaxWidthConstraint
        self.cardMaxHeightConstraint = cardMaxHeightConstraint

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: bottomAnchor),

            segmentedControl.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16.0),
            segmentedControl.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20.0),
            segmentedControl.heightAnchor.constraint(equalToConstant: 40.0),

            closeButton.centerYAnchor.constraint(equalTo: segmentedControl.centerYAnchor),
            closeButton.leadingAnchor.constraint(equalTo: segmentedControl.trailingAnchor, constant: 12.0),
            closeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20.0),
            closeButton.widthAnchor.constraint(equalToConstant: 34.0),
            closeButton.heightAnchor.constraint(equalToConstant: 34.0),

            contentContainer.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 14.0),
            contentContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16.0),
            contentContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16.0),
            contentContainer.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16.0),

            officialLineArtContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            officialLineArtContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            officialLineArtContainer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            officialLineArtContainer.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            myLineArtContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            myLineArtContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            myLineArtContainer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            myLineArtContainer.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            historyContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            historyContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            historyContainer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            historyContainer.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            myLineArtEmptyLabel.centerYAnchor.constraint(equalTo: myLineArtContainer.centerYAnchor),
            myLineArtEmptyLabel.leadingAnchor.constraint(equalTo: myLineArtContainer.leadingAnchor, constant: 20.0),
            myLineArtEmptyLabel.trailingAnchor.constraint(equalTo: myLineArtContainer.trailingAnchor, constant: -20.0),

            historyEmptyLabel.centerYAnchor.constraint(equalTo: historyContainer.centerYAnchor),
            historyEmptyLabel.leadingAnchor.constraint(equalTo: historyContainer.leadingAnchor, constant: 20.0),
            historyEmptyLabel.trailingAnchor.constraint(equalTo: historyContainer.trailingAnchor, constant: -20.0)
        ])
        applyContentLibrarySizeClass()

        showPartition(index: 0)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyContentLibrarySizeClass()
    }

    private func applyContentLibrarySizeClass() {
        let compact = traitCollection.userInterfaceIdiom == .phone
        backdropView.backgroundColor = UIColor(white: 0.0, alpha: compact ? 0.28 : 0.18)
        cardTopConstraint?.isActive = compact
        cardLeadingConstraint?.isActive = compact
        cardTrailingConstraint?.isActive = compact
        cardBottomConstraint?.isActive = compact
        cardCenterXConstraint?.isActive = !compact
        cardCenterYConstraint?.isActive = !compact
        cardWidthConstraint?.isActive = !compact
        cardHeightConstraint?.isActive = !compact
        cardMaxWidthConstraint?.isActive = !compact
        cardMaxHeightConstraint?.isActive = !compact
    }

    /// 设置某分段的标题（控制器传入本地化文案）。
    func setSegmentTitle(_ title: String, forPartitionAt index: Int) {
        guard KCContentLibraryPartition.defaultOrder.indices.contains(index) else { return }
        segmentedControl.setTitle(title, forSegmentAt: index)
    }

    /// 设置我的线稿空态文案。
    func setMyLineArtEmptyText(_ text: String) {
        myLineArtEmptyLabel.text = text
    }

    /// 设置历史作品空态显隐与文案。历史真正为空（无已保存、无草稿）时显示引导，
    /// 控制器同时隐藏 `historyPanel` 栅格；非空时恢复栅格显示。
    func setHistoryEmptyVisible(_ visible: Bool, text: String) {
        historyEmptyLabel.text = text
        historyEmptyLabel.isHidden = !visible
    }

    /// 历史空态当前是否可见（供运行时验收读取）。
    var isHistoryEmptyVisible: Bool { !historyEmptyLabel.isHidden }

    /// 切换可见分区（不触发 `onPartitionChange` 回调）。
    func showPartition(index: Int) {
        guard KCContentLibraryPartition.defaultOrder.indices.contains(index) else { return }
        suppressSegmentCallback = true
        segmentedControl.selectedSegmentIndex = index
        suppressSegmentCallback = false
        officialLineArtContainer.isHidden = index != 0
        myLineArtContainer.isHidden = index != 1
        historyContainer.isHidden = index != 2
    }

    @objc private func handleSegmentChange() {
        guard !suppressSegmentCallback else { return }
        onPartitionChange?(segmentedControl.selectedSegmentIndex)
    }

    @objc private func handleClose() {
        onClose?()
    }
}
