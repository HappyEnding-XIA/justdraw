# App Structure Reorganization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `KidCanvas` App target 从平铺文件结构整理为 App / Features / Infrastructure / DesignSystem / Localization / Resources 分层目录，同时保持 iPhone 与 iPad 可编译、运行行为不变。

**Architecture:** 第一阶段只做物理目录与 Xcode 引用重排，不拆业务逻辑，不改变类名、协议名或模块依赖。SPM 继续保持单 package 多 target；App target 通过目录分层表达职责边界，后续再针对 `KCMainViewController` 与 `KCDrawingCanvasView` 做小步拆分。

**Tech Stack:** UIKit、Swift、Xcode project.pbxproj、本地 Swift Package `Packages/KidCanvasModules`、项目校验脚本 `scripts/validate_project.py`。

---

## Target File Structure

```text
KidCanvas/
  App/
    AppDelegate.swift
    SceneDelegate.swift
    KCAppCompositionRoot.swift
  Features/
    Editor/
      KCMainViewController.swift
      KCEditorPanelsFeature.swift
      KCDeviceLayoutMetrics.swift
    Canvas/
      KCCanvasFeature.swift
      KCDrawingCanvasView.swift
    Tools/
      KCToolRailFeature.swift
      KCBrushDockFeature.swift
      KCEraserControlsFeature.swift
      KCBrushStickerPanelView.swift
    ContentPicker/
      KCContentPickerFeature.swift
      KCColorPalettePanelRenderer.swift
    LineArt/
      KCLineArtFeature.swift
      KCLineArtPickerViewController.swift
    History/
      KCHistoryFeature.swift
  Infrastructure/
    KCDrawingEngineAdapter.swift
    KCSessionService.swift
    LegacyArchiveMigrator.swift
  DesignSystem/
    KCEditorUIFactory.swift
    KCPressFeedbackController.swift
    KCToastPresenter.swift
  Localization/
    KCLocalizedStrings.swift
    zh-Hans.lproj/
    en.lproj/
  Resources/
    Assets.xcassets/
    Info.plist
```

## Task 1: Prepare Current Worktree

**Files:**
- Modify: none

- [ ] **Step 1: Confirm no mixed functional diff remains**

Run:

```bash
git status --short
```

Expected: only files related to this plan are dirty before starting the directory migration.

- [ ] **Step 2: Remove AppleDouble metadata**

Run:

```bash
find KidCanvas KidCanvas.xcodeproj Packages docs scripts -name '._*' -type f -print -delete
```

Expected: any printed `._*` files are deleted and do not appear in `git status --short`.

## Task 2: Move App Target Files

**Files:**
- Move: `KidCanvas/*.swift`
- Move: `KidCanvas/Assets.xcassets`
- Move: `KidCanvas/Info.plist`
- Move: `KidCanvas/*.lproj`

- [ ] **Step 1: Create target directories**

Run:

```bash
mkdir -p KidCanvas/App KidCanvas/Features/Editor KidCanvas/Features/Canvas KidCanvas/Features/Tools KidCanvas/Features/ContentPicker KidCanvas/Features/LineArt KidCanvas/Features/History KidCanvas/Infrastructure KidCanvas/DesignSystem KidCanvas/Localization KidCanvas/Resources
```

- [ ] **Step 2: Move files into responsibility directories**

Run:

```bash
mv KidCanvas/AppDelegate.swift KidCanvas/SceneDelegate.swift KidCanvas/KCAppCompositionRoot.swift KidCanvas/App/
mv KidCanvas/KCMainViewController.swift KidCanvas/KCEditorPanelsFeature.swift KidCanvas/KCDeviceLayoutMetrics.swift KidCanvas/Features/Editor/
mv KidCanvas/KCCanvasFeature.swift KidCanvas/KCDrawingCanvasView.swift KidCanvas/Features/Canvas/
mv KidCanvas/KCToolRailFeature.swift KidCanvas/KCBrushDockFeature.swift KidCanvas/KCEraserControlsFeature.swift KidCanvas/KCBrushStickerPanelView.swift KidCanvas/Features/Tools/
mv KidCanvas/KCContentPickerFeature.swift KidCanvas/KCColorPalettePanelRenderer.swift KidCanvas/Features/ContentPicker/
mv KidCanvas/KCLineArtFeature.swift KidCanvas/KCLineArtPickerViewController.swift KidCanvas/Features/LineArt/
mv KidCanvas/KCHistoryFeature.swift KidCanvas/Features/History/
mv KidCanvas/KCDrawingEngineAdapter.swift KidCanvas/KCSessionService.swift KidCanvas/LegacyArchiveMigrator.swift KidCanvas/Infrastructure/
mv KidCanvas/KCEditorUIFactory.swift KidCanvas/KCPressFeedbackController.swift KidCanvas/KCToastPresenter.swift KidCanvas/DesignSystem/
mv KidCanvas/KCLocalizedStrings.swift KidCanvas/Localization/
mv KidCanvas/zh-Hans.lproj KidCanvas/en.lproj KidCanvas/Localization/
mv KidCanvas/Assets.xcassets KidCanvas/Info.plist KidCanvas/Resources/
```

Expected: `KidCanvas/` root no longer contains App implementation Swift files.

## Task 3: Update Xcode Project References

**Files:**
- Modify: `KidCanvas.xcodeproj/project.pbxproj`

- [ ] **Step 1: Update file reference paths**

Replace each source/resource path in `project.pbxproj` with its new relative path. Examples:

```text
path = App/AppDelegate.swift;
path = Features/Editor/KCMainViewController.swift;
path = Features/Canvas/KCDrawingCanvasView.swift;
path = Infrastructure/KCSessionService.swift;
path = DesignSystem/KCEditorUIFactory.swift;
path = Localization/KCLocalizedStrings.swift;
path = Resources/Assets.xcassets;
path = Resources/Info.plist;
path = Localization/zh-Hans.lproj/Localizable.strings;
```

- [ ] **Step 2: Update build settings that reference Info.plist**

Run:

```bash
rg -n "Info.plist|Assets.xcassets|Localizable.strings|InfoPlist.strings" KidCanvas.xcodeproj/project.pbxproj
```

Expected: Info.plist references point to `KidCanvas/Resources/Info.plist` or `Resources/Info.plist` consistently with existing source tree settings; localization and asset references point to their new paths.

- [ ] **Step 3: Preserve build phase membership**

Run:

```bash
python3 scripts/validate_project.py
```

Expected: if validation fails, only path-location assertions should fail. Fix project references before continuing.

## Task 4: Update Documentation and Validation Rules

**Files:**
- Modify: `docs/architecture/TECHNICAL_ARCHITECTURE.md`
- Modify: `docs/architecture/MODULAR_ARCHITECTURE_DESIGN.md`
- Modify: `docs/modules/README.md`
- Modify: `docs/modules/*.md` where old paths are mentioned
- Modify: `scripts/validate_project.py`

- [ ] **Step 1: Find stale path references**

Run:

```bash
rg -n "KidCanvas/[A-Za-z0-9_]+\\.swift|KidCanvas/Assets\\.xcassets|KidCanvas/Info\\.plist|zh-Hans\\.lproj|en\\.lproj" docs scripts README.md
```

Expected: every result is reviewed and either updated to the new path or intentionally kept as a conceptual reference.

- [ ] **Step 2: Update architecture docs**

Document that App target is now organized by:

```text
App / Features / Infrastructure / DesignSystem / Localization / Resources
```

Keep this invariant: SPM remains a single local package with multiple targets.

- [ ] **Step 3: Update validation script path expectations**

Adjust file existence checks and path-based assertions so `scripts/validate_project.py` validates the new directory layout.

## Task 5: Verify and Commit

**Files:**
- Modify: all moved files and project/docs/scripts updates

- [ ] **Step 1: Clean metadata again**

Run:

```bash
find KidCanvas KidCanvas.xcodeproj Packages docs scripts -name '._*' -type f -print -delete
```

Expected: no source metadata files remain.

- [ ] **Step 2: Run package tests**

Run:

```bash
swift test
```

Working directory: `Packages/KidCanvasModules`

Expected: all tests pass.

- [ ] **Step 3: Run project validation**

Run:

```bash
python3 scripts/validate_project.py
```

Expected: `Validation passed.`

- [ ] **Step 4: Build iPhone and iPad**

Run:

```bash
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/KidCanvasStructure-iPhone build -quiet
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11 M4' -derivedDataPath /tmp/KidCanvasStructure-iPad build -quiet
```

Expected: both commands exit 0.

- [ ] **Step 5: Check diff hygiene**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors; dirty files are only the intended structure/docs/script changes.

- [ ] **Step 6: Commit structure reorganization**

Run:

```bash
git add KidCanvas KidCanvas.xcodeproj docs scripts
git commit -m "【xiaoda】refactor(ios): 重整 App 目录分层"
```

Expected: commit succeeds and `git status --short` is clean.

## Self-Review

- Spec coverage: covers directory migration, Xcode references, docs, validation, iPhone/iPad verification, and commit.
- Placeholder scan: no TODO/TBD placeholders remain.
- Scope control: first stage is behavior-preserving reorganization; large-file extraction is deliberately excluded and should become a later plan after this commit.
