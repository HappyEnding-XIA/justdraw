//
//  KCMainViewController+DraftAutosave.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/08.
//

import UIKit

// MARK: - 草稿自动保存

extension KCMainViewController {
    func performCanvasReplacementAfterUserConfirmation(_ replacement: @escaping () -> Void) {
        guard self.shouldConfirmCanvasReplacement() else {
            replacement()
            return
        }

        let alert = UIAlertController(
            title: KCL10n.replaceCanvasAlertTitle,
            message: KCL10n.replaceCanvasAlertMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: KCL10n.cancelTitle, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: KCL10n.saveDraftAndContinueTitle, style: .default, handler: { [weak self] _ in
            guard let self else { return }
            self.protectCurrentCanvasDraftBeforeReplacement { [weak self] saved in
                guard let self else { return }
                guard saved else {
                    self.showSaveToastWithSuccess(false)
                    return
                }
                replacement()
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }

    private func shouldConfirmCanvasReplacement() -> Bool {
        guard self.canvasFeature.hasVisibleContent(self.canvasView) else {
            return false
        }
        if self.activeSession != nil && !self.activeSessionHasUnsavedChanges {
            return false
        }
        if self.activeDraftMatchesCanvas && self.sessionStore.hasDraft() {
            return false
        }
        return true
    }

    private func protectCurrentCanvasDraftBeforeReplacement(completion: @escaping (Bool) -> Void) {
        if self.activeSession != nil && !self.activeSessionHasUnsavedChanges {
            completion(true)
            return
        }

        if self.activeDraftMatchesCanvas && self.sessionStore.hasDraft() {
            completion(true)
            return
        }

        if !self.canvasFeature.hasVisibleContent(self.canvasView) {
            self.activeDraftMatchesCanvas = false
            completion(true)
            return
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
                    self.activeDraftMatchesCanvas = false
                    self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
                    completion(false)
                }
                return
            }

            guard self.isDraftProtectionGenerationCurrent(generation) else { return }
            let saved = self.sessionStore.saveDraftData(pngData: pngData, cachedImage: snapshot)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.isDraftProtectionGenerationCurrent(generation) else { return }
                self.activeDraftMatchesCanvas = saved
                self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
                completion(saved)
            }
        }
    }

    @objc func didTapDraftThumb() {
        self.performCanvasReplacementAfterUserConfirmation { [weak self] in
            self?.openDraftThumb()
        }
    }

    private func openDraftThumb() {
        let generation = self.nextArtworkLoadGeneration()
        self.draftPersistenceQueue.async { [weak self] in
            guard let self else { return }
            guard let data = self.sessionStore.loadDraftData(),
                  let draftImage = self.sessionStore.displayDecodedImage(from: data) else { return }

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
                self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
                self.refreshActionButtons()
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
                    self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
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
                self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
            }
        }
        return true
    }

    func clearDraftAndInvalidateCurrentDraftMarker() {
        self.nextDraftProtectionGeneration()
        self.sessionStore.clearDraft()
        self.activeDraftMatchesCanvas = false
    }

    func scheduleStartupDeferredWorkIfNeeded() {
        guard !self.didScheduleStartupDeferredWork else { return }
        self.didScheduleStartupDeferredWork = true
        self.scheduleStartupDeferredTask(after: KCStartupDeferredDelay.colorControls) { controller in
            controller.loadColorControlsAfterStartupIfNeeded()
        }
        self.scheduleStartupDeferredTask(after: KCStartupDeferredDelay.restoreDraft) { controller in
            controller.restoreDraftIfNeeded()
        }
        self.scheduleStartupDeferredTask(after: KCStartupDeferredDelay.historySessions) { controller in
            controller.refreshHistorySessionsAsync(loadDraftThumbnail: false)
        }
        self.scheduleStartupDeferredTask(after: KCStartupDeferredDelay.stickerButtons) { controller in
            controller.loadStickerButtonsAfterStartupIfNeeded()
        }
    }

    private func scheduleStartupDeferredTask(after delay: TimeInterval, perform work: @escaping (KCMainViewController) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            work(self)
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
                  let draftImage = self.sessionStore.displayDecodedImage(from: data) else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.artworkLoadGeneration == generation else { return }
                guard self.activeSession == nil else { return }
                guard !self.canvasFeature.hasVisibleContent(self.canvasView) else { return }

                self.sessionStore.cacheLoadedDraftImage(draftImage)
                self.suppressNextDraftSave = true
                self.canvasView.restoreCanvas(with: draftImage)
                self.activeDraftMatchesCanvas = true
                self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
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
            self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
            return
        }

        if !self.canvasFeature.hasVisibleContent(self.canvasView) {
            self.clearDraftAndInvalidateCurrentDraftMarker()
            self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
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
                    self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
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
                self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
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
}
