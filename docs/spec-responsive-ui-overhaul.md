# Spec: Responsive UI overhaul

## Objective

Make PixelLab Studio usable and visually stable across common Windows window
sizes and DPI settings without removing the features inherited from the
WeebLabs fork. Resizing must preserve the avatar's framing, keep controls
reachable, and prevent sidebars or dialogs from overlapping or being cut off.

Acceptance behaviour:

- The application opens at a safe usable size even when an older settings file
  contains a tiny, invalid, or off-screen window size.
- The native window has a minimum size of 960 x 540 logical pixels, adjusted
  for the active display scale without exceeding the usable screen area.
- The content uses one 1280 x 720 reference coordinate system and one explicit
  DPI scale; project-level and runtime scale factors no longer compound.
- Resizing preserves the avatar's relative framing. User zoom remains an
  independent multiplier, so a rig shown at 100% stays proportionally framed
  after a resize rather than becoming cropped.
- The avatar origin stays centered unless the user has deliberately panned it.
- Left and right panels clamp their widths against valid bounds even during
  startup or very narrow transient viewport sizes.
- At the supported minimum size, the center canvas remains usable and panel
  controls do not overlap each other.
- Long panel content and modal content remain reachable through scrolling or
  viewport-bounded sizing.
- Existing native hotkey chords and all PixelLab Studio features remain intact.

## Tech stack

- Godot 4.6 / GDScript
- Existing Node2D/CanvasLayer scene architecture
- Existing JSON-backed user settings
- Pure layout-policy utility covered by headless tests
- No new runtime dependencies

## Commands

From the repository root, using the local Godot 4.6 console binary:

```powershell
Godot_v4.6.1-stable_win64_console.exe --headless --path test --script responsive_layout_test.gd
Godot_v4.6.1-stable_win64_console.exe --headless --path test --script hotkey_binding_test.gd
Godot_v4.6.1-stable_win64_console.exe --headless --path . --editor --quit
Godot_v4.6.1-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" build/PixelLabStudio.exe
```

## Project structure

- `autoload/responsive_layout.gd`: pure window, camera-fit, panel-width, and
  popup-bound calculations.
- `main_scenes/main.gd`: display-scale setup, safe settings restoration,
  resize integration, camera zoom composition, and central layout dispatch.
- `ui_scenes/spriteEditMenu/sprite_viewer.gd`: responsive left sidebar.
- `ui_scenes/spriteList/viewer.gd`: responsive right sidebar.
- `test/responsive_layout_test.gd`: headless layout-policy regressions.
- Dialog scripts/scenes are changed only when the responsive foundation proves
  a concrete overflow at the supported test sizes.

## Code style

Keep layout calculations pure and named by intent. Runtime nodes apply the
returned values but do not duplicate breakpoint formulas. Use tabs for
GDScript indentation and preserve the surrounding file's naming conventions.

```gdscript
var layout := ResponsiveLayout.window_layout(viewport_size, user_zoom)
camera.zoom = Vector2.ONE * layout.camera_zoom
```

Magic values belong in the layout policy as documented constants. Avoid adding
new per-frame allocations or rebuilding the scene tree during resize.

## Testing strategy

Headless unit tests cover:

- invalid and legacy saved window sizes;
- DPI-aware minimum native window sizes and screen-bound clamping;
- proportional camera fit at 960 x 540, 1280 x 720, and 1920 x 1080;
- user zoom remaining independent from resize fit;
- asymmetric window aspect ratios using the limiting dimension;
- valid sidebar width bounds when the available viewport is narrow;
- popup rectangles staying inside the viewport.

Integration checks import the complete project and run existing hotkey tests.
Manual visual QA uses 960 x 540, 1280 x 720, 1920 x 1080, maximized, and a
resize drag. It checks the avatar, both sidebars, settings, costume controls,
layer list, file dialogs, and representative custom dialogs.

## Boundaries

- Always: preserve saved avatar compatibility, keep user zoom/pan, retain the
  current dark visual identity, and verify every increment before continuing.
- Ask first: remove a feature, redesign a workflow, migrate save-file schemas,
  or change the native background-input extension.
- Never: solve layout by hiding controls without an accessible alternative,
  require an external utility, or overwrite the user's existing portable test
  build while it may be running.

## Success criteria

- No supported test size opens with overlapping primary panels or clipped
  essential controls.
- Resizing does not crop a previously framed avatar solely because the viewport
  changed.
- A corrupt `120 x 74` saved window size is repaired automatically.
- Left and right panel width calculations never receive inverted clamp bounds.
- All new layout tests and existing native-hotkey tests pass.
- The full project imports without script errors.
- A separate portable Windows executable is produced for user testing.

## Approved decisions

- Keep PixelLab Studio as the base instead of restarting from the older
  kaiakairos project.
- Use automatic proportional avatar fit during resize.
- Rebuild the responsive foundation before cosmetic panel cleanup.
- Preserve the current feature set and native double-binding work.

