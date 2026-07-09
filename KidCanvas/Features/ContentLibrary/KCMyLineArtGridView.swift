//
//  KCMyLineArtGridView.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/09.
//

import UIKit
import KCDomain

/// 内容库“我的线稿”分区网格（T099）。2 列缩略图，单指点击打开、长按删除（删除经
/// 控制器二次确认）。顶部“保存当前为线稿”入口；空态显示引导文案。缩略图由控制器
/// 通过 `thumbnailProvider` 提供（来自 `KCCustomLineArtService` 的内存缓存）。
final class KCMyLineArtGridView: UIView {

    /// “保存当前为线稿”入口回调。
    var onSaveAsLineArt: (() -> Void)?
    /// T101：“从照片生成线稿”入口回调。
    var onGenerateFromPhoto: (() -> Void)?
    /// 打开某条线稿回调（参数为线稿 id）。
    var onOpen: ((String) -> Void)?
    /// 删除某条线稿回调（参数为 id 与展示标题，由控制器弹确认框）。
    var onDelete: ((String, String) -> Void)?
    /// 按 id 提供内存缓存缩略图（主线程安全）。
    var thumbnailProvider: ((String) -> UIImage?)?

    private let saveButton = UIButton(type: .system)
    private let generateButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let gridStack = UIStackView()
    private let emptyLabel = UILabel()
    private var items: [KCCustomLineArtMetadata] = []

    private let columns = 2
    private let rowHeight: CGFloat = 132.0
    private let spacing: CGFloat = 14.0

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

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.titleLabel?.font = .systemFont(ofSize: 16.0, weight: .semibold)
        saveButton.tintColor = KCEditorVisualStyle.accentInkColor
        saveButton.layer.cornerRadius = 16.0
        saveButton.layer.cornerCurve = .continuous
        saveButton.backgroundColor = KCEditorVisualStyle.accentColor
        if #available(iOS 15.0, *) {
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12.0, leading: 18.0, bottom: 12.0, trailing: 18.0)
            saveButton.configuration = configuration
        }
        saveButton.addTarget(self, action: #selector(handleSaveAsLineArt), for: .touchUpInside)
        addSubview(saveButton)

        generateButton.translatesAutoresizingMaskIntoConstraints = false
        generateButton.titleLabel?.font = .systemFont(ofSize: 15.0, weight: .semibold)
        generateButton.tintColor = KCEditorVisualStyle.inkColor
        generateButton.layer.cornerRadius = 16.0
        generateButton.layer.cornerCurve = .continuous
        generateButton.backgroundColor = KCEditorVisualStyle.compactBackgroundColor
        if #available(iOS 15.0, *) {
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12.0, leading: 16.0, bottom: 12.0, trailing: 16.0)
            generateButton.configuration = configuration
        }
        generateButton.addTarget(self, action: #selector(handleGenerateFromPhoto), for: .touchUpInside)
        addSubview(generateButton)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        addSubview(scrollView)

        gridStack.translatesAutoresizingMaskIntoConstraints = false
        gridStack.axis = .vertical
        gridStack.spacing = spacing
        scrollView.addSubview(gridStack)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.textColor = KCEditorVisualStyle.mutedInkColor
        emptyLabel.font = .systemFont(ofSize: 16.0, weight: .medium)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            saveButton.topAnchor.constraint(equalTo: topAnchor, constant: 4.0),
            saveButton.centerXAnchor.constraint(equalTo: centerXAnchor),

            generateButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 10.0),
            generateButton.centerXAnchor.constraint(equalTo: centerXAnchor),

            scrollView.topAnchor.constraint(equalTo: generateButton.bottomAnchor, constant: 16.0),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            gridStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            gridStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            gridStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            gridStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            gridStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20.0),
            emptyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20.0)
        ])
    }

    /// 配置并刷新网格。
    func configure(
        items: [KCCustomLineArtMetadata],
        saveTitle: String,
        generateTitle: String,
        emptyText: String,
        thumbnailProvider: @escaping (String) -> UIImage?
    ) {
        self.items = items
        self.thumbnailProvider = thumbnailProvider
        saveButton.setTitle(saveTitle, for: .normal)
        generateButton.setTitle(generateTitle, for: .normal)
        emptyLabel.text = emptyText
        rebuildGrid()
        let isEmpty = items.isEmpty
        emptyLabel.isHidden = !isEmpty
        scrollView.isHidden = isEmpty
    }

    private func rebuildGrid() {
        for arranged in gridStack.arrangedSubviews {
            gridStack.removeArrangedSubview(arranged)
            arranged.removeFromSuperview()
        }
        var index = 0
        while index < items.count {
            var rowItems: [KCCustomLineArtMetadata] = []
            for _ in 0..<columns {
                if index < items.count {
                    rowItems.append(items[index])
                    index += 1
                }
            }
            gridStack.addArrangedSubview(makeRow(rowItems))
        }
    }

    private func makeRow(_ rowItems: [KCCustomLineArtMetadata]) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = spacing
        row.distribution = .fillEqually
        row.alignment = .fill
        for item in rowItems {
            let cell = makeCell(for: item)
            cell.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
            row.addArrangedSubview(cell)
        }
        return row
    }

    private func makeCell(for item: KCCustomLineArtMetadata) -> UIView {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor.white
        button.layer.cornerRadius = 18.0
        button.layer.cornerCurve = .continuous
        button.layer.borderColor = KCEditorVisualStyle.subtleBorderColor
        button.layer.borderWidth = 1.0
        button.clipsToBounds = true
        button.accessibilityLabel = item.title
        button.accessibilityIdentifier = "library.my-line-art.\(item.identifier)"
        if let image = thumbnailProvider?(item.identifier) {
            button.setImage(image, for: .normal)
            button.tintColor = UIColor.darkText
            button.contentVerticalAlignment = .fill
            button.contentHorizontalAlignment = .fill
        }
        button.addTarget(self, action: #selector(handleCellTap(_:)), for: .touchUpInside)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleCellLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        button.addGestureRecognizer(longPress)

        // 用关联对象记录 id/title（按钮复用 tag 不够稳）。
        objc_setAssociatedObject(button, &Self.cellIdKey, item.identifier, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(button, &Self.cellTitleKey, item.title, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return button
    }

    private static var cellIdKey: UInt8 = 0
    private static var cellTitleKey: UInt8 = 0

    @objc private func handleSaveAsLineArt() {
        onSaveAsLineArt?()
    }

    @objc private func handleGenerateFromPhoto() {
        onGenerateFromPhoto?()
    }

    @objc private func handleCellTap(_ sender: UIButton) {
        if let id = objc_getAssociatedObject(sender, &Self.cellIdKey) as? String {
            onOpen?(id)
        }
    }

    @objc private func handleCellLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began,
              let button = recognizer.view,
              let id = objc_getAssociatedObject(button, &Self.cellIdKey) as? String,
              let title = objc_getAssociatedObject(button, &Self.cellTitleKey) as? String else {
            return
        }
        // 轻微反馈，提示进入删除确认。
        button.alpha = 0.6
        UIView.animate(withDuration: 0.18) { button.alpha = 1.0 }
        onDelete?(id, title)
    }
}
