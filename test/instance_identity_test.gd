extends SceneTree

const InstanceIdentity = preload("../autoload/instance_identity.gd")

var _failures: Array[String] = []
var _test_root := ""
var _stale_root := ""


func _initialize() -> void:
	var suffix := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_root = "user://instance_identity_test_" + suffix
	_stale_root = _test_root + "_stale"

	_test_formats_numbered_and_fallback_titles()
	_test_concurrent_managers_claim_distinct_slots()
	_test_released_slot_is_reused_without_renumbering_live_instances()
	_test_stale_process_lock_is_reclaimed()
	_test_live_owner_handle_blocks_stale_probe()

	_cleanup_root(_test_root)
	_cleanup_root(_stale_root)

	if _failures.is_empty():
		print("instance_identity_test: all tests passed")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_formats_numbered_and_fallback_titles() -> void:
	_assert_equal(
		InstanceIdentity.title_for_slot("PixelLab Studio", 2),
		"PixelLab Studio — Instance 2",
		"formats a numbered native title"
	)
	_assert_equal(
		InstanceIdentity.title_for_pid("PixelLab Studio", 4321),
		"PixelLab Studio — Process 4321",
		"formats a unique fallback title"
	)


func _test_concurrent_managers_claim_distinct_slots() -> void:
	var first := InstanceIdentity.new(_test_root)
	var second := InstanceIdentity.new(_test_root)

	_assert_equal(first.claim(), 1, "first live process claims slot 1")
	_assert_equal(second.claim(), 2, "second live manager skips the owned slot")

	first.release()
	second.release()


func _test_released_slot_is_reused_without_renumbering_live_instances() -> void:
	var first := InstanceIdentity.new(_test_root)
	var second := InstanceIdentity.new(_test_root)
	var replacement := InstanceIdentity.new(_test_root)

	_assert_equal(first.claim(), 1, "first manager initially owns slot 1")
	_assert_equal(second.claim(), 2, "second manager initially owns slot 2")
	first.release()
	_assert_equal(replacement.claim(), 1, "a closed process makes its slot reusable")
	_assert_equal(second.instance_number, 2, "a live process keeps its original number")

	replacement.release()
	second.release()


func _test_stale_process_lock_is_reclaimed() -> void:
	var absolute_root := ProjectSettings.globalize_path(_stale_root)
	var stale_slot := absolute_root.path_join("slot_1")
	DirAccess.make_dir_recursive_absolute(stale_slot)
	var owner_file := FileAccess.open(stale_slot.path_join("owner.pid"), FileAccess.WRITE)
	if owner_file != null:
		owner_file.store_string("-1")
		owner_file.close()

	var identity := InstanceIdentity.new(_stale_root)
	_assert_equal(identity.claim(), 1, "reclaims a slot whose owner is no longer running")
	identity.release()


func _test_live_owner_handle_blocks_stale_probe() -> void:
	var first := InstanceIdentity.new(_test_root)
	var second := InstanceIdentity.new(_test_root)

	_assert_equal(first.claim(), 1, "first manager holds its owner file open")
	_assert_equal(second.claim(), 2, "an open owner file cannot be reclaimed")

	first.release()
	second.release()


func _cleanup_root(virtual_root: String) -> void:
	var absolute_root := ProjectSettings.globalize_path(virtual_root)
	var directory := DirAccess.open(absolute_root)
	if directory == null:
		return

	directory.list_dir_begin()
	var child_name := directory.get_next()
	while not child_name.is_empty():
		if directory.current_is_dir() and child_name != "." and child_name != "..":
			var child_path := absolute_root.path_join(child_name)
			DirAccess.remove_absolute(child_path.path_join("owner.pid"))
			DirAccess.remove_absolute(child_path.path_join("owner.probe"))
			DirAccess.remove_absolute(child_path)
		child_name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute_root)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
