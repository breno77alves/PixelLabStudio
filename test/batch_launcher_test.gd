extends SceneTree

const BatchLauncher = preload("../autoload/batch_launcher.gd")

var _failures: Array[String] = []
var _test_root := ""
var _ready_test_root := ""


func _initialize() -> void:
	_test_root = "user://batch_launcher_test_%d_%d" % [
		OS.get_process_id(), Time.get_ticks_usec()
	]
	_ready_test_root = "user://batch_runs/batch_launcher_test_%d_%d" % [
		OS.get_process_id(), Time.get_ticks_usec()
	]

	_test_parses_batch_user_arguments()
	_test_longest_case_insensitive_prefix_wins()
	_test_normalizes_invalid_configuration()
	_test_scans_only_save_files_and_resolves_templates()
	_test_stable_label_comes_from_filename()
	_test_builds_a_child_request_with_a_ready_signal()
	_test_writes_a_ready_marker_atomically()
	_test_rejects_a_ready_marker_outside_batch_runs()

	_cleanup_test_root()
	if _failures.is_empty():
		print("batch_launcher_test: all tests passed")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_parses_batch_user_arguments() -> void:
	var parsed := BatchLauncher.parse_arguments(PackedStringArray([
		"--avatar=H:/Avatar Files/Corpo_base.save",
		"--template=CorpoGravacao",
		"--window-label=Corpo_base",
		"--batch-ready-file=H:/Ready Signals/002.ready",
		"--read-only-session",
	]))

	_assert_equal(
		parsed["avatar_path"],
		"H:/Avatar Files/Corpo_base.save",
		"preserves spaces in an avatar argument"
	)
	_assert_equal(parsed["template_name"], "CorpoGravacao", "parses template name")
	_assert_equal(parsed["window_label"], "Corpo_base", "parses stable window label")
	_assert_equal(
		parsed["ready_file_path"],
		"H:/Ready Signals/002.ready",
		"parses the child readiness path"
	)
	_assert_equal(parsed["read_only_session"], true, "parses read-only mode")


func _test_longest_case_insensitive_prefix_wins() -> void:
	var rules := [
		{"prefix": "Corpo", "template": "CorpoGravacao"},
		{"prefix": "corpo_de_costas", "template": "CostasGravacao"},
	]

	_assert_equal(
		BatchLauncher.matching_template("CORPO_DE_COSTAS_01.save", rules),
		"CostasGravacao",
		"uses the most specific matching prefix"
	)


func _test_normalizes_invalid_configuration() -> void:
	var normalized := BatchLauncher.normalize_config({
		"folder": "",
		"launch_delay_ms": 999999,
		"rules": [
			{"prefix": "", "template": "Ignored"},
			{"prefix": "Busto", "template": "Gravacao"},
		],
		"selected": ["Busto_base.save", 12],
	})

	_assert_equal(
		normalized["folder"],
		BatchLauncher.DEFAULT_FOLDER,
		"restores the default folder"
	)
	_assert_equal(
		normalized["launch_delay_ms"],
		BatchLauncher.MAX_LAUNCH_DELAY_MS,
		"clamps an excessive launch delay"
	)
	_assert_equal(
		normalized["startup_timeout_ms"],
		BatchLauncher.DEFAULT_STARTUP_TIMEOUT_MS,
		"adds a conservative startup timeout to older configurations"
	)
	_assert_equal(normalized["rules"].size(), 1, "drops incomplete rules")
	_assert_equal(
		normalized["selected"],
		["Busto_base.save"],
		"drops non-string selections"
	)


func _test_scans_only_save_files_and_resolves_templates() -> void:
	var absolute_root := ProjectSettings.globalize_path(_test_root)
	DirAccess.make_dir_recursive_absolute(absolute_root.path_join("nested"))
	_write_text(absolute_root.path_join("Busto_base.save"), "{}")
	_write_text(absolute_root.path_join("Corpo_base.SAVE"), "{}")
	_write_text(absolute_root.path_join("notes.txt"), "ignored")
	_write_text(absolute_root.path_join("nested").path_join("Corpo_nested.save"), "{}")

	var config := BatchLauncher.normalize_config({
		"folder": absolute_root,
		"selected": ["Busto_base.save"],
		"known_files": ["Busto_base.save"],
		"rules": [
			{"prefix": "Busto", "template": "Gravacao"},
			{"prefix": "Corpo", "template": "CorpoGravacao"},
		],
	})
	var entries := BatchLauncher.scan_folder(
		config, ["Gravacao", "CorpoGravacao"]
	)

	_assert_equal(entries.size(), 2, "scans only top-level save files")
	_assert_equal(entries[0]["file_name"], "Busto_base.save", "sorts names")
	_assert_equal(entries[0]["selected"], true, "remembers an existing selection")
	_assert_equal(
		entries[1]["selected"],
		true,
		"selects a newly discovered valid file"
	)
	_assert_equal(entries[1]["template_name"], "CorpoGravacao", "resolves template")
	_assert_equal(entries[1]["valid"], true, "marks a resolved entry valid")


func _test_stable_label_comes_from_filename() -> void:
	_assert_equal(
		BatchLauncher.label_for_path("H:/Avatars/Corpo_base.save"),
		"Corpo_base",
		"uses the filename stem as a stable label"
	)


func _test_builds_a_child_request_with_a_ready_signal() -> void:
	var arguments := BatchLauncher.child_arguments({
		"path": "H:/Avatar Files/Corpo_base.save",
		"template_name": "CorpoGravacao",
		"label": "Corpo_base",
	}, "H:/Ready Signals/002.ready", "H:/Ready Signals/002.log")

	_assert_equal(arguments[0], "--log-file", "gives each child an isolated engine log")
	_assert_equal(
		arguments[1],
		"H:/Ready Signals/002.log",
		"uses the requested isolated log path"
	)
	_assert_equal(arguments[2], "--", "separates engine and user arguments")
	_assert_equal(
		arguments.has("--batch-ready-file=H:/Ready Signals/002.ready"),
		true,
		"passes a unique readiness path to the child"
	)
	_assert_equal(
		arguments.has("--read-only-session"),
		true,
		"keeps batch children read-only"
	)


func _test_writes_a_ready_marker_atomically() -> void:
	var ready_path := ProjectSettings.globalize_path(
		_ready_test_root.path_join("003.ready")
	)
	var write_error := BatchLauncher.write_ready_marker(
		ready_path,
		{"avatar": "Corpo_base.save"}
	)
	_assert_equal(write_error, OK, "writes a readiness marker")
	_assert_equal(FileAccess.file_exists(ready_path), true, "publishes the final marker")
	_assert_equal(
		FileAccess.file_exists(ready_path + ".tmp"),
		false,
		"does not leave a partial marker"
	)


func _test_rejects_a_ready_marker_outside_batch_runs() -> void:
	var unsafe_path := ProjectSettings.globalize_path(
		_test_root.path_join("not-allowed.ready")
	)
	DirAccess.remove_absolute(unsafe_path)
	var write_error := BatchLauncher.write_ready_marker(unsafe_path, {})

	_assert_equal(
		write_error,
		ERR_INVALID_PARAMETER,
		"rejects a readiness marker outside the private batch directory"
	)
	_assert_equal(
		FileAccess.file_exists(unsafe_path),
		false,
		"does not write an unsafe readiness marker"
	)


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("could not create test file: " + path)
		return
	file.store_string(contents)
	file.close()


func _cleanup_test_root() -> void:
	var absolute_root := ProjectSettings.globalize_path(_test_root)
	var absolute_ready_root := ProjectSettings.globalize_path(_ready_test_root)
	DirAccess.remove_absolute(absolute_ready_root.path_join("003.ready"))
	DirAccess.remove_absolute(absolute_ready_root)
	DirAccess.remove_absolute(absolute_root.path_join("not-allowed.ready"))
	DirAccess.remove_absolute(absolute_root.path_join("nested").path_join("Corpo_nested.save"))
	DirAccess.remove_absolute(absolute_root.path_join("nested"))
	for name in ["Busto_base.save", "Corpo_base.SAVE", "notes.txt"]:
		DirAccess.remove_absolute(absolute_root.path_join(name))
	DirAccess.remove_absolute(absolute_root)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
