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

        cardView.backgroundColor = UIColor(white: 1.0, alpha: 0.96)
        cardView.layer.cornerRadius = 26.0
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderColor = KCEditorVisualStyle.borderColor
        cardView.layer.borderWidth = 1.0
        cardView.layer.shadowColor = KCEditorVisualStyle.shadowColor
        cardView.layer.shadowOpacity = 0.30
        cardView.layer.shadowRadius = 18.0
        cardView.layer.shadowOffset = CGSize(width: 0.0, height: 8.0)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

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

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: bottomAnchor),

            cardView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16.0),
            cardView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16.0),
            cardView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16.0),
            cardView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16.0),

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
            myLineArtEmptyLabel.trailingAnchor.constraint(equalTo: myLineArtContainer.trailingAnchor, constant: -20.0)
        ])

        showPartition(index: 0)
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
