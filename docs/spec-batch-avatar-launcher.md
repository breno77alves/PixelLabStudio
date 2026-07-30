# Spec: Batch Avatar Launcher

## Objective

Open multiple `.save` avatars from one native PixelLab Studio launcher, apply
the matching saved OBS scene template, and give automated windows stable
avatar-based titles without changing global settings.

The default folder is `H:/AI/Projetos/Youtube/Sprites/ALL`. `Busto*` maps to
`Gravacao`; `Corpo*` maps to `CorpoGravacao`. Users can edit and extend these
prefix rules in the launcher.

## Runtime Contract

The exported application accepts user arguments after Godot's `--` separator:

```text
PixelLabStudio.exe -- --batch-launcher
PixelLabStudio.exe --log-file <unique log> -- --avatar=<absolute path> \
  --template=<name> --window-label=<label> \
  --batch-ready-file=<unique marker> --read-only-session
```

Batch child sessions read the normal settings and templates but never write
`settings.pngtp`, `session.pngtp`, `lastAvatar`, or persistent window size.
Manual sessions preserve their existing behavior. Each batch child writes to
its own engine log and atomically publishes a readiness marker only after its
template and avatar finish loading.

## Launcher Configuration

`user://batch_launcher.json` stores a versioned folder, selected filenames,
post-ready delay, startup timeout, and prefix-to-template rules. Matching is
case-insensitive and the longest matching prefix wins. Invalid, unmatched, or
missing files are skipped with an explicit status.

The launcher scans only the selected folder, sorts `.save` files
case-insensitively, defaults new valid files to selected, and deduplicates
absolute paths.

## User Interface

Use responsive Godot `Control` containers, one scrollable file list, editable
rule rows, meaningful empty/error/progress states, and keyboard-focusable
native controls. A normal app button and a colocated `.bat` open the dedicated
launcher mode. Children start sequentially: the launcher waits for one avatar
to become ready before starting the next. It closes after every selected child
confirms readiness and stays open with the filename and reason when any child
exits early or times out.

## Testing Strategy

- Pure tests cover argument parsing, rule priority, config normalization,
  file selection, stable labels, isolated child arguments, and atomic ready
  markers.
- Integration tests cover read-only settings behavior and session-only
  template application.
- Existing hotkey, responsive layout, scene template, and instance identity
  suites must remain green.
- Windows verification opens all eight current saves and checks native titles,
  template sizes/zooms, and unchanged shared settings.

## Boundaries

- Always: validate paths/extensions/templates before process creation; use
  `OS.create_instance`; keep launcher configuration separate from app settings.
- Ask first: recursive folder scanning, window-position templates, named launch
  profiles, or automatically editing OBS sources.
- Never: use AutoHotkey, overwrite the stable portable builds, or let batch
  child sessions persist shared settings.

## Success Criteria

- One click opens every selected valid avatar with the correct template.
- Automated titles are stable (`PixelLab Studio — Corpo_base`).
- New specific rules such as `Corpo_de_costas` override the generic `Corpo`.
- Concurrent batch sessions leave shared settings and recovery files unchanged.
- The feature ships in a separate branch, portable folder, and ZIP.
