# KidCanvas

KidCanvas is a drawing app project for kids on iPhone and iPad. This repository contains the current prototype, product documentation, architecture documentation, and the migration plan toward a `Swift-first + SPM modular` codebase.

中文版本: [README.md](/Volumes/xiaoda_SSD/KidCanvas/justdraw/README.md)

## Current Status

- The repository still contains the existing prototype implementation for reference.
- The architecture direction is now clearly defined as `Swift-first`, `SPM modularization`, `UIKit/Core Graphics canvas core`, and `SwiftUI panels where appropriate`.
- Official documents have been organized under `docs/`.
- AI collaboration materials live under `ai-docs/` and are intended to stay out of version control by default.

## Documentation

- Product requirements:
  [docs/product/prd.md](/Volumes/xiaoda_SSD/KidCanvas/justdraw/docs/product/prd.md)
- Technical architecture:
  [docs/architecture/TECHNICAL_ARCHITECTURE.md](/Volumes/xiaoda_SSD/KidCanvas/justdraw/docs/architecture/TECHNICAL_ARCHITECTURE.md)
- Modular architecture:
  [docs/architecture/MODULAR_ARCHITECTURE_DESIGN.md](/Volumes/xiaoda_SSD/KidCanvas/justdraw/docs/architecture/MODULAR_ARCHITECTURE_DESIGN.md)
- Coding standards:
  [docs/architecture/CODING_STANDARDS.md](/Volumes/xiaoda_SSD/KidCanvas/justdraw/docs/architecture/CODING_STANDARDS.md)
- Module decoupling:
  [docs/architecture/MODULE_DECOUPLING_GUIDELINES.md](/Volumes/xiaoda_SSD/KidCanvas/justdraw/docs/architecture/MODULE_DECOUPLING_GUIDELINES.md)
- Release notes:
  [docs/release/CHANGELOG.md](/Volumes/xiaoda_SSD/KidCanvas/justdraw/docs/release/CHANGELOG.md)
- AI collaboration workspace:
  `ai-docs/`

## Quick Start

1. Open `KidCanvas.xcodeproj` in Xcode on macOS.
2. Select an iPhone or iPad simulator and run the `KidCanvas` scheme.
3. If you want to build from the command line, confirm the available simulator name on your machine first, then run:

```bash
xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=KidCanvas iPad Pro 11 M4' build
```

## Local Validation

To run the lightweight validation script bundled with this repository:

```bash
python3 scripts/validate_project.py
```

The script mainly verifies:

- plist / json parsing
- Xcode project references
- iPhone / iPad landscape configuration
- Prototype coverage for drawing, fill, stickers, history, import, and export flows

## Repository Layout

- `KidCanvas/`: current app source
- `docs/`: official documentation
- `ai-docs/`: local AI collaboration documents
- `scripts/`: helper scripts

## Maintenance Notes

- Chinese is the primary language for project-facing documentation, with English support where needed.
- Formal design and engineering documents should be written under `docs/`.
- New architecture and code should follow the modular, layered, and decoupled design rules.
