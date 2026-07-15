# Implementation Plan: OBS Scene Templates

## Architecture Decisions

- Store templates as an ordered array of small dictionaries in
  `Saving.settings["sceneTemplates"]`; this preserves UI order and remains JSON
  compatible.
- Keep validation and list mutation in a pure helper so corrupted settings and
  edge cases are testable without a running scene tree.
- Let `main.gd` remain the only owner of native window and camera state.
- Build the controls inside the existing settings panel to inherit its
  scrolling and responsive behavior.

## Task List

### Phase 1: Data contract

- [ ] Add failing tests for normalization, overwrite, limits, and deletion.
- [ ] Implement the pure helper and a backward-compatible settings default.

### Checkpoint: Data contract

- [ ] New unit suite passes.
- [ ] Existing settings files with no template key still load.

### Phase 2: Runtime and UI

- [ ] Add one runtime method that applies validated size and zoom.
- [ ] Add template selection, exact numeric fields, save/apply/delete actions,
      and clear empty/error states to Settings.

### Checkpoint: User flow

- [ ] Saving, overwriting, applying, and deleting work end to end.
- [ ] Settings panel remains scrollable at its minimum supported window size.

### Phase 3: Release

- [ ] Run template, responsive layout, and hotkey tests.
- [ ] Review correctness, readability, architecture, security, and performance.
- [ ] Export the portable Windows build and update the test ZIP.
- [ ] Commit and push the feature branch.

## Risks and Mitigations

- The OS can adjust impossible window dimensions: numeric fields use the
  runtime minimum and conservative maximum bounds, and the UI refreshes from
  the applied state.
- A resize and zoom change can race in one frame: set zoom first, resize through
  the existing handler, and perform one deferred layout refresh.
- Old JSON may contain malformed entries: normalize every entry before it is
  listed or applied.
