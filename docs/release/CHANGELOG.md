# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project currently tracks changes in a simple manual form.

## [Unreleased]

### Added — Swift-first foundation layers (SPM package)

Built the pure-Swift, UIKit-free foundation of the modular architecture
(`Packages/KidCanvasModules`) as testable SPM targets. The Objective-C app
target is unchanged; these modules are not yet wired into the app. 79 unit
tests pass (`swift test`).

- `KCCommon`: `HexColor` (RGBA + hex, Codable, prototype-faithful `lrint`
  rounding), `KCError`, and a pluggable logging seam (`KCLog`/`KCLogging`).
- `KCDomain`: completed the value model — enriched `Stroke` (points, pressure
  stats, `averagePressure`), `StickerItem` + `StickerTransform`,
  `CanvasSnapshot`, `EditorState` (centralized tool state matching the
  prototype defaults), `ContentPalette`/`StickerGroup`/`LineArtTemplate`,
  and repository protocols (`SessionRepository`, `PhotoLibraryServicing`).
- `KCDrawingEngine` (CoreGraphics-only, no UIKit): `BitmapBuffer`,
  `FloodFillEngine` (faithful BFS port with the prototype's
  `tolerance*4` Manhattan-delta rule and overflow guards), `ColorSampler`,
  `PressureModel` (ported force normalization), `StrokeRenderMath` (ported
  per-brush width/alpha formulas), and `EraserStampPath`
  (circle/cloud/star stamp generation).
- `KCContentCatalog`: built-in 24/36-color palettes, four sticker categories,
  and the eight line-art template entries — ported verbatim from the
  Objective-C content arrays.
- `KCSessionPersistence`: `SessionStore` implementing `SessionRepository`
  with the same on-disk layout as the prototype
  (`Documents/KidCanvasSessions/`, `<uuid>.png`, `<uuid>-thumb.jpg`,
  `draft.png`, JSON metadata with `schemaVersion`), partial-failure rollback,
  and a `LegacySessionMigrator` seam for the old `sessions.archive`.

### Integrated — SPM package wired into App target (Phase 2)

- Linked `Packages/KidCanvasModules` as a local SPM package via
  `XCLocalSwiftPackageReference` in `project.pbxproj`. All 5 modules
  are now linked: `KCCommon`, `KCDomain`, `KCContentCatalog`,
  `KCDrawingEngine`, `KCSessionPersistence`.
- Set `SWIFT_VERSION = 5.0` on the `KidCanvas` target (both Debug/Release).
- Added `KidCanvas/KCContentBridge.swift`, the first Swift source file in
  the App target. It exposes `ContentCatalogDefaults` (palettes, stickers,
  line-art) to Objective-C via `@objc(KCContentBridge)` static methods.
- All Objective-C source files are unchanged and the app builds cleanly
  for both iPhone 17 Pro and iPad Pro 11 M4 simulators. No new warnings
  introduced by the integration.

### Migrated — canvas engine logic to Swift (Phase 5 start)

- Linked `KCDrawingEngine` to the App target (4 of 5 modules linked at that
  point; `KCSessionPersistence` was linked subsequently, completing all 5).
- Added `KidCanvas/KCDrawingEngineBridge.swift`, a `@objc` adapter exposing
  `FloodFillEngine`, `ColorSampler`, and `PressureModel` to Objective-C.
- Replaced three OC algorithms in `KDDrawingCanvasView.m` with Swift
  bridge calls (canvas state management stays in OC):
  - `performFloodFillAtPoint:color:` — ~170 lines of inline BFS → single
    `FloodFillEngine` call.
  - `colorAtPoint:` — ~35 lines of 1×1 bitmap sampling → single
    `ColorSampler` call.
  - `normalizedPressureForTouch:` — ~10 lines of force math → single
    `PressureModel` call.
- Added a hand-authored `KidCanvas/KCDrawingEngineBridge.h`. The
  auto-generated `KidCanvas-Swift.h` is emitted **empty** in this project's
  Xcode 16 configuration (`-experimental-emit-module-separately` quirk;
  the `@objc` symbols are confirmed present in the compiled objects). The
  hand-authored header declares the same interface with selectors verified
  against the compiled binary.
- Build: `generic/platform=iOS Simulator` **BUILD SUCCEEDED** (universal
  binary, 36 Swift engine symbols confirmed present). Device-specific
  simulator builds fail due to a Rosetta/x86_64 simulator vs arm64 SPM
  package mismatch in this environment — an environment issue, not a code
  issue.

### Migrated — stroke rendering metrics + eraser stamp path to Swift (T003)

- Refactored `StrokeRenderMath` to expose a primitive
  `renderedMetrics(brushStyle:lineWidth:pressure:)` method (the existing
  `metrics(for:)` now delegates to it).
- Added 3 new bridge methods to `KCDrawingEngineBridge.swift`:
  `renderedStrokeLineWidth`, `renderedStrokeAlpha` (delegate to
  `StrokeRenderMath`), and `eraserStampPath` (returns `UIBezierPath`,
  delegates to `EraserStampPath`). Updated hand-authored
  `KCDrawingEngineBridge.h` with verified selectors.
- Replaced `drawStroke:` switch block (~15 lines of per-brush width/alpha
  math) with a single Swift bridge call in `KDDrawingCanvasView.m`.
- Replaced `eraserShapePathForShape:center:size:` (~30 lines of
  circle/cloud/star CGPath generation) with a single Swift bridge call.
- Added 3 unit tests for the primitive `renderedMetrics` method
  (agreement with full model, floor at 1.0, crayon pressure scaling).
- Build: all iPhone 17 Pro, iPad Pro 11 M4, and generic simulator
  builds pass. `swift test`: 82 tests, 0 failures.
  `validate_project.py`: passes.
- Remaining OC logic: `drawCrayonGrainForPath:` (crayon texture — needs
  visual regression), sticker gestures, `KDMainViewController`,
  `KDSessionStore`, app lifecycle.

### Linked — KCSessionPersistence (all 5 SPM modules now wired)

- Linked `KCSessionPersistence` as the final SPM module dependency
  (5 of 5 modules linked).
- Added `KidCanvas/SessionStoreBridge.swift` — minimal `@objc` bridge
  over the Swift `SessionStore`, exposing `shared`, `hasSavedSessions`,
  `loadDraftData`, `clearDraft`, `sessionCount` to prove the dependency
  links and compiles.
- Added hand-authored `KidCanvas/SessionStoreBridge.h` with verified
  selectors.
- Full session migration (replacing OC `KDSessionStore` usage in
  `KDMainViewController` with the Swift `SessionStore`) is a follow-up
  task.
- Build: iPhone 17 Pro, iPad Pro 11 M4, generic simulator — all pass.
  `swift test`: 82 tests, 0 failures.



## [0.1.0] - 2026-06-22

### Added

- Initial `KidCanvas` UIKit / Objective-C iPad drawing app prototype.
- Landscape-only, single-screen canvas experience with floating tool panels.
- Core drawing tools including pencil, pen, crayon, fill, and eraser.
- Color workflow including 24/36 color palettes, custom color picker, and eyedropper.
- Sticker workflow with built-in stickers plus move, scale, rotate, reorder, and delete interactions.
- Built-in line art templates for fill mode.
- Undo and redo support across drawing and editing actions.
- Artwork save flow with session history, thumbnails, draft restore, and delete support.
- Photo import support and Photos save integration.
- Local validation script for project structure and requested feature coverage.
- README documentation with run, validation, scope, and simulator checklist guidance.
