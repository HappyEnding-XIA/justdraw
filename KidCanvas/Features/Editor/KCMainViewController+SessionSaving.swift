//
//  KCMainViewController+SessionSaving.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/08.
//

import UIKit
import KCDomain

// MARK: - 正式保存

extension KCMainViewController {
    @objc func didTapSaveSession() {
        if !self.canvasFeature.hasVisibleContent(self.canvasView) {
            self.showEmptyCanvasSaveToast()
            return
        }

        let snapshot = self.canvasView.snapshotImage()
        let existingSessionId = self.activeSession?.identifier
        let generation = self.nextSessionSaveGeneration()
        self.sessionPersistenceQueue.async { [weak self, snapshot, existingSessionId] in
            guard let self else { return }
            guard let encodedData = self.sessionStore.encodedArtworkData(from: snapshot) else {
                self.finishFailedSessionSaveIfCurrent(generation)
                return
            }
            guard self.isSessionSaveGenerationCurrent(generation) else { return }
            guard let savedSession = self.sessionStore.saveArtwork(
                pngData: encodedData.pngData,
                thumbnailJPEGData: encodedData.thumbnailJPEGData,
                existingSessionId: existingSessionId
            ) else {
                self.finishFailedSessionSaveIfCurrent(generation)
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.finishSavingSession(
                    savedSession: savedSession,
                    generation: generation,
                    photoExportImageData: encodedData.pngData
                )
            }
        }
    }

    private func finishSavingSession(
        savedSession: KCSessionMetadata,
        generation: Int,
        photoExportImageData: Data
    ) {
        let saveStillMatchesVisibleCanvas = self.isSessionSaveGenerationCurrent(generation)

        self.activeSession = savedSession
        self.selectedHistorySession = savedSession
        self.replaceLoadedHistorySession(savedSession)
        self.activeSessionHasUnsavedChanges = !saveStillMatchesVisibleCanvas
        if saveStillMatchesVisibleCanvas {
            self.invalidateDraftSaveTimer()
            self.clearDraftAndInvalidateCurrentDraftMarker()
        }
        self.historyPageIndex = 0
        self.refreshHistoryUI(loadDraftThumbnail: false, loadSessions: false)
        self.refreshActionButtons()
        self.showSaveToastWithSuccess(true)
        self.exportSavedArtworkToPhotoLibrary(imageData: photoExportImageData)
    }

    private func finishFailedSessionSaveIfCurrent(_ generation: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.isSessionSaveGenerationCurrent(generation) else { return }
            self.showSaveToastWithSuccess(false)
        }
    }

    private func exportSavedArtworkToPhotoLibrary(imageData: Data) {
        Task { [weak self, imageData] in
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--kc-runtime-photo-export-failure-check") {
                try? await Task.sleep(nanoseconds: 120_000_000)
                await MainActor.run {
                    self?.showPhotoExportFailedToast()
                }
                return
            }
#endif
            guard let self else { return }
            let exported = await self.photoLibraryService.export(imageData: imageData)
            guard !exported else { return }
            await MainActor.run {
                self.showPhotoExportFailedToast()
            }
        }
    }

    func invalidateSessionSaveWork() {
        self.sessionSaveGenerationLock.lock()
        defer { self.sessionSaveGenerationLock.unlock() }
        self.sessionSaveGeneration += 1
    }

    @discardableResult
    private func nextSessionSaveGeneration() -> Int {
        self.sessionSaveGenerationLock.lock()
        defer { self.sessionSaveGenerationLock.unlock() }
        self.sessionSaveGeneration += 1
        return self.sessionSaveGeneration
    }

    private func isSessionSaveGenerationCurrent(_ generation: Int) -> Bool {
        self.sessionSaveGenerationLock.lock()
        defer { self.sessionSaveGenerationLock.unlock() }
        return self.sessionSaveGeneration == generation
    }
}
