# T116 Brush Performance and Crayon Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate long-stroke jank and zoom-then-draw crayon branching while preserving iPhone/iPad canvas semantics, undo/redo, fill, picker, stamps, save, and history behavior.

**Architecture:** Keep dab generation UIKit-free in `KCDrawingEngine`, add resumable incremental generation state, and let the App canvas append only new dabs. Render completed non-sticker content through one bounded raster cache and render only the active stroke as live dabs; cache the static workbench separately. Keep disk history schema unchanged.

**Tech Stack:** Swift, UIKit, Core Graphics, local Swift Package Manager targets, XCTest, Debug runtime acceptance probes, Xcode iOS Simulator.

---

### Task 1: Resumable Incremental Dab Generator

**Files:**
- Modify: `Packages/KidCanvasModules/Sources/KCDrawingEngine/KCBrushDabGenerator.swift`
- Modify: `Packages/KidCanvasModules/Tests/KCDrawingEngineTests/KCBrushDabGeneratorTests.swift`

- [ ] **Step 1: Write failing incremental-equivalence tests**

Add tests that split the same samples into one-sample and uneven batches and require exact equality with `dabs(for:)`:

```swift
func testIncrementalBatchesExactlyMatchFullGeneration() {
    let samples = line(samples: 80, spacing: 3.0)
    let generator = KCBrushDabGenerator(preset: .preset(for: .crayon))
    let expected = generator.dabs(for: samples)
    var state = KCBrushDabGenerationState()
    var actual: [KCBrushDab] = []
    for batch in samples.chunked(sizes: [1, 3, 7, 2, 11]) {
        actual.append(contentsOf: generator.appendDabs(for: batch, state: &state))
    }
    XCTAssertEqual(actual, expected)
}

func testIncrementalDuplicateSamplesMatchFullGeneration() {
    let samples = [sample(x: 0, y: 0), sample(x: 0, y: 0), sample(x: 12, y: 0)]
    let generator = KCBrushDabGenerator(preset: .preset(for: .pencil))
    var state = KCBrushDabGenerationState()
    let actual = samples.flatMap { generator.appendDabs(for: [$0], state: &state) }
    XCTAssertEqual(actual, generator.dabs(for: samples))
}
```

Implement the test-local `chunked(sizes:)` helper in the test file so no production collection extension is added.

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
swift test --package-path Packages/KidCanvasModules --filter KCBrushDabGeneratorTests
```

Expected: compile failure because `KCBrushDabGenerationState` and `appendDabs(for:state:)` do not exist.

- [ ] **Step 3: Implement resumable generator state**

Add a public UIKit-free state and make full generation reuse the incremental core:

```swift
public struct KCBrushDabGenerationState: Sendable, Equatable {
    var previousSample: KCBrushInputSample?
    var residualDistance: Double = 0
    var nextDabIndex: UInt64 = 0
    public init() {}
}

public func dabs(for samples: [KCBrushInputSample]) -> [KCBrushDab] {
    var state = KCBrushDabGenerationState()
    return appendDabs(for: samples, state: &state)
}

public func appendDabs(
    for samples: [KCBrushInputSample],
    state: inout KCBrushDabGenerationState
) -> [KCBrushDab] {
    // Emit the first dab once, then process only segments from state.previousSample.
}
```

Move the existing segment/residual algorithm into `appendDabs`. Preserve duplicate-sample behavior, exact seed ordering, spacing math, and deterministic output.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the focused test command. Expected: all `KCBrushDabGeneratorTests` pass.

- [ ] **Step 5: Commit the engine increment**

```bash
git add Packages/KidCanvasModules/Sources/KCDrawingEngine/KCBrushDabGenerator.swift Packages/KidCanvasModules/Tests/KCDrawingEngineTests/KCBrushDabGeneratorTests.swift
git commit -m '【xiaoda】perf(brush): 支持增量生成 dab'
```

### Task 2: Crayon Geometry Guardrails

**Files:**
- Modify: `Packages/KidCanvasModules/Sources/KCDrawingEngine/KCBrushPreset.swift`
- Modify: `Packages/KidCanvasModules/Sources/KCDrawingEngine/KCBrushDabGenerator.swift`
- Modify: `Packages/KidCanvasModules/Tests/KCDrawingEngineTests/KCBrushDabGeneratorTests.swift`

- [ ] **Step 1: Write failing crayon-stability tests**

Add tests for the exact jitter contract and finite fallback:

```swift
func testCrayonJitterIsBoundedForZoomStableGeometry() {
    let preset = KCBrushPreset.preset(for: .crayon)
    XCTAssertEqual(preset.jitter, 0.06, accuracy: 1e-9)
    let sample = sample(x: 100, y: 100, pressure: 1.0)
    let dab = KCBrushDabGenerator(preset: preset).dabs(for: [sample]).first!
    XCTAssertLessThanOrEqual(hypot(dab.center.x - 100, dab.center.y - 100), dab.radius * 0.06 + 1e-9)
}

func testNonFiniteTiltFallsBackToStableRoundDab() {
    let bad = sample(x: 0, y: 0, altitude: .nan, azimuth: .infinity)
    let dab = KCBrushDabGenerator(preset: .preset(for: .crayon)).dabs(for: [bad]).first!
    XCTAssertTrue(dab.radius.isFinite)
    XCTAssertTrue(dab.rotation.isFinite)
    XCTAssertEqual(dab.aspectRatio, 1.0, accuracy: 1e-9)
}
```

- [ ] **Step 2: Run focused tests and verify RED**

Expected: jitter assertion fails because current value is `0.18`; non-finite input produces unstable geometry.

- [ ] **Step 3: Implement stable preset and finite guards**

Set crayon `jitter` to `0.06`. Normalize non-finite pressure, velocity, altitude, azimuth, point coordinates, radius, aspect ratio, and rotation at the generator boundary. Keep crayon aspect ratio in `[1.0, 1.35]` and preserve content-coordinate brush size semantics.

- [ ] **Step 4: Run focused and full engine tests**

```bash
swift test --package-path Packages/KidCanvasModules --filter KCBrushDabGeneratorTests
swift test --package-path Packages/KidCanvasModules --filter KCDrawingEngineTests
```

Expected: all pass.

- [ ] **Step 5: Commit geometry stability**

```bash
git add Packages/KidCanvasModules/Sources/KCDrawingEngine/KCBrushPreset.swift Packages/KidCanvasModules/Sources/KCDrawingEngine/KCBrushDabGenerator.swift Packages/KidCanvasModules/Tests/KCDrawingEngineTests/KCBrushDabGeneratorTests.swift
git commit -m '【xiaoda】fix(brush): 稳定缩放后的蜡笔几何'
```

### Task 3: App Adapter and Active-Stroke Incremental Dabs

**Files:**
- Modify: `KidCanvas/Infrastructure/KCDrawingEngineAdapter.swift`
- Modify: `KidCanvas/Features/Canvas/KCDrawingCanvasModels.swift`
- Modify: `KidCanvas/Features/Canvas/KCDrawingCanvasView.swift`
- Modify: `scripts/validate_project.py`

- [ ] **Step 1: Add failing validator requirements**

Require these structures and forbid active-stroke full invalidation:

```python
require_text(canvas_models, "var dabGenerationState = KCBrushDabGenerationState()", "Active strokes retain incremental dab state")
require_text(canvas_view, "appendIncrementalDabs", "Canvas appends only new dabs")
forbid_text(canvas_view, "stroke.cachedDabs = nil\n    }", "Appending samples no longer clears the complete dab cache")
require_text(canvas_view, "copy.samples = stroke.samples", "Undo/redo preserves dab samples")
require_text(canvas_view, "copy.cachedDabs = stroke.cachedDabs", "Undo/redo preserves generated dabs")
```

- [ ] **Step 2: Run validator and verify RED**

Run `/usr/bin/python3 scripts/validate_project.py`. Expected: new T116 checks fail.

- [ ] **Step 3: Extend the drawing-engine provider**

Add an incremental provider method using the same style mapping and line-width-scaled preset as the full method:

```swift
func appendBrushDabs(
    for samples: [KCBrushInputSample],
    state: inout KCBrushDabGenerationState,
    canvasScale: Double,
    brushStyle: Int,
    lineWidth: Double
) -> [KCBrushDab]
```

- [ ] **Step 4: Store incremental state on active strokes**

Add `dabGenerationState` to `KDStroke`. Replace per-sample cache invalidation with a shared `appendIncrementalDabs(_:to:)` helper that:

1. appends samples;
2. asks the provider only for new dabs;
3. appends new dabs to `cachedDabs`;
4. unions new dab bounds into cumulative `cachedRenderBounds`;
5. returns only the new local redraw bounds.

Use the helper from touches began/moved/ended. Keep coalesced touches batched. Do not clear completed dabs on viewport changes.

- [ ] **Step 5: Preserve dab data through state restore**

Update `copyOfStroke(_:)`:

```swift
copy.samples = stroke.samples
copy.cachedDabs = stroke.cachedDabs
```

Generation state need not be copied for completed strokes.

- [ ] **Step 6: Run validator, tests, and drawing-tools runtime**

```bash
/usr/bin/python3 scripts/validate_project.py
swift test --package-path Packages/KidCanvasModules
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" drawing-tools
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" drawing-tools
```

Expected: all pass.

- [ ] **Step 7: Commit App incremental integration**

```bash
git add KidCanvas/Infrastructure/KCDrawingEngineAdapter.swift KidCanvas/Features/Canvas/KCDrawingCanvasModels.swift KidCanvas/Features/Canvas/KCDrawingCanvasView.swift scripts/validate_project.py
git commit -m '【xiaoda】perf(canvas): 增量处理活动画笔 dab'
```

### Task 4: Deterministic Brush-Tip Variants

**Files:**
- Modify: `KidCanvas/Features/Canvas/KCDrawingCanvasView.swift`
- Modify: `scripts/validate_project.py`

- [ ] **Step 1: Add failing validator requirements**

Require a fixed variant count of 8, require the cache key to include a variant index, and require `drawDabs` to select with `dab.seed`.

- [ ] **Step 2: Run validator and verify RED**

Expected: T116 variant checks fail.

- [ ] **Step 3: Implement an eight-image cached variant set**

Use a small reference wrapper cached by style and RGBA color. Build exactly eight 80-point tip images, each with a deterministic seed derived from the preset seed and variant index. In `drawDabs`, choose:

```swift
let variantIndex = Int(dab.seed % UInt64(Self.brushTipVariantCount))
let tip = variants[variantIndex]
```

Create variants before touch movement begins or on first style/color selection; `touchesMoved` must not allocate `UIImage` instances. Variant changes only internal speck placement.

- [ ] **Step 4: Run validator and brush-sample runtime**

```bash
/usr/bin/python3 scripts/validate_project.py
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" brush-samples
```

Expected: pass and write a nonblank sample sheet.

- [ ] **Step 5: Commit texture variants**

```bash
git add KidCanvas/Features/Canvas/KCDrawingCanvasView.swift scripts/validate_project.py
git commit -m '【xiaoda】fix(brush): 使用确定性蜡笔纹理变体'
```

### Task 5: Completed-Content and Workbench Raster Caches

**Files:**
- Modify: `KidCanvas/Features/Canvas/KCDrawingCanvasView.swift`
- Modify: `scripts/validate_project.py`

- [ ] **Step 1: Add failing cache-path validator checks**

Require `draw(_:)` to draw `rasterImageExcludingStickers()` for completed content, require active stroke overlay separately, require a workbench cache key containing bounds/scale/traits, and forbid the committed-stroke loop from the viewport screen draw path.

- [ ] **Step 2: Run validator and verify RED**

Expected: new cache checks fail.

- [ ] **Step 3: Render completed content through the existing bounded cache**

Refactor `draw(_:)` order:

1. draw cached workbench surface in view coordinates;
2. concatenate viewport transform;
3. draw paper shadow;
4. clip to content plane;
5. draw the completed-content raster once;
6. draw active stroke dabs only;
7. draw the paper border.

On stroke completion, if the cache is valid, compose only the completed stroke into a new bounded cache image; otherwise allow one lazy full rebuild. Keep fill, picker, snapshot, background replacement, undo/redo, bounds changes, and memory warning invalidation coherent.

- [ ] **Step 4: Cache the workbench gradient**

Create one `workbenchSurfaceCacheImage` keyed by bounds, screen scale, and interface style. Rebuild only when the key changes or a memory warning clears the cache. Do not include paper, artwork, or stamps.

- [ ] **Step 5: Add Debug counters for proof**

Track completed-stroke replay count and raster rebuild count in Debug. After warming a 300-stroke cache, viewport-only frames must not increase either counter.

- [ ] **Step 6: Run cache regressions**

```bash
/usr/bin/python3 scripts/validate_project.py
swift test --package-path Packages/KidCanvasModules
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" canvas-viewport
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" canvas-viewport
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" save-history-restore
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" save-history-restore
```

Expected: all pass.

- [ ] **Step 7: Commit raster caching**

```bash
git add KidCanvas/Features/Canvas/KCDrawingCanvasView.swift scripts/validate_project.py
git commit -m '【xiaoda】perf(canvas): 缓存完成笔画与工作台渲染'
```

### Task 6: Quantified Brush Interaction Probe

**Files:**
- Modify: `KidCanvas/Features/Canvas/KCDrawingCanvasView.swift`
- Modify: `KidCanvas/Features/Editor/KCMainViewController+RuntimeAcceptance.swift`
- Modify: `scripts/runtime_acceptance_test.sh`
- Modify: `scripts/validate_project.py`

- [ ] **Step 1: Add the `brush-interaction` probe route**

Map `brush-interaction` to `--kc-runtime-brush-interaction-check` and `kc_runtime_brush_interaction.json`.

- [ ] **Step 2: Implement shared-path measurements**

Use 600 deterministic samples in coalesced-style batches. Measure:

- repeated full-prefix regeneration baseline;
- incremental generation total and ratio;
- per-batch timings, P95, and max;
- 300 completed strokes followed by repeated viewport frames;
- replay and raster rebuild counters before/after viewport frames;
- crayon maximum center offset ratio, aspect ratio, and finite geometry.

Write these required fields:

```text
incrementalVsFullRatio <= 0.35
appendBatchP95Ms <= 8.0
appendBatchMaxMs < 50.0
completedStrokeCount == 300
viewportTriggeredStrokeReplay == false
crayonMaxOffsetRatio <= 0.060001
crayonMaxAspectRatio <= 1.35
geometryFinite == true
passed == true
```

- [ ] **Step 3: Run both simulators**

```bash
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" brush-interaction
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" brush-interaction
```

Expected: both JSON results satisfy every threshold. Record timing output in the workboard.

- [ ] **Step 4: Attempt physical old-iPad verification**

If the paired iPad7,11 is available, build and run the same Debug probe on it. Require measured viewport FPS >= 30 and no main-thread interval >= 50 ms. If CoreDevice transport is unavailable, preserve the automated probe evidence and record physical FPS as the only manual acceptance item; do not claim physical-device completion without its output.

- [ ] **Step 5: Commit the performance probe**

```bash
git add KidCanvas/Features/Canvas/KCDrawingCanvasView.swift KidCanvas/Features/Editor/KCMainViewController+RuntimeAcceptance.swift scripts/runtime_acceptance_test.sh scripts/validate_project.py
git commit -m '【xiaoda】test(canvas): 增加画笔交互性能验收'
```

### Task 7: Documentation, Full Verification, Review, and Delivery

**Files:**
- Modify: `docs/modules/KCDrawingEngine.md`
- Modify: `docs/modules/KCDrawingCanvasView.md`
- Modify: `docs/architecture/TECHNICAL_ARCHITECTURE.md`
- Modify: `docs/testing/DELIVERY_ACCEPTANCE_CHECKLIST.md`
- Modify: `ai-docs/AI_WORKBOARD.md` (local ignored board)

- [ ] **Step 1: Update module and architecture documents**

Document incremental state, active-stroke local dirty bounds, jitter `0.06`, eight variants, completed-content cache, workbench cache, memory behavior, performance thresholds, and unchanged history schema.

- [ ] **Step 2: Run complete automated verification**

```bash
swift test --package-path Packages/KidCanvasModules
/usr/bin/python3 scripts/validate_project.py
git diff --check
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" brush-interaction
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" brush-interaction
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" drawing-tools
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" drawing-tools
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" canvas-viewport
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" canvas-viewport
scripts/runtime_acceptance_test.sh "iPhone 17 Pro" save-history-restore
scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" save-history-restore
```

Expected: all pass. Run iPhone/iPad Debug builds explicitly if a runtime probe did not rebuild one destination.

- [ ] **Step 3: Review the complete diff**

Check for behavior regressions, cache invalidation gaps, retained-image growth, duplicated rendering, missing sample copies, and test gaps. Resolve all blocking findings and rerun affected verification.

- [ ] **Step 4: Update the local workboard**

Mark T116 code and automated acceptance complete, record exact timings and commits, and leave physical old-iPad/manual visual acceptance explicit until proven.

- [ ] **Step 5: Commit documentation and any review fixes**

```bash
git add docs KidCanvas Packages scripts
git commit -m '【xiaoda】docs(canvas): 收口 T116 性能与验收边界'
```

- [ ] **Step 6: Push and confirm clean synchronization**

```bash
git push origin main
git status --short --branch
git rev-list --left-right --count main...origin/main
```

Expected: clean worktree and `0 0` divergence.
