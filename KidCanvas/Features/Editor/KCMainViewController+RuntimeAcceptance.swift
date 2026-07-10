//
//  KCMainViewController+RuntimeAcceptance.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/08.
//

import UIKit
import KCDrawingEngine
import KCDomain

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
        let shouldRunCanvasViewportProbe = arguments.contains("--kc-runtime-canvas-viewport-check")
        let shouldRunContentLibraryProbe = arguments.contains("--kc-runtime-content-library-check")
        guard shouldRunEmptySaveProbe
                || shouldRunLayoutProbe
                || shouldRunStickerProbe
                || shouldRunSaveHistoryProbe
                || shouldRunPhotoExportFailureProbe
                || shouldRunDrawingToolsProbe
                || shouldRunSystemUIProbe
                || shouldRunBrushSamplesProbe
                || shouldRunBrushPerfProbe
                || shouldRunCanvasViewportProbe
                || shouldRunContentLibraryProbe else {
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
            } else if shouldRunCanvasViewportProbe {
                self?.runCanvasViewportAcceptanceProbe()
            } else if shouldRunContentLibraryProbe {
                self?.runContentLibraryAcceptanceProbe()
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

    /// T097/T106/T107：画布导航运行时验收。验证默认视图居中、非默认视口下坐标转换非恒等、
    /// 放大后双指平移会改变 viewport、填色/取色同内容点一致（不偏移）、
    /// 缩小态（scale<1）双指平移不被强制吸回中心（T107）、
    /// 恢复视图回到默认、恢复按钮按状态显隐。
    private func runCanvasViewportAcceptanceProbe() {
        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.invalidateDraftSaveTimer()
        self.suppressNextDraftSave = true
        self.canvasView.startBlankCanvas()
        self.clearDraftAndInvalidateCurrentDraftMarker()
        self.refreshHistoryUI()
        self.refreshActionButtons()
        self.view.layoutIfNeeded()
        // 先注入面板感知安全创作区，让默认视图按创作区居中。
        self.canvasView.applyViewportRect(self.canvasCreationRect())

        let defaultIsDefault = self.canvasView.viewportIsAtDefault
        let restoreButtonHiddenAtDefault = self.restoreViewportButton.isHidden

        // 设非默认视口：放大 2 倍并平移。
        self.canvasView.runtimeAcceptanceSetViewport(scale: 2.0, translation: CGPoint(x: 120.0, y: -80.0))
        let afterSetIsDefault = self.canvasView.viewportIsAtDefault
        let restoreButtonShownAfterSet = self.restoreViewportButton.isHidden == false
        let scaleAfterSet = self.canvasView.currentViewportScale
        self.view.layoutIfNeeded()
        let restoreFrameAfterSet = self.restoreViewportButton.convert(self.restoreViewportButton.bounds, to: self.view)
        let collapseFrameAfterSet = self.collapseToggleButton.convert(self.collapseToggleButton.bounds, to: self.view)
        let floatingButtonsDoNotOverlap = !restoreFrameAfterSet.intersects(collapseFrameAfterSet)

        // 屏幕中心经 viewport 反变换得到内容点，验证转换非恒等（缩放下内容点应与屏幕点不同）。
        let canvasBounds = self.canvasView.bounds
        let screenCenter = CGPoint(x: canvasBounds.midX, y: canvasBounds.midY)
        let contentPoint = self.canvasView.runtimeAcceptanceCanvasPoint(forScreenPoint: screenCenter)
        let conversionNonIdentity = abs(contentPoint.x - screenCenter.x) > 1.0
            || abs(contentPoint.y - screenCenter.y) > 1.0

        // T106：模拟双指平移，验收真实平移入口会改变 translation，且同一屏幕点对应的内容点
        // 会按手指方向产生反向变化，证明放大状态下画布内容能跟手移动。
        let translationBeforePan = self.canvasView.currentViewportTranslation
        let contentPointBeforePan = contentPoint
        let panDelta = CGPoint(x: -60.0, y: 44.0)
        self.canvasView.runtimeAcceptanceApplyViewportTranslation(panDelta)
        let translationAfterPan = self.canvasView.currentViewportTranslation
        let contentPointAfterPan = self.canvasView.runtimeAcceptanceCanvasPoint(forScreenPoint: screenCenter)
        let viewportTranslationChanged = abs(translationAfterPan.x - translationBeforePan.x) > 1.0
            || abs(translationAfterPan.y - translationBeforePan.y) > 1.0
        let contentPointChangedAfterPan = abs(contentPointAfterPan.x - contentPointBeforePan.x) > 1.0
            || abs(contentPointAfterPan.y - contentPointBeforePan.y) > 1.0
        let panContentDirectionMatches = contentPointAfterPan.x > contentPointBeforePan.x
            && contentPointAfterPan.y < contentPointBeforePan.y

        // 同一内容点先填色再取色，验证填色与取色解析到同一内容像素（缩放/平移不偏移）。
        let contentSize = CGSize(width: max(canvasBounds.width, 1.0), height: max(canvasBounds.height, 1.0))
        let normalized = CGPoint(x: contentPointAfterPan.x / contentSize.width, y: contentPointAfterPan.y / contentSize.height)
        let fillColor = UIColor(red: 0.20, green: 0.60, blue: 0.30, alpha: 1.0)
        self.canvasView.currentColor = fillColor
        let fillSucceeded = self.canvasView.performRuntimeAcceptanceFloodFill(atNormalizedPoint: normalized)
        self.canvasView.currentToolMode = .picker
        let pickedColor = self.canvasView.runtimeAcceptancePickedColor(atNormalizedPoint: normalized)
        let pickedMatchesFill = self.color(pickedColor, matchesColor: fillColor)

        // T107：缩小态（scale < 1.0）也必须允许双指平移，不能强制吸回中心。
        // 用最低缩放 0.5 保证双端（iPhone/iPad）缩放后内容都小于安全创作区，从而命中新的
        // “重叠钳制”分支；旧实现会把任何缩小态平移强制吸回居中（translation 不变）。
        let scaledDownCentered = self.canvasView.runtimeAcceptanceDefaultTranslation(forScale: 0.5)
        self.canvasView.runtimeAcceptanceSetViewport(scale: 0.5, translation: scaledDownCentered)
        let scaledDownScaleAfterSet = self.canvasView.currentViewportScale
        let scaledDownTranslationBeforePan = self.canvasView.currentViewportTranslation
        let scaledDownContentPointBeforePan = self.canvasView.runtimeAcceptanceCanvasPoint(forScreenPoint: screenCenter)
        self.canvasView.runtimeAcceptanceApplyViewportTranslation(CGPoint(x: 48.0, y: -36.0))
        let scaledDownTranslationAfterPan = self.canvasView.currentViewportTranslation
        let scaledDownContentPointAfterPan = self.canvasView.runtimeAcceptanceCanvasPoint(forScreenPoint: screenCenter)
        let scaledDownScaleUnderOne = scaledDownScaleAfterSet < 1.0
        let scaledDownViewportTranslationChanged = abs(scaledDownTranslationAfterPan.x - scaledDownTranslationBeforePan.x) > 1.0
            || abs(scaledDownTranslationAfterPan.y - scaledDownTranslationBeforePan.y) > 1.0
        let scaledDownContentPointChangedAfterPan = abs(scaledDownContentPointAfterPan.x - scaledDownContentPointBeforePan.x) > 1.0
            || abs(scaledDownContentPointAfterPan.y - scaledDownContentPointBeforePan.y) > 1.0
        // 缩小态平移后 translation 不应等于默认居中（证明未被强制吸回中心）。
        let scaledDownNotCentered = abs(scaledDownTranslationAfterPan.x - scaledDownCentered.x) > 1.0
            || abs(scaledDownTranslationAfterPan.y - scaledDownCentered.y) > 1.0

        // 恢复视图。
        self.canvasView.restoreDefaultViewport()
        let afterRestoreIsDefault = self.canvasView.viewportIsAtDefault
        let restoreButtonHiddenAfterRestore = self.restoreViewportButton.isHidden

        let passed = defaultIsDefault
            && restoreButtonHiddenAtDefault
            && !afterSetIsDefault
            && restoreButtonShownAfterSet
            && floatingButtonsDoNotOverlap
            && abs(scaleAfterSet - 2.0) < 0.01
            && conversionNonIdentity
            && viewportTranslationChanged
            && contentPointChangedAfterPan
            && panContentDirectionMatches
            && fillSucceeded
            && pickedMatchesFill
            && scaledDownScaleUnderOne
            && scaledDownViewportTranslationChanged
            && scaledDownContentPointChangedAfterPan
            && scaledDownNotCentered
            && afterRestoreIsDefault
            && restoreButtonHiddenAfterRestore

        let result: [String: Any] = [
            "probe": "canvas-viewport",
            "passed": passed,
            "defaultIsDefault": defaultIsDefault,
            "restoreButtonHiddenAtDefault": restoreButtonHiddenAtDefault,
            "afterSetIsDefault": afterSetIsDefault,
            "restoreButtonShownAfterSet": restoreButtonShownAfterSet,
            "floatingButtonsDoNotOverlap": floatingButtonsDoNotOverlap,
            "restoreFrameAfterSet": self.dictionary(for: restoreFrameAfterSet),
            "collapseFrameAfterSet": self.dictionary(for: collapseFrameAfterSet),
            "scaleAfterSet": scaleAfterSet,
            "screenCenter": self.dictionary(for: CGRect(origin: screenCenter, size: .zero)),
            "contentPoint": self.dictionary(for: CGRect(origin: contentPoint, size: .zero)),
            "conversionNonIdentity": conversionNonIdentity,
            "panDelta": self.dictionary(for: CGRect(origin: panDelta, size: .zero)),
            "translationBeforePan": self.dictionary(for: CGRect(origin: translationBeforePan, size: .zero)),
            "translationAfterPan": self.dictionary(for: CGRect(origin: translationAfterPan, size: .zero)),
            "contentPointBeforePan": self.dictionary(for: CGRect(origin: contentPointBeforePan, size: .zero)),
            "contentPointAfterPan": self.dictionary(for: CGRect(origin: contentPointAfterPan, size: .zero)),
            "viewportTranslationChanged": viewportTranslationChanged,
            "contentPointChangedAfterPan": contentPointChangedAfterPan,
            "panContentDirectionMatches": panContentDirectionMatches,
            "fillSucceeded": fillSucceeded,
            "pickedMatchesFill": pickedMatchesFill,
            "scaledDownScaleAfterSet": scaledDownScaleAfterSet,
            "scaledDownScaleUnderOne": scaledDownScaleUnderOne,
            "scaledDownCenteredTranslation": self.dictionary(for: CGRect(origin: scaledDownCentered, size: .zero)),
            "scaledDownTranslationBeforePan": self.dictionary(for: CGRect(origin: scaledDownTranslationBeforePan, size: .zero)),
            "scaledDownTranslationAfterPan": self.dictionary(for: CGRect(origin: scaledDownTranslationAfterPan, size: .zero)),
            "scaledDownContentPointBeforePan": self.dictionary(for: CGRect(origin: scaledDownContentPointBeforePan, size: .zero)),
            "scaledDownContentPointAfterPan": self.dictionary(for: CGRect(origin: scaledDownContentPointAfterPan, size: .zero)),
            "scaledDownViewportTranslationChanged": scaledDownViewportTranslationChanged,
            "scaledDownContentPointChangedAfterPan": scaledDownContentPointChangedAfterPan,
            "scaledDownNotCentered": scaledDownNotCentered,
            "afterRestoreIsDefault": afterRestoreIsDefault,
            "restoreButtonHiddenAfterRestore": restoreButtonHiddenAfterRestore
        ]
        self.writeRuntimeAcceptanceResult(result, fileName: "kc_runtime_acceptance_canvas_viewport.json")
    }

    /// T098：内容库运行时验收。验证浮层默认关闭、可打开；分区切换；官方线稿非空且不可删除；
    /// 历史与我的线稿分区容器按分区显隐；我的线稿为空态；可关闭。
    private func runContentLibraryAcceptanceProbe() {
        self.activeSession = nil
        self.selectedHistorySession = nil
        self.activeSessionHasUnsavedChanges = false
        self.invalidateDraftSaveTimer()
        self.suppressNextDraftSave = true
        self.canvasView.startBlankCanvas()
        self.clearDraftAndInvalidateCurrentDraftMarker()
        self.refreshHistoryUI()
        self.refreshActionButtons()
        self.view.layoutIfNeeded()

        let initiallyHidden = self.contentLibraryPanelView?.isHidden ?? true
        let featureInitiallyHidden = !self.contentLibrary.isPanelVisible

        // 打开内容库（默认官方线稿分区）。
        self.setContentLibraryPanelVisible(true)
        let panelShown = !(self.contentLibraryPanelView?.isHidden ?? true)
        let featureVisible = self.contentLibrary.isPanelVisible
        let defaultPartitionIsOfficial = self.contentLibrary.currentPartition == .officialLineArt
        let pickerEmbedded = self.contentLibraryLineArtPicker != nil
        let officialContainerVisible = !(self.contentLibraryPanelView?.officialLineArtContainer.isHidden ?? true)

        let officialItemCount = self.currentLineArtItems().count
        let officialNotEmpty = officialItemCount > 0
        // 官方线稿分区不可删除（分区能力由 KCDomain 守护）。
        let officialNotDeletable = !self.contentLibrary.canDelete(in: .officialLineArt, itemCount: officialItemCount)

        // 切到历史分区：容器可见、分区选中。
        let historyIndex = KCContentLibraryPartition.defaultOrder.firstIndex(of: .history) ?? 2
        self.contentLibraryPanelView?.showPartition(index: historyIndex)
        self.contentLibrary.selectPartition(.history)
        let historySelected = self.contentLibrary.currentPartition == .history
        let historyContainerVisible = !(self.contentLibraryPanelView?.historyContainer.isHidden ?? true)

        // 切到我的线稿分区：空态、容器可见、不可删除（空）。
        let myIndex = KCContentLibraryPartition.defaultOrder.firstIndex(of: .myLineArt) ?? 1
        self.contentLibraryPanelView?.showPartition(index: myIndex)
        self.contentLibrary.selectPartition(.myLineArt)
        let myLineArtSelected = self.contentLibrary.currentPartition == .myLineArt
        let myLineArtContainerVisible = !(self.contentLibraryPanelView?.myLineArtContainer.isHidden ?? true)
        let myLineArtEmpty = self.contentLibrary.isEmpty(partition: .myLineArt, itemCount: 0)
        let myLineArtNotDeletableWhenEmpty = !self.contentLibrary.canDelete(in: .myLineArt, itemCount: 0)

        // T102：分区顺序固定为 官方/我的/历史（3 个可见主分区），imports 为预留且不在 defaultOrder。
        let mainPartitionCount = KCContentLibraryPartition.defaultOrder.count
        let mainPartitionOrderIsFixed = KCContentLibraryPartition.defaultOrder == [.officialLineArt, .myLineArt, .history]
        let importsReserved = !KCContentLibraryPartition.defaultOrder.contains(.imports)
            && !KCContentLibraryPartition.imports.isMainPartition

        // T102：历史空态与实际数据一致（无已保存会话且无草稿时显示“还没有历史作品”）。
        let historyEmptyExpected = self.sessions.isEmpty && !self.sessionStore.hasDraft()
        let historyEmptyMatches = (self.contentLibraryPanelView?.isHistoryEmptyVisible ?? false) == historyEmptyExpected

        // T099：我的线稿保存/删除（同步 Debug 钩子；store 异步路径与上限/命名已由单测覆盖）。
        let myLineArtGridEmbedded = self.myLineArtGridView != nil
        let customLineArtCountBefore = self.customLineArtService.count()
        let historyCountBefore = self.sessions.count

        // 空画布保存为线稿 → “线条过少”校验门拦截，计数不变。
        self.canvasView.startBlankCanvas()
        self.runtimeAcceptanceLastSaveToastTitle = nil
        self.didTapSaveAsLineArt()
        let tooFewStrokesToastShown = self.runtimeAcceptanceLastSaveToastTitle == KCL10n.saveAsLineArtTooFewStrokesTitle
        let gateBlockedSave = self.customLineArtService.count() == customLineArtCountBefore

        // 画 3 笔后保存为线稿 → 计数 +1、分配编号、历史作品不受影响。
        self.canvasView.currentToolMode = .brush
        self.canvasView.currentLineWidth = 20.0
        self.canvasView.insertRuntimeAcceptanceStroke()
        self.canvasView.insertRuntimeAcceptanceStroke()
        self.canvasView.insertRuntimeAcceptanceStroke()
        let lineArtImage = self.canvasView.lineArtImage()
        let saved = self.customLineArtService.runtimeAcceptanceSaveSynchronously(image: lineArtImage, sourceSessionId: nil)
        let saveSucceeded = saved != nil
        let sequenceNumberAssigned = (saved?.sequenceNumber ?? 0) >= 1
        let countIncreased = self.customLineArtService.count() == customLineArtCountBefore + 1
        let historyUnaffectedBySave = self.sessions.count == historyCountBefore

        // 删除刚保存的线稿 → 计数回到保存前；历史仍不受影响。
        if let savedId = saved?.identifier {
            self.customLineArtService.runtimeAcceptanceDeleteSynchronously(identifier: savedId)
        }
        let deleteRestoredCount = self.customLineArtService.count() == customLineArtCountBefore
        let historyUnaffectedByDelete = self.sessions.count == historyCountBefore

        // T100：图片导入——模拟器无相机走降级分支；相册来源不走 noCamera。
        let cameraDecision = self.imageImportService.decideAction(for: .camera)
        let photoDecision = self.imageImportService.decideAction(for: .photoLibrary)
        let cameraNoCameraFallback = cameraDecision == .showNoCamera
        let photoNotNoCamera = photoDecision != .showNoCamera

        // T101：离线线稿提取器对合成卡通图返回可用结果，且“从照片生成线稿”入口已接线。
        let generateEntryWired = self.myLineArtGridView?.onGenerateFromPhoto != nil
        let syntheticSource = Self.runtimeAcceptanceLineArtSourcePNG()
        let extraction = self.lineArtExtractor.extract(from: syntheticSource)
        let extractionUsable = extraction?.quality.isUsable ?? false
        let extractionHasData = !(extraction?.lineArtPNG.isEmpty ?? true) && !(extraction?.thumbnailJPEG.isEmpty ?? true)

        // 关闭内容库。
        self.setContentLibraryPanelVisible(false)

        let passed = initiallyHidden
            && featureInitiallyHidden
            && panelShown
            && featureVisible
            && defaultPartitionIsOfficial
            && pickerEmbedded
            && officialContainerVisible
            && officialNotEmpty
            && officialNotDeletable
            && historySelected
            && historyContainerVisible
            && myLineArtSelected
            && myLineArtContainerVisible
            && myLineArtEmpty
            && myLineArtNotDeletableWhenEmpty
            && mainPartitionCount == 3
            && mainPartitionOrderIsFixed
            && importsReserved
            && historyEmptyMatches
            && myLineArtGridEmbedded
            && tooFewStrokesToastShown
            && gateBlockedSave
            && saveSucceeded
            && sequenceNumberAssigned
            && countIncreased
            && historyUnaffectedBySave
            && deleteRestoredCount
            && historyUnaffectedByDelete
            && photoNotNoCamera
            && generateEntryWired
            && extractionUsable
            && extractionHasData

        let result: [String: Any] = [
            "probe": "content-library",
            "passed": passed,
            "initiallyHidden": initiallyHidden,
            "featureInitiallyHidden": featureInitiallyHidden,
            "panelShown": panelShown,
            "featureVisible": featureVisible,
            "defaultPartitionIsOfficial": defaultPartitionIsOfficial,
            "pickerEmbedded": pickerEmbedded,
            "officialContainerVisible": officialContainerVisible,
            "officialItemCount": officialItemCount,
            "officialNotEmpty": officialNotEmpty,
            "officialNotDeletable": officialNotDeletable,
            "historySelected": historySelected,
            "historyContainerVisible": historyContainerVisible,
            "myLineArtSelected": myLineArtSelected,
            "myLineArtContainerVisible": myLineArtContainerVisible,
            "myLineArtEmpty": myLineArtEmpty,
            "myLineArtNotDeletableWhenEmpty": myLineArtNotDeletableWhenEmpty,
            "mainPartitionCount": mainPartitionCount,
            "mainPartitionOrderIsFixed": mainPartitionOrderIsFixed,
            "importsReserved": importsReserved,
            "historyEmptyExpected": historyEmptyExpected,
            "historyEmptyMatches": historyEmptyMatches,
            "myLineArtGridEmbedded": myLineArtGridEmbedded,
            "tooFewStrokesToastShown": tooFewStrokesToastShown,
            "gateBlockedSave": gateBlockedSave,
            "saveSucceeded": saveSucceeded,
            "sequenceNumberAssigned": sequenceNumberAssigned,
            "customLineArtCountBefore": customLineArtCountBefore,
            "countIncreased": countIncreased,
            "historyUnaffectedBySave": historyUnaffectedBySave,
            "deleteRestoredCount": deleteRestoredCount,
            "historyUnaffectedByDelete": historyUnaffectedByDelete,
            "cameraNoCameraFallback": cameraNoCameraFallback,
            "photoNotNoCamera": photoNotNoCamera,
            "generateEntryWired": generateEntryWired,
            "extractionUsable": extractionUsable,
            "extractionHasData": extractionHasData
        ]
        self.writeRuntimeAcceptanceResult(result, fileName: "kc_runtime_acceptance_content_library.json")
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

    /// T101：合成白底 + 多个黑色形状的 PNG，作为离线线稿提取的卡通样例源。
    private static func runtimeAcceptanceLineArtSourcePNG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400.0, height: 400.0))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 400.0, height: 400.0))
            UIColor.black.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 60.0, y: 250.0, width: 110.0, height: 110.0))
            context.cgContext.fillEllipse(in: CGRect(x: 240.0, y: 250.0, width: 110.0, height: 110.0))
            context.cgContext.fill(CGRect(x: 150.0, y: 110.0, width: 100.0, height: 80.0))
            context.cgContext.fill(CGRect(x: 60.0, y: 60.0, width: 90.0, height: 30.0))
            context.cgContext.fill(CGRect(x: 250.0, y: 60.0, width: 90.0, height: 30.0))
        }
        return image.pngData() ?? Data()
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
