extends SceneTree

const LauncherScene = preload(
	"../ui_scenes/batchLauncher/batch_launcher_dialog.tscn"
)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var launcher := LauncherScene.instantiate()
	root.add_child(launcher)
	await process_frame
	await process_frame

	var files_list := launcher.find_child("FilesList", true, false)
	var rules_list := launcher.find_child("RulesList", true, false)
	var launch_button := launcher.find_child("LaunchButton", true, false)
	_assert_equal(files_list != null, true, "renders the scrollable file list")
	_assert_equal(rules_list != null, true, "renders the editable rule list")
	_assert_equal(launch_button != null, true, "renders the batch action")
	if files_list != null:
		_assert_equal(files_list.get_child_count(), 8, "lists the eight current avatar saves")
	if rules_list != null:
		_assert_equal(rules_list.get_child_count(), 2, "loads the two default prefix rules")
	if launch_button != null:
		_assert_equal(launch_button.disabled, false, "enables launch for valid selected files")

	launcher.queue_free()
	await process_frame
	if _failures.is_empty():
		print("batch_launcher_ui_test: all tests passed")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
