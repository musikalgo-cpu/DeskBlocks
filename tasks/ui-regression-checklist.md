# DeskBlocks UI Regression Checklist

Use this checklist after changes to AppKit window behavior, block rendering, tile viewport behavior, drag-and-drop, folder references, or persistence.

## Commands

- [ ] `swift build`
- [ ] `swift run DeskBlocksCoreChecks`

## Block Viewport And Resize

- [ ] Create or use a block with 30+ tiles.
- [ ] Resize to one column, then resize taller again.
- [ ] Resize to one row, then resize wider again.
- [ ] Enable `Lock Block` and confirm the block cannot be moved or resized.
- [ ] Confirm locked blocks can still be unlocked from an occupied folder tile or app menu; fully transparent empty areas may show the macOS Desktop menu in the MVP.
- [ ] Disable `Lock Block` and confirm move and resize work again.
- [ ] Confirm the viewport shows at most 10 full rows and 10 full columns.
- [ ] Confirm the block stays inside the visible screen bounds after large resize and move operations.
- [ ] Quit and relaunch; confirm a previously narrow/high tile viewport does not expand offscreen.

## Overflow And Scroll

- [ ] Confirm overflow indicators appear only above/below the tile grid, never on the sides.
- [ ] Confirm indicators have dedicated space and do not overlap tile content.
- [ ] Confirm vertical scrolling moves by whole rows, not individual tile slots.
- [ ] Confirm a partially filled final row is reachable by scrolling.
- [ ] Confirm scrolling back to the top returns to the first row.

## Folder References

- [ ] Use `Choose Folder...` on a visible tile and confirm the folder label appears in that tile.
- [ ] Drag a folder from a Finder window onto a tile.
- [ ] Drag a folder directly from the Desktop onto a tile.
- [ ] Scroll a block, then drop a folder onto a visible tile and confirm it lands in that visible target.
- [ ] Double-click a referenced tile and confirm the folder opens.
- [ ] Remove a folder reference and confirm the Finder folder remains unchanged.

## Visual Behavior

- [ ] Confirm block background is fully transparent outside frame, title, folder icons, labels, chevrons, and hover/drag affordances.
- [ ] Confirm title and folder labels are pure white and readable on the user's desktop.
- [ ] Change a block title color through the native color picker and confirm the title updates immediately.
- [ ] Enable `Hide Empty Tiles` and confirm empty folder placeholders disappear while occupied folder tiles remain visible.
- [ ] Drag a folder onto a hidden empty tile area and confirm magnetic placement still works.
- [ ] Confirm magnetic hover feels subtle and neutral, not system-accent colored.
- [ ] Confirm the block title remains centered while resizing.

## Persistence Smoke

- [ ] Create, resize, scroll, place folders, quit, and relaunch.
- [ ] Confirm persisted block title, title color, empty tile visibility, lock state, position, size, tile count, and folder references restore correctly.
- [ ] Confirm hidden tile references remain reachable through scrolling after relaunch.
