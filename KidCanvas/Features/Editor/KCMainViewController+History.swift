//
//  KCMainViewController+History.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/08.
//

import UIKit
import KCDomain

// MARK: - 历史

extension KCMainViewController {
    func refreshHistoryUI(
        loadDraftThumbnail: Bool = true,
        preloadThumbnails: Bool = true,
        loadSessions: Bool = true,
        checkDraftExistence: Bool = true
    ) {
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
        let hasDraft = draftImage != nil || (checkDraftExistence && self.sessionStore.hasDraft())
        let selectedSession = self.currentSelectedHistorySession()
        let canDeleteHistoryItem = self.history.canDeleteHistory(
            hasSelectedSession: selectedSession != nil,
            sessionCount: self.sessions.count,
            hasDraft: hasDraft
        )
        let deleteHistoryTitle = self.historyDeleteActionTitle(
            selectedSession: selectedSession,
            hasDraft: hasDraft
        )
        self.deleteHistoryButton.setTitle(deleteHistoryTitle, for: .normal)
        self.deleteHistoryButton.accessibilityLabel = deleteHistoryTitle
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
        self.draftThumbButton.accessibilityLabel = draftImage != nil
            ? KCL10n.draftThumbAvailableAccessibility
            : KCL10n.draftThumbEmptyAccessibility
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
                self.historyThumbSessionIdentifiers[index] = nil
                Self.setHistoryButtonPlaceholderVisible(true, on: button)
                button.isEnabled = false
                button.accessibilityLabel = "\(KCL10n.historyThumbPrefix(status.accessibilityPrefix)) \(index + 1)"
                button.backgroundColor = UIColor(red: 1.0, green: 0.995, blue: 0.98, alpha: 1.0)
                button.transform = .identity
            } else {
                let session = self.sessions[sessionIndex]
                let image = self.sessionStore.cachedThumbnailImage(forSession: session)
                if image == nil {
                    missingVisibleThumbnailIds.append(session.identifier)
                }
                let representsSameSession = self.historyThumbSessionIdentifiers[index] == session.identifier
                if image != nil || !representsSameSession {
                    Self.applyHistoryBackgroundImageIfNeeded(
                        image,
                        identity: self.historyImageIdentityForSession(session, image: image),
                        to: button,
                        storedIdentity: &self.historyThumbImageIdentities[index]
                    )
                }
                self.historyThumbSessionIdentifiers[index] = session.identifier
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

    private func historyDeleteActionTitle(
        selectedSession: KCSessionMetadata?,
        hasDraft: Bool
    ) -> String {
        if selectedSession != nil {
            return KCL10n.deleteSelectedHistoryTitle
        }
        if self.activeSession != nil {
            return KCL10n.deleteCurrentHistoryTitle
        }
        if hasDraft {
            return KCL10n.deleteDraftHistoryTitle
        }
        return KCL10n.deleteLatestHistoryTitle
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

    func replaceLoadedHistorySession(_ session: KCSessionMetadata) {
        self.historySessionRefreshGeneration += 1
        self.sessions.removeAll { $0.identifier == session.identifier }
        self.sessions.insert(session, at: 0)
    }

    func removeLoadedHistorySession(withId sessionId: String) {
        self.historySessionRefreshGeneration += 1
        self.sessions.removeAll { $0.identifier == sessionId }
    }

    private func preloadVisibleHistoryThumbnailsIfNeeded(_ sessionIds: [String]) {
        let uniqueSessionIds = Array(Set(sessionIds))
        guard !uniqueSessionIds.isEmpty else { return }

        let generation = self.historyThumbnailRefreshGeneration + 1
        self.historyThumbnailRefreshGeneration = generation
        self.sessionStore.preloadThumbnailImages(forSessionIds: uniqueSessionIds) { [weak self] in
            guard let self else { return }
            guard self.historyThumbnailRefreshGeneration == generation else { return }
            self.refreshHistoryUI(loadDraftThumbnail: false, preloadThumbnails: false, loadSessions: false)
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
        if self.historyThumbImageIdentities.count != self.historyThumbButtons.count {
            self.historyThumbImageIdentities = Array(repeating: nil, count: self.historyThumbButtons.count)
        }
        if self.historyThumbSessionIdentifiers.count != self.historyThumbButtons.count {
            self.historyThumbSessionIdentifiers = Array(repeating: nil, count: self.historyThumbButtons.count)
        }
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
        clearHistoryButtonForegroundImages(button)
        guard visible else {
            if let placeholderView = button.viewWithTag(Self.historyPlaceholderViewTag) as? UIImageView {
                placeholderView.alpha = 0.0
                placeholderView.isHidden = true
            }
            return
        }

        let placeholderView = historyPlaceholderImageView(on: button)
        placeholderView.alpha = 1.0
        placeholderView.isHidden = false
    }

    private static func clearHistoryButtonForegroundImages(_ button: UIButton) {
        for state in Self.historyThumbnailImageStates {
            button.setImage(nil, for: state)
        }
        button.setImage(nil, for: .normal)
        button.imageView?.contentMode = .center
        button.imageView?.alpha = 0.0
        button.imageView?.isHidden = true
    }

    private static func historyPlaceholderImageView(on button: UIButton) -> UIImageView {
        if let imageView = button.viewWithTag(Self.historyPlaceholderViewTag) as? UIImageView {
            imageView.image = Self.historySlotPlaceholderImage()
            return imageView
        }

        let imageView = UIImageView(image: Self.historySlotPlaceholderImage())
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tag = Self.historyPlaceholderViewTag
        imageView.contentMode = .center
        imageView.isUserInteractionEnabled = false
        imageView.alpha = 0.0
        imageView.isHidden = true
        button.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 30.0),
            imageView.heightAnchor.constraint(equalToConstant: 30.0)
        ])
        return imageView
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
}
