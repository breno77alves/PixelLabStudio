# Plan: Responsive UI overhaul

## Increment 1 - Tested layout policy

- Add failing tests for window restoration, DPI minimums, camera fit, sidebar
  bounds, and popup bounds.
- Implement a pure `ResponsiveLayout` utility until the policy tests pass.
- Keep this increment independent from live scene nodes.

Files: `test/responsive_layout_test.gd`, `autoload/responsive_layout.gd`.

## Increment 2 - Window and camera foundation

- Normalize the project reference viewport and remove compounded stretch scale.
- Apply a single display-scale policy at startup.
- Repair saved window sizes before applying them and set a native minimum.
- Compose automatic viewport fit with the user's zoom percentage.
- Preserve center origin and pan through resize.

Files: `project.godot`, `main_scenes/main.gd`, layout policy/tests if a new edge
case is discovered.

## Increment 3 - Responsive primary panels

- Fix the left startup clamp and centralize sidebar bounds.
- Reserve a minimum central canvas width when both sidebars are present.
- Reflow or scroll vertical content at the 960 x 540 test size.
- Keep manual resize handles within the same responsive constraints.

Files: the two sidebar scripts and, only if required, their scene files.

## Increment 4 - Dialog and secondary UI containment

- Inventory custom dialogs and overlays against the supported size matrix.
- Clamp popup position/size to the viewport and add scrolling to overflowing
  content where necessary.
- Check control panel, tutorial, update notices, and file-dialog launch paths.

Files are selected from verified failures and limited to one dialog family per
commit.

## Increment 5 - Visual QA and portable build

- Run headless tests and full project import.
- Exercise the resize matrix in the Windows build and capture evidence.
- Perform a multi-axis code review before publication.
- Export into a new `PixelLabStudio-Responsive-Test` folder and zip, leaving the
  previous native-hotkeys build untouched.
- Push the branch and update/open the appropriate GitHub pull request after the
  local build passes.

