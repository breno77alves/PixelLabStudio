extends SceneTree

var _failures: Array[String] = []
var _settings_path := ""
var _saving: Node = null
var _original_settings: Dictionary = {}


func _initialize() -> void:
	_settings_path = "user://read_only_session_test_%d_%d.json" % [
		OS.get_process_id(), Time.get_ticks_usec()
	]
	_saving = root.get_node_or_null("Saving")
	if _saving == null or not _saving.has_method("set_settings_write_enabled"):
		_failures.append("Saving must expose set_settings_write_enabled")
	else:
		_original_settings = _saving.settings.duplicate(true)
		_test_read_only_session_preserves_existing_settings()
		_test_manual_session_can_still_write_settings()
		_saving.settings = _original_settings
		_saving.set_settings_write_enabled(true)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_settings_path))
	if _failures.is_empty():
		print("read_only_session_test: all tests passed")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_read_only_session_preserves_existing_settings() -> void:
	_write_text(_settings_path, "original")
	_saving.settings = {"lastAvatar": "should-not-be-written"}
	_saving.set_settings_write_enabled(false)
	_saving.write_settings(_settings_path)
	_assert_equal(_read_text(_settings_path), "original", "read-only mode blocks settings writes")


func _test_manual_session_can_still_write_settings() -> void:
	_saving.set_settings_write_enabled(true)
	_saving.settings = {"lastAvatar": "manual.save"}
	_saving.write_settings(_settings_path)
	var parsed: Variant = JSON.parse_string(_read_text(_settings_path))
	_assert_equal(parsed["lastAvatar"], "manual.save", "manual mode keeps existing persistence")


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("could not create test settings file")
		return
	file.store_string(contents)
	file.close()


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var contents := file.get_as_text()
	file.close()
	return contents


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
