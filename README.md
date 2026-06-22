# KidCanvas

UIKit / Objective-C drawing app prototype for iPad. The first version is landscape-only and uses a full-screen canvas with floating tool panels.

## Run

1. Open `KidCanvas.xcodeproj` in Xcode on macOS.
2. Select an iPad simulator, for example iPad Pro 11-inch.
3. Build and run the `KidCanvas` scheme.
4. Rotate the simulator to landscape if needed.

This repository was prepared from Windows, so `xcodebuild` has not been run locally in this workspace.
On macOS, the shared scheme is `KidCanvas`, so command-line verification can use `xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' build` after confirming the simulator name on that Mac.

## Validate

Run the lightweight local checks before opening Xcode:

```bash
python scripts/validate_project.py
```

This verifies plist/json parsing, project references, Objective-C source structure, iPad landscape settings, the no-Chinese-UI rule, and source-level coverage for the requested drawing, color, fill, sticker, line-art, history, import, and save features.

## Scope

- iPad only.
- Landscape only.
- Single canvas-first screen.
- Floating controls with no Chinese UI text.
- 24/36 color palettes, custom color picker, and eyedropper.
- Pencil, pen, crayon, fill, eraser, sticker, undo, redo, import, save.
- Eraser size slider plus circle, cloud, and star shapes.
- Built-in line art templates for fill mode.
- Built-in stickers. Sticker import is intentionally out of v1.
- Saved history with thumbnails, draft restore, photo import, and delete.

## Simulator Checklist

- Draw with pencil, pen, and crayon; verify width slider changes stroke size.
- Tap once with brush and eraser; verify a dot/stamp appears.
- Switch 24/36 palettes, custom color, and eyedropper.
- Use fill on a closed line art region.
- Add, move, pinch, rotate, bring forward, and delete stickers.
- Save artwork; verify it appears in History and Photos permission flow behaves correctly.
- Relaunch after drawing; verify draft thumbnail and restore.
- Import a photo from the library, then save/delete the session.
- Use undo/redo across draw, fill, import, line art, sticker insert, and sticker transform.
