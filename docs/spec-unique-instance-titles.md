# Spec: Unique Titles for Multiple Instances

## Objective

Give every concurrently running PixelLab Studio process a distinct native
window title so OBS Window Capture can identify each window without requiring
the user to minimize all other instances.

The first live process uses `PixelLab Studio — Instance 1`, the second uses
`PixelLab Studio — Instance 2`, and so on. A number is reserved only while its
owning process is alive. Stale reservations left by crashes are reclaimed.

## Tech Stack

- Godot 4.6.1 and GDScript.
- Native process IDs from `OS.get_process_id()` and a lifetime-owned file
  handle for cross-process liveness on Windows.
- Atomic directory renames under `user://instance_locks` for cross-process
  slot reservation.
- Native title through the main `Window.title` property.

## Commands

- Unit/integration test:
  `godot --headless --path test --script instance_identity_test.gd`
- Regression tests:
  `godot --headless --path test --script responsive_layout_test.gd`
  and `godot --headless --path test --script hotkey_binding_test.gd`
- Windows package:
  `godot --headless --path . --editor --export-pack "Windows Desktop" PixelLabStudio.pck`

## Project Structure

- `autoload/instance_identity.gd`: title formatting, lock ownership, stale-lock
  recovery, and release.
- `main_scenes/main.gd`: claims a slot on startup, sets the title, and releases
  the slot during shutdown.
- `test/instance_identity_test.gd`: deterministic title and lock lifecycle
  coverage.

## Code Style

Use typed GDScript, snake_case, explicit ownership checks, and early returns:

```gdscript
func release() -> void:
	if instance_number <= 0 or not _owns_lock():
		return
	_remove_lock_directory(_lock_path)
```

## Testing Strategy

- Start with failing tests for title formatting, two simultaneous claims,
  release/reuse, and stale-lock recovery.
- Run the existing layout, hotkey, and scene-template suites.
- Export the Windows package and start at least two real processes against the
  same user-data directory; their logs must report different titles.

## Boundaries

- Always: isolate this work on `feature/unique-instance-titles`; release only a
  lock owned by the current PID; recover crashed-process locks.
- Ask first: add manually editable labels, bind identities to avatars, or split
  settings/save directories per instance.
- Never: change the project name, OBS settings, costumes, templates, hotkeys,
  or the stable responsive branch.

## Success Criteria

- Two live processes never intentionally claim the same instance number.
- Titles are distinct and visible to native window-capture software.
- Closing Instance 1 makes slot 1 reusable without renaming already-running
  windows.
- A crash does not permanently consume an instance number.
- A failure to create lock files falls back to a unique PID-based title rather
  than leaving duplicate titles.

## Open Questions

- Custom labels such as character names may be added later. This first version
  is automatic and configuration-free.
