//
//  KCLineArtPickerViewController.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/06.
//

import UIKit

/// 线稿选择弹窗，只负责 UIKit 展示和选择回调，不处理草稿、会话或画布替换。
final class KCLineArtPickerViewController: UIViewController {
    typealias SelectionHandler = (KCLineArtItem) -> Void
    typealias PressFeedbackRegistrar = (UIControl) -> Void

    private let items: [KCLineArtItem]
    private let lineArtFeature: KCLineArtFeature
    private let registerPressFeedback: PressFeedbackRegistrar?
    private let selectionHandler: SelectionHandler

    init(
        items: [KCLineArtItem],
        lineArtFeature: KCLineArtFeature,
        registerPressFeedback: PressFeedbackRegistrar?,
        selectionHandler: @escaping SelectionHandler
    ) {
        self.items = items
        self.lineArtFeature = lineArtFeature
        self.registerPressFeedback = registerPressFeedback
        self.selectionHandler = selectionHandler
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .popover
        self.preferredContentSize = CGSize(width: 450.0, height: 420.0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.accessibilityIdentifier = "line-art.picker"
        self.buildInterface()
    }

    private func buildInterface() {
        let panel = KCEditorVisualStyle.makeGlassEffectView(contentTint: KCEditorVisualStyle.glassContentTintStrong)
        panel.translatesAutoresizingMaskIntoConstraints = false
        KCEditorVisualStyle.applyGlassSurface(to: panel, cornerRadius: KCEditorVisualStyle.lineArtPickerCornerRadius)
        self.view.addSubview(panel)

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
        let rows = (self.items.count + columns - 1) / columns
        for row in 0..<rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 14.0
            rowStack.distribution = .fillEqually
            grid.addArrangedSubview(rowStack)
            rowStack.heightAnchor.constraint(equalToConstant: 132.0).isActive = true

            for column in 0..<columns {
                let index = row * columns + column
                if index >= self.items.count {
                    rowStack.addArrangedSubview(UIView())
                    continue
                }

                let item = self.items[index]
                let button = self.lineArtPreviewButton(for: item, index: index)
                rowStack.addArrangedSubview(button)
            }
        }

        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            panel.topAnchor.constraint(equalTo: self.view.topAnchor),
            panel.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

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
    }

    func lineArtPreviewButton(for item: KCLineArtItem, index: Int) -> UIButton {
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
        var configuration = UIButton.Configuration.plain()
        configuration.image = self.lineArtFeature.cachedThumbnailImage(for: item)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14.0, leading: 18.0, bottom: 14.0, trailing: 18.0)
        button.configuration = configuration
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = KCL10n.lineArtTitle(item.title)
        button.accessibilityIdentifier = "line-art.\(item.title.lowercased())"
        button.addTarget(self, action: #selector(didTapLineArtPreviewButton(_:)), for: .touchUpInside)
        self.registerPressFeedback?(button)
        if configuration.image == nil {
            self.loadLineArtThumbnail(for: item, index: index, button: button)
        }
        return button
    }

    private func loadLineArtThumbnail(for item: KCLineArtItem, index: Int, button: UIButton) {
        self.lineArtFeature.prepareThumbnailImage(for: item) { [weak self, weak button] loadedItem, image in
            guard let self, let button else { return }
            guard index < self.items.count else { return }
            guard button.tag == index, self.items[index].id == loadedItem.id else { return }

            var configuration = button.configuration ?? UIButton.Configuration.plain()
            configuration.image = image
            button.configuration = configuration
            button.imageView?.contentMode = .scaleAspectFit
        }
    }

    @objc private func didTapLineArtPreviewButton(_ button: UIButton) {
        let index = button.tag
        guard index < self.items.count else {
            return
        }
        self.selectionHandler(self.items[index])
    }
}
