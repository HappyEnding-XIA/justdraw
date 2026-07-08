# Main View Controller Decomposition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 逐步拆薄 `KCMainViewController.swift`，降低 App 编辑器页面后续迭代风险，同时保持现有 UIKit/CoreGraphics 行为不变。

**Architecture:** 采用小步、行为保持的 extension / helper 文件拆分。优先移动无状态辅助类型和纯 UI 构建/状态协调代码；高风险流程（保存、草稿、相册、运行时验收）单独排后续任务，不与首轮结构拆分混合。

**Tech Stack:** Swift、UIKit、Xcode project.pbxproj、本地 SPM `KCDomain`/`KCCommon`、`scripts/validate_project.py`。

---

## Target Slices

```text
KidCanvas/Features/Editor/
  KCMainViewController.swift
  KCEditorToolControls.swift
  KCEditorColorBridge.swift
  KCMainViewController+LayoutMetrics.swift
  KCMainViewController+PanelCollapse.swift
  KCMainViewController+ToolSelection.swift
  KCMainViewController+History.swift
  KCMainViewController+DraftAutosave.swift
```

## Task 1: Extract Stateless Editor Helpers

**Files:**
- Create: `KidCanvas/Features/Editor/KCEditorToolControls.swift`
- Create: `KidCanvas/Features/Editor/KCEditorColorBridge.swift`
- Modify: `KidCanvas/Features/Editor/KCMainViewController.swift`
- Modify: `KidCanvas.xcodeproj/project.pbxproj`

- [x] **Step 1: Move button subclasses and tool-mode mapping**

Move `KDToolButton`, `KDBrushButton`, and `KDToolMode <-> KCToolMode` mapping into `KCEditorToolControls.swift`.

- [x] **Step 2: Move `KCHexColor -> UIColor` bridge**

Move `UIColor.init(kcHex:)` into `KCEditorColorBridge.swift`.

- [x] **Step 3: Add both files to the App target Sources**

Update the Xcode project so the new files live under `KidCanvas/Features/Editor` and compile in the `KidCanvas` target.

- [x] **Step 4: Verify**

Run:

```bash
python3 scripts/validate_project.py
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/KidCanvasMainSplit-iPhone build -quiet
```

Expected: both commands exit 0.

## Task 2: Extract Layout Metric Forwarders

**Files:**
- Create: `KidCanvas/Features/Editor/KCMainViewController+LayoutMetrics.swift`
- Modify: `KidCanvas/Features/Editor/KCMainViewController.swift`
- Modify: `KidCanvas.xcodeproj/project.pbxproj`
- Modify if needed: `scripts/validate_project.py`

- [x] **Step 1: Move layout metrics proxy methods**

Move the `// MARK: - 设备布局指标` section into an extension file.

- [x] **Step 2: Keep validation coverage**

If `scripts/validate_project.py` checks those methods by reading only `KCMainViewController.swift`, update it to read the extension file too.

- [x] **Step 3: Verify iPhone and iPad builds**

Run:

```bash
python3 scripts/validate_project.py
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/KidCanvasMainSplit-iPhone build -quiet
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11 M4' -derivedDataPath /tmp/KidCanvasMainSplit-iPad build -quiet
```

Expected: all commands exit 0.

## Task 3: Extract Panel Collapse Coordination

**Files:**
- Create: `KidCanvas/Features/Editor/KCMainViewController+PanelCollapse.swift`
- Modify: `KidCanvas/Features/Editor/KCMainViewController.swift`
- Modify: `KidCanvas.xcodeproj/project.pbxproj`

- [x] **Step 1: Move collapse controls section**

Move `buildCollapseControls()`, `togglePanelsCollapsed(_:)`, `applyPanelsCollapsedAnimated(_:)`, and `refreshToolStateChip()` into the extension.

- [x] **Step 2: Verify behavior remains wired**

Run:

```bash
python3 scripts/validate_project.py
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/KidCanvasMainSplit-iPhone build -quiet
```

Expected: commands exit 0; validation still sees collapse wiring.

## Task 4: Extract Tool Selection Coordination

**Files:**
- Create: `KidCanvas/Features/Editor/KCMainViewController+ToolSelection.swift`
- Modify: `KidCanvas/Features/Editor/KCMainViewController.swift`
- Modify: `KidCanvas.xcodeproj/project.pbxproj`
- Modify: `scripts/validate_project.py`

- [x] **Step 1: Move low-risk tool selection methods**

Move tool, brush, size preview, brush dock scrolling, color selection, custom color picker, eraser shape, sticker selection, and matching button actions into the extension.

- [x] **Step 2: Keep high-risk flows in the main controller**

Keep new canvas, save, history, photo import, line-art replacement, draft autosave, and runtime acceptance in the main controller for later dedicated tasks.

- [x] **Step 3: Verify**

Run:

```bash
python3 scripts/validate_project.py
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/KidCanvasToolSelection-iPhone build -quiet
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11 M4' -derivedDataPath /tmp/KidCanvasToolSelection-iPad build -quiet
swift test --package-path Packages/KidCanvasModules
```

Expected: all commands exit 0.

## Task 5: Extract History UI Coordination

**Files:**
- Create: `KidCanvas/Features/Editor/KCMainViewController+History.swift`
- Modify: `KidCanvas/Features/Editor/KCMainViewController.swift`
- Modify: `KidCanvas.xcodeproj/project.pbxproj`
- Modify: `scripts/validate_project.py`
- Modify: `docs/modules/KCHistoryFeature.md`

- [x] **Step 1: Move history refresh helpers**

Move `refreshHistoryUI(...)`, history pagination helpers, thumbnail identity helpers, placeholder toggling, and async metadata/thumbnail refresh helpers into `KCMainViewController+History.swift`.

- [x] **Step 2: Keep high-risk flows in the main controller**

Keep save, draft autosave, photo import, line-art loading, and runtime acceptance probes in `KCMainViewController.swift` for dedicated follow-up slices.

- [x] **Step 3: Update project and validation coverage**

Add the new extension file to the Xcode Sources phase and make `scripts/validate_project.py` read it as part of the controller composite text.

- [x] **Step 4: Verify**

Run:

```bash
python3 scripts/validate_project.py
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/KidCanvasHistorySplit-iPhone build -quiet
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11 M4' -derivedDataPath /tmp/KidCanvasHistorySplit-iPad build -quiet
swift test --package-path Packages/KidCanvasModules
```

Expected: all commands exit 0.

## Task 6: Extract Image Picking Coordination

**Files:**
- Create: `KidCanvas/Features/Editor/KCMainViewController+ImagePicking.swift`
- Modify: `KidCanvas/Features/Editor/KCMainViewController.swift`
- Modify: `KidCanvas.xcodeproj/project.pbxproj`
- Modify: `scripts/validate_project.py`
- Modify: `docs/architecture/TECHNICAL_DEBT_ROADMAP.md`

- [x] **Step 1: Move photo import entry points**

Move `didTapImportImage()`, `configuredPhotoLibraryPicker()`, `presentPhotoLibraryPicker(...)`, `imagePickerController(...)`, `imagePickerControllerDidCancel(...)`, `finishImportingImage(...)`, and `normalizedImageFromImage(...)` into `KCMainViewController+ImagePicking.swift`.

- [x] **Step 2: Preserve async image normalization**

Keep large photo orientation normalization and downscaling on `imageImportProcessingQueue`; keep `imageImportGeneration` stale-result protection and Debug runtime completion signaling intact.

- [x] **Step 3: Update project and validation coverage**

Add the new extension file to the Xcode Sources phase and make `scripts/validate_project.py` read it as part of the controller composite text.

- [x] **Step 4: Verify**

Run:

```bash
python3 scripts/validate_project.py
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/KidCanvasImagePickingSplit-iPhone build -quiet
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11 M4' -derivedDataPath /tmp/KidCanvasImagePickingSplit-iPad build -quiet
swift test --package-path Packages/KidCanvasModules
```

Expected: all commands exit 0.

## Task 7: Extract Draft Autosave Coordination

**Files:**
- Create: `KidCanvas/Features/Editor/KCMainViewController+DraftAutosave.swift`
- Modify: `KidCanvas/Features/Editor/KCMainViewController.swift`
- Modify: `KidCanvas.xcodeproj/project.pbxproj`
- Modify: `scripts/validate_project.py`
- Modify: `docs/modules/KCSessionPersistence.md`
- Modify: `docs/architecture/TECHNICAL_DEBT_ROADMAP.md`

- [x] **Step 1: Move draft coordination**

Move canvas replacement confirmation, draft protection, draft thumbnail opening, startup draft restore, draft generation guards, draft autosave timer, and scene background draft flushing into `KCMainViewController+DraftAutosave.swift`.

- [x] **Step 2: Preserve background persistence guarantees**

Keep PNG encoding and `saveDraftData(pngData:cachedImage:)` on `draftPersistenceQueue`; keep `draftSaveGeneration`, `draftProtectionGeneration`, and `artworkLoadGeneration` stale-result protection intact.

- [x] **Step 3: Update project, validation, and docs**

Add the new extension file to the Xcode Sources phase, make `scripts/validate_project.py` read it as part of the controller composite text, and update session persistence / roadmap docs.

- [x] **Step 4: Verify**

Run:

```bash
python3 scripts/validate_project.py
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/KidCanvasDraftAutosaveSplit-iPhone build -quiet
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11 M4' -derivedDataPath /tmp/KidCanvasDraftAutosaveSplit-iPad build -quiet
swift test --package-path Packages/KidCanvasModules
```

Expected: all commands exit 0.

## Task 8: Extract Runtime Acceptance Probes

**Files:**
- Create: `KidCanvas/Features/Editor/KCMainViewController+RuntimeAcceptance.swift`
- Modify: `KidCanvas/Features/Editor/KCMainViewController.swift`
- Modify: `KidCanvas.xcodeproj/project.pbxproj`
- Modify: `scripts/validate_project.py`
- Modify: `docs/architecture/TECHNICAL_ARCHITECTURE.md`
- Modify: `docs/architecture/TECHNICAL_DEBT_ROADMAP.md`

- [x] **Step 1: Move Debug-only probe code**

Move runtime acceptance probe dispatch, empty-save, layout, sticker undo/redo, save-history, photo-export-failure, drawing-tools, system-UI probes, and result-writing helpers into `KCMainViewController+RuntimeAcceptance.swift`.

- [x] **Step 2: Keep release behavior unchanged**

Keep the whole extension behind `#if DEBUG`; only expose the probe entry point and the minimal same-target state needed by `viewDidAppear`.

- [x] **Step 3: Update project and validation coverage**

Add the new extension file to the Xcode Sources phase and make `scripts/validate_project.py` read it as part of the controller composite text.

- [x] **Step 4: Verify**

Run:

```bash
python3 scripts/validate_project.py
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/KidCanvasRuntimeAcceptanceSplit-iPhone build -quiet
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11 M4' -derivedDataPath /tmp/KidCanvasRuntimeAcceptanceSplit-iPad build -quiet
swift test --package-path Packages/KidCanvasModules
```

Expected: all commands exit 0.

## Self-Review

- Spec coverage: covers the completed split slices for helpers, layout, panel collapse, tool selection, history UI coordination, image picking coordination, draft autosave coordination, and runtime acceptance probes.
- Placeholder scan: no TBD/TODO placeholders.
- Scope control: keeps formal save, history deletion, and line-art loading as later dedicated slices.
