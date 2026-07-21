# T104 + T109 Non-AI Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete all remaining non-AI items before T108: migrate photo-library import to PHPicker, reduce redundant glass layers, and add conservative paper margin plus light workbench ambience.

**Architecture:** Keep KCDomain UIKit-free. Photo-library import uses `PhotosUI.PHPickerViewController` in the App layer and reuses the existing async image normalization pipeline; camera import remains on `UIImagePickerController(.camera)`. T109 G4/G5 stay in presentation code only and must not alter saved image data, canvas content coordinates, or history schema.

**Tech Stack:** Swift, UIKit, PhotosUI, KCDomain Swift Package tests, Debug runtime acceptance probes.

---

### Task 1: T104 PHPicker Decision Contract

**Files:**
- Modify: `Packages/KidCanvasModules/Tests/KCDomainTests/KCImageImportTests.swift`
- Modify: `Packages/KidCanvasModules/Sources/KCDomain/KCImageImport.swift`

- [ ] **Step 1: Write failing tests**

Add tests proving `.photoLibrary` presents without requesting full photo-library authorization:

```swift
func testPhotoLibraryNotDeterminedPresentsWithoutAuthorizationRequest() {
    let action = KCImageImportDecision.resolve(source: .photoLibrary, isAvailable: true, authorization: .notDetermined)
    XCTAssertEqual(action, .present)
}

func testPhotoLibraryDeniedStillPresentsPHPicker() {
    let action = KCImageImportDecision.resolve(source: .photoLibrary, isAvailable: true, authorization: .denied)
    XCTAssertEqual(action, .present)
}
```

- [ ] **Step 2: Run red test**

Run: `swift test --package-path Packages/KidCanvasModules --filter KCImageImportTests`

Expected: FAIL because current decision returns `.requestAuthorization` / `.showDeniedFailure`.

- [ ] **Step 3: Implement domain decision**

In `KCImageImportDecision.resolve`, keep unavailable handling first; for `.photoLibrary` return `.present` when available before switching on authorization. Camera behavior remains unchanged.

- [ ] **Step 4: Run green test**

Run: `swift test --package-path Packages/KidCanvasModules --filter KCImageImportTests`

Expected: PASS.

### Task 2: T104 App-Layer PHPicker Migration

**Files:**
- Modify: `KidCanvas/Features/Editor/KCMainViewController.swift`
- Modify: `KidCanvas/Features/Editor/KCMainViewController+ImagePicking.swift`
- Modify: `KidCanvas/Features/Editor/KCMainViewController+RuntimeAcceptance.swift`
- Modify: `KidCanvas/Infrastructure/KCImageImportService.swift`

- [ ] **Step 1: Implement PHPicker**

Import `PhotosUI`, add `PHPickerViewControllerDelegate`, create `configuredPhotoLibraryPicker() -> PHPickerViewController`, set `selectionLimit = 1` and `filter = .images`, and implement `picker(_:didFinishPicking:)`.

- [ ] **Step 2: Reuse normalization**

Extract shared helpers so PHPicker and camera picker both call the same generation guard, background `normalizedImageFromImage`, `finishImportingImage`, and `generateLineArt` branches.

- [ ] **Step 3: Update runtime probe**

Replace `imagePickerUsesPhotoLibrary` with `photoPickerPresented` / `photoPickerDelegateSet`, simulate import through the shared image-processing helper, and keep the clean-session assertions.

### Task 3: T109 G4/G5 Visual Closeout

**Files:**
- Modify: `KidCanvas/Features/Tools/KCBrushStickerPanelView.swift`
- Modify: `KidCanvas/Features/Canvas/KCDrawingCanvasView.swift`
- Modify: `scripts/validate_project.py`

- [ ] **Step 1: Reduce glass layers**

Remove the redundant `shell` background from `KCBrushStickerPanelView`; pin the preview and slider directly to the host panel margins. Keep `sizePreviewView` readable but lighter.

- [ ] **Step 2: Add conservative ambience**

In `KCDrawingCanvasView.draw(_:)`, draw a very light workbench ambience before the paper. Add a small screen-render-only paper display inset for default presentation; do not use it in snapshot/history rendering.

- [ ] **Step 3: Add validator guards**

Require PHPicker, require the T109 G4/G5 identifiers/comments, forbid old `UIImagePickerController(.photoLibrary)` and redundant shell code.

### Task 4: Docs and Verification

**Files:**
- Modify: `docs/modules/KCPhotoLibrary.md`
- Modify: `docs/modules/KCBrushStickerPanelView.md`
- Modify: `docs/modules/KCDrawingCanvasView.md`
- Modify: `docs/architecture/GLASS_MATERIAL_BASELINE.md`
- Modify: `docs/architecture/TECHNICAL_ARCHITECTURE.md`
- Modify: `docs/testing/DELIVERY_ACCEPTANCE_CHECKLIST.md`

- [ ] **Step 1: Update docs**

Record that T104 uses PHPicker for photo library import, camera remains UIImagePicker, and T109 G4/G5 are completed with conservative visual boundaries.

- [ ] **Step 2: Run verification**

Run:

```bash
swift test --package-path Packages/KidCanvasModules --filter KCImageImportTests
swift test --package-path Packages/KidCanvasModules
/usr/bin/python3 scripts/validate_project.py
git diff --check
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" system-ui
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" system-ui
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" drawing-tools
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" drawing-tools
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" layout-safe-area
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" layout-safe-area
```

Expected: all pass, except simulator infrastructure issues must be recorded with exact command output.
