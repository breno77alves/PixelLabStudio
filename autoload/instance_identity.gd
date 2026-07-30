class_name InstanceIdentity
extends RefCounted

const MAX_INSTANCES := 99
const OWNER_FILE := "owner.pid"
const DEFAULT_LOCK_ROOT := "user://instance_locks"

var instance_number := 0
var process_id := 0

var _lock_root_virtual: String
var _lock_root_absolute: String
var _lock_path := ""


func _init(lock_root: String = DEFAULT_LOCK_ROOT) -> void:
	_lock_root_virtual = lock_root
	_lock_root_absolute = ProjectSettings.globalize_path(lock_root)


func claim(max_instances: int = MAX_INSTANCES) -> int:
	if instance_number > 0:
		return instance_number

	process_id = OS.get_process_id()
	if process_id <= 0:
		return 0
	if DirAccess.make_dir_recursive_absolute(_lock_root_absolute) != OK:
		return 0

	_cleanup_stale_candidates()
	var candidate_path := _create_candidate()
	if candidate_path.is_empty():
		return 0

	for slot in range(1, maxi(max_instances, 1) + 1):
		var slot_path := _slot_path(slot)
		if DirAccess.dir_exists_absolute(slot_path):
			if not _lock_is_stale(slot_path):
				continue
			_remove_lock_directory(slot_path)

		if DirAccess.rename_absolute(candidate_path, slot_path) == OK:
			instance_number = slot
			_lock_path = slot_path
			return instance_number

	_remove_lock_directory(candidate_path)
	return 0


func release() -> void:
	if instance_number <= 0 or _lock_path.is_empty():
		return
	if _read_owner(_lock_path) == process_id:
		_remove_lock_directory(_lock_path)
	instance_number = 0
	_lock_path = ""


func title(base_title: String) -> String:
	if instance_number > 0:
		return title_for_slot(base_title, instance_number)
	return title_for_pid(base_title, process_id)


static func title_for_slot(base_title: String, slot: int) -> String:
	return "%s — Instance %d" % [base_title, maxi(slot, 1)]


static func title_for_pid(base_title: String, pid: int) -> String:
	return "%s — Process %d" % [base_title, maxi(pid, 0)]


func _create_candidate() -> String:
	var candidate_name := "candidate_%d_%d" % [process_id, Time.get_ticks_usec()]
	var candidate_path := _lock_root_absolute.path_join(candidate_name)
	if DirAccess.make_dir_absolute(candidate_path) != OK:
		return ""

	var owner_file := FileAccess.open(candidate_path.path_join(OWNER_FILE), FileAccess.WRITE)
	if owner_file == null:
		_remove_lock_directory(candidate_path)
		return ""
	owner_file.store_string(str(process_id))
	owner_file.close()
	return candidate_path


func _cleanup_stale_candidates() -> void:
	var directory := DirAccess.open(_lock_root_absolute)
	if directory == null:
		return

	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if (
			directory.current_is_dir()
			and entry_name.begins_with("candidate_")
		):
			var candidate_path := _lock_root_absolute.path_join(entry_name)
			if _lock_is_stale(candidate_path):
				_remove_lock_directory(candidate_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _lock_is_stale(lock_path: String) -> bool:
	var owner_pid := _read_owner(lock_path)
	return owner_pid <= 0 or not OS.is_process_running(owner_pid)


func _read_owner(lock_path: String) -> int:
	var owner_path := lock_path.path_join(OWNER_FILE)
	var owner_file := FileAccess.open(owner_path, FileAccess.READ)
	if owner_file == null:
		return -1
	var owner_text := owner_file.get_as_text().strip_edges()
	owner_file.close()
	if not owner_text.is_valid_int():
		return -1
	return owner_text.to_int()


func _slot_path(slot: int) -> String:
	return _lock_root_absolute.path_join("slot_%d" % slot)


func _remove_lock_directory(lock_path: String) -> void:
	DirAccess.remove_absolute(lock_path.path_join(OWNER_FILE))
	DirAccess.remove_absolute(lock_path)
