# KidCanvas Main Screen Design Brief

## Goal

Create a first-pass main screen for KidCanvas that communicates "open and draw immediately" for children ages 4-10 while still feeling polished enough for parents and stakeholders.

This first mock focuses on the iPad landscape home canvas because it is the clearest flagship surface for the product.

## Reference Baseline

This main-screen concept should explicitly follow the current preview direction already present in the project:

- `docs/product/mockups/ui-preview.html`
- `docs/product/mockups/ui-preview.svg`

The mock is not a blank-slate redesign. It should evolve from the current preview structure, control placement, softness, and overall product mood.

## Keep From Current Preview

- Cream and sky-tinted background
- Full-screen canvas-first shell
- Floating glass panels with large rounded corners
- Top-left action bar and top-right action bar
- Left vertical tool rail
- Right stacked utility panels
- Bottom brush dock
- Soft shadows, bright accent colors, and tactile rounded controls

## Refine From Current Preview

- Make the central canvas more expressive and more clearly child-focused
- Improve first-glance hierarchy so the canvas wins attention over the side panels
- Keep the right column useful but visually secondary
- Preserve the playful feel without introducing a different style language

## Product Intent

- The canvas is the center of gravity.
- Tools must feel simple, playful, and obvious.
- The layout should support both free drawing and guided coloring without switching pages.
- The UI should look warm and toy-like, but not cluttered or babyish.

## Core Screen Structure

The main screen has four persistent regions:

1. Top action bar
2. Left tool rail
3. Center drawing canvas
4. Right utility panel

The canvas must remain visually dominant.

## Top Action Bar

Purpose: high-priority actions and session-level controls.

Include:

- Brand / palette button
- New canvas
- Undo
- Redo
- Line art
- History
- Import
- Save

Design notes:

- Rounded floating panel
- Large icon buttons
- Minimal text on the bar itself
- Save should be the strongest positive action

## Left Tool Rail

Purpose: switching the active creation mode.

Include:

- Brush
- Eraser
- Fill
- Sticker
- Eyedropper

Design notes:

- Vertical stack
- Current tool clearly highlighted
- Icons should be understandable without labels, but the mock may include compact labels if needed

## Center Canvas

Purpose: immediate creative space.

Design notes:

- Large white paper-like drawing area
- Slight rounded corners
- Subtle shadow to separate from the background
- The canvas should already contain a light sample drawing so the screen feels alive
- The sample content should look child-friendly: rainbow, sun, clouds, flowers, doodles, or simple animals

## Right Utility Panel

Purpose: context-sensitive controls for the active tool.

For the first mock, assume Brush mode is active.

Include:

- Color section
- Brush size section
- Recent colors
- Sticker preview strip
- Draft / history preview area

Design notes:

- Split into stacked rounded cards or one scrollable floating panel with clear subsections
- Color dots should feel bright and inviting
- Size control should be visual, not purely numeric

## Visual Direction

- Bright, warm, daylight palette
- Cream, sky blue, coral, mint, sunflower yellow accents
- Soft shadows and glassy floating panels
- Friendly but not overly cartoonish
- Productive enough to feel like a real app, playful enough for kids

## Typography

- Clean rounded sans-serif feeling
- Short labels only
- Avoid dense UI copy

## Localization Considerations

- This screen must later support Chinese and English
- Avoid overlong labels in high-density controls
- Prefer icon-first controls with short text where text is necessary

## Device Target For This Mock

- iPad landscape
- 4:3 style composition
- Designed as a hero main screen concept, not an engineering-accurate pixel spec

## Deliverable

Produce one polished main-screen concept image that can be used to align product, design, and engineering on the flagship interface direction.
