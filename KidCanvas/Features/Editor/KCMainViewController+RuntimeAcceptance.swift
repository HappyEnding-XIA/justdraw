//
//  KCMainViewController+RuntimeAcceptance.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/08.
//

import UIKit
import KCDrawingEngine

#if DEBUG

extension KCMainViewController {
    // MARK: - 运行时验收探针

    func runRuntimeAcceptanceProbeIfNeeded() {
        if self.runtimeAcceptanceProbeDidRun {
            return
        }

        let arguments = ProcessInfo.processInfo.arguments
        let shouldRunEmptySaveProbe = arguments.contains("--kc-runtime-empty-save-check")
        let shouldRunLayoutProbe = arguments.contains("--kc-runtime-layout-check")
        let shouldRunStickerProbe = arguments.contains("--kc-runtime-sticker-check")
        let shouldRunSaveHistoryProbe = arguments.contains("--kc-runtime-save-history-check")
        let shouldRunPhotoExportFailureProbe = arguments.contains("--kc-runtime-photo-export-failure-check")
        let shouldRunDrawingToolsProbe = arguments.contains("--kc-runtime-drawing-tools-check")
        let shouldRunSystemUIProbe = arguments.contains("--kc-runtime-system-ui-check")
        let shouldRunBrushSamplesProbe = arguments.contains("--kc-runtime-brush-samples-check")
        let shouldRunBrushPerfProbe = arguments.contains("--kc-runtime-brush-perf-check")
        guard shouldRunEmptySaveProbe
                || shouldRunLayoutProbe
                || shouldRunStickerProbe
                || shouldRunSaveHistoryProbe
                || shouldRunPhotoExportFailureProbe
                || shouldRunDrawingToolsProbe
                || shouldRunSystemUIProbe
                || shouldRunBrushSamplesProbe
                || shouldRunBrushPerfProbe else {
            return
        }
        self.runtimeAcceptanceProbeDidRun = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if shouldRunBrushSamplesProbe {
                self?.runBrushSamplesAcceptanceProbe()
            } else if shouldRunBrushPerfProbe {
                self?.runBrushPerfAcceptanceProbe()
            } else if shouldRunLayoutProbe {
                self?.runLayoutAcceptanceProbe()
            } else if shouldRunStickerProbe {
                self?.runStickerUndoRedoAcceptanceProbe()
            } else if shouldRunSaveHistoryProbe {
                self?.runSaveHistoryAcceptanceProbe()
            } else if shouldRunPhotoExportFailureProbe {
                self?.runPhotoExportFailureAcceptanceProbe()
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
        let emptySaveToastVisible = self.saveToastView?.accessibilityLabel == KCL10n.emptySaveToastTitle
        let result: [String: Any] = [
            "probe": "empty-save",
            "passed": !hasVisibleContentBefore
                && saveButtonEnabledBeforeTap
                && emptySaveToastVisible
                && self.sessions.count == historyCountBefore,
            "hasVisibleContentBefore": hasVisibleContentBefore,
            "saveButtonEnabledBeforeTap": saveButtonEnabledBeforeTap,
            "emptySaveToastVisible": emptySaveToastVisible,
            "historyCountBefore": historyCountBefore,
            "historyCountAfter": self.sessions.count,
            "expectedToast": KCL10n.emptySaveToastTitle
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
        if let savedSession {
            self.deleteSavedHistorySession(savedSession)
        }
        let afterDeleteHistoryCount = self.sessions.count
        let afterDeleteVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        let afterDeleteActiveSessionId = self.activeSession?.identifier ?? ""
        let afterDeleteSelectedSessionId = self.selectedHistorySession?.identifier ?? ""

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
                && !afterOpenCanRedo
                && afterDeleteHistoryCount == initialHistoryCount
                && !afterDeleteVisible
                && afterDeleteActiveSessionId.isEmpty
                && afterDeleteSelectedSessionId.isEmpty,
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
            "afterDeleteHistoryCount": afterDeleteHistoryCount,
            "afterDeleteVisible": afterDeleteVisible,
            "afterDeleteActiveSessionId": afterDeleteActiveSessionId,
            "afterDeleteSelectedSessionId": afterDeleteSelectedSessionId,
            "openSucceeded": openSucceeded,
            "expectedToast": KCL10n.saveSuccessToastTitle
        ]
        self.writeRuntimeAcceptanceResult(result, fileName: "kc_runtime_acceptance_save_history.json")
    }

    private func runPhotoExportFailureAcceptanceProbe() {
        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.invalidateDraftSaveTimer()
        self.suppressNextDraftSave = true
        self.canvasView.startBlankCanvas()
        self.clearDraftAndInvalidateCurrentDraftMarker()
        self.runtimeAcceptanceLastSaveToastTitle = nil
        self.runtimeAcceptanceLastPhotoExportToastTitle = nil
        self.refreshHistoryUI()
        self.refreshActionButtons()

        let initialHistoryCount = self.sessions.count
        let initialVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        self.canvasView.currentColor = UIColor(red: 0.24, green: 0.58, blue: 0.40, alpha: 1.0)
        self.canvasView.currentToolMode = .brush
        self.canvasView.currentBrushStyle = .pen
        self.canvasView.currentLineWidth = 18.0
        self.canvasView.insertRuntimeAcceptanceStroke()
        self.refreshActionButtons()

        let afterDrawVisible = self.canvasFeature.hasVisibleContent(self.canvasView)
        self.didTapSaveSession()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            let afterSaveHistoryCount = self.sessions.count
            let afterSaveActiveSessionId = self.activeSession?.identifier ?? ""
            let afterSaveSelectedSessionId = self.selectedHistorySession?.identifier ?? ""
            let localSaveToastObserved = self.runtimeAcceptanceLastSaveToastTitle == KCL10n.saveSuccessToastTitle
            let photoExportFailureObserved = self.runtimeAcceptanceLastPhotoExportToastTitle == KCL10n.photoExportFailedToastTitle
            let currentToastTitle = self.saveToastView?.accessibilityLabel ?? ""
            let photoExportFailureToastTitle = self.runtimeAcceptanceLastPhotoExportToastTitle ?? ""

            let result: [String: Any] = [
                "probe": "photo-export-failure",
                "passed": !initialVisible
                    && afterDrawVisible
                    && afterSaveHistoryCount == initialHistoryCount + 1
                    && !afterSaveActiveSessionId.isEmpty
                    && afterSaveActiveSessionId == afterSaveSelectedSessionId
                    && localSaveToastObserved
                    && photoExportFailureObserved
                    && photoExportFailureToastTitle == KCL10n.photoExportFailedToastTitle
                    && currentToastTitle != KCL10n.saveFailedToastTitle,
                "initialHistoryCount": initialHistoryCount,
                "afterSaveHistoryCount": afterSaveHistoryCount,
                "afterSaveActiveSessionId": afterSaveActiveSessionId,
                "afterSaveSelectedSessionId": afterSaveSelectedSessionId,
                "localSaveToastObserved": localSaveToastObserved,
                "photoExportFailureObserved": photoExportFailureObserved,
                "photoExportFailureToastTitle": photoExportFailureToastTitle,
                "currentToastTitle": currentToastTitle,
                "forbiddenToast": KCL10n.saveFailedToastTitle,
                "expectedPhotoExportToast": KCL10n.photoExportFailedToastTitle
            ]
            self.writeRuntimeAcceptanceResult(result, fileName: "kc_runtime_acceptance_photo_export_failure.json")
        }
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

    // MARK: - 画笔样张 / 性能基线探针（T095）

    private func runBrushSamplesAcceptanceProbe() {
        let image = self.canvasView.renderBrushSampleSheet()
        var result: [String: Any] = [
            "probe": "brush-samples",
            "passed": image != nil
        ]
        if let image, let png = image.pngData(),
           let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let imageURL = documentsURL.appendingPathComponent("kc_runtime_brush_samples.png")
            try? png.write(to: imageURL, options: [.atomic])
            result["imageFileName"] = "kc_runtime_brush_samples.png"
            result["imageWidth"] = image.size.width
            result["imageHeight"] = image.size.height
        }
        self.writeRuntimeAcceptanceResult(result, fileName: "kc_runtime_brush_samples.json")
    }

    private func runBrushPerfAcceptanceProbe() {
        // 用一段代表性 stroke（铅笔，dab 最密、最重）测 dab 生成耗时，建立 100/300 条 stroke 基线。
        var samples: [KCBrushInputSample] = []
        var time: TimeInterval = 0
        var x: CGFloat = 0
        while x <= 1000 {
            samples.append(KCBrushInputSample(point: CGPoint(x: x, y: 0), timestamp: time,
                                              pressure: 1.0, velocity: 0,
                                              altitude: Double.pi / 2.0, azimuth: 0, isPencil: true))
            x += 8
            time += 0.016
        }
        let sampleCount = samples.count

        func measureGenerate(strokeCount: Int) -> Double {
            let start = CFAbsoluteTimeGetCurrent()
            for _ in 0..<strokeCount {
                _ = self.canvasView.drawingEngine.brushDabs(for: samples, canvasScale: 1.0,
                                                            brushStyle: KDBrushStyle.pencil.rawValue)
            }
            return (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        }

        let result: [String: Any] = [
            "probe": "brush-perf",
            "passed": true,
            "sampleCount": sampleCount,
            "generate100StrokesMs": measureGenerate(strokeCount: 100),
            "generate300StrokesMs": measureGenerate(strokeCount: 300)
        ]
        self.writeRuntimeAcceptanceResult(result, fileName: "kc_runtime_brush_perf.json")
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
}
#endif
