# Spec: OBS Scene Templates

## Objective

Add reusable, global scene templates that let a streamer reproduce the exact
PixelLab Studio window size and avatar zoom used by different OBS scenes.

A template stores a name, native window width, native window height, and the
existing user zoom percentage. Users can enter exact values, save or overwrite
a named template, apply it immediately, and delete it later.

## Tech Stack

- Godot 4.6.1 and GDScript.
- Existing JSON settings file at `user://settings.pngtp`.
- Existing responsive window and camera composition in `main.gd` and
  `responsive_layout.gd`.

## Commands

- Unit tests: `godot --headless --path test --script scene_template_test.gd`
- Existing layout tests: `godot --headless --path test --script responsive_layout_test.gd`
- Hotkey regression tests: `godot --headless --path test --script hotkey_binding_test.gd`
- Packaging smoke test: `godot --headless --path . --script tools/native_extension_smoke_test.gd`

## Project Structure

- `autoload/scene_template.gd`: pure validation and list operations.
- `autoload/saving.gd`: default `sceneTemplates` settings value.
- `main_scenes/main.gd`: applies a validated template to the native window and
  composed camera zoom.
- `ui_scenes/settings/settings_menu.gd`: template editor and actions.
- `test/scene_template_test.gd`: deterministic unit tests.

## Code Style

Use typed GDScript for public contracts, snake_case names, early returns, and
the existing dynamic settings-section style:

```gdscript
func apply_scene_template(template: Dictionary) -> bool:
	var normalized := SceneTemplate.normalize(template, get_window().min_size)
	if normalized.is_empty():
		return false
	get_window().size = SceneTemplate.window_size(normalized)
	return true
```

## Testing Strategy

- Unit-test normalization, bounds, overwrite semantics, the 20-template limit,
  and deletion without opening the UI.
- Run existing responsive-layout and hotkey suites to catch regressions.
- Export and launch the Windows build, then manually save and apply a template
  while checking that the reported window size and zoom match it.

## Boundaries

- Always: preserve old settings files, validate loaded JSON, keep zoom within
  the existing 10%-400% range, and persist successful changes immediately.
- Ask first: add costume, avatar, background, window position, or hotkeys to a
  template; change the application-wide minimum window size.
- Never: silently delete a user's templates, add a dependency, or bypass the
  responsive resize flow.

## Success Criteria

- A user can save up to 20 named templates from exact width, height, and zoom
  fields; saving an existing name overwrites it case-insensitively.
- Selecting and applying a template changes the native window size and avatar
  zoom in one action and persists the resulting window size.
- Invalid or legacy JSON entries cannot crash the settings screen.
- A selected custom template can be deleted; the empty state remains usable.
- Existing layout and hotkey tests continue to pass.

## Open Questions

- Future versions may optionally include window position, costume, avatar, or a
  global hotkey. They are intentionally excluded from this first version.
