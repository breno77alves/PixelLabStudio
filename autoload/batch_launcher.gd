class_name BatchLauncher
extends RefCounted

const CONFIG_VERSION := 2
const CONFIG_PATH := "user://batch_launcher.json"
const DEFAULT_FOLDER := "H:/AI/Projetos/Youtube/Sprites/ALL"
const DEFAULT_LAUNCH_DELAY_MS := 2000
const MIN_LAUNCH_DELAY_MS := 250
const MAX_LAUNCH_DELAY_MS := 10000
const DEFAULT_STARTUP_TIMEOUT_MS := 120000
const MIN_STARTUP_TIMEOUT_MS := 10000
const MAX_STARTUP_TIMEOUT_MS := 600000
const MAX_RULES := 64
const MAX_LABEL_LENGTH := 80


static func default_config() -> Dictionary:
	return {
		"version": CONFIG_VERSION,
		"folder": DEFAULT_FOLDER,
		"selected": [],
		"known_files": [],
		"launch_delay_ms": DEFAULT_LAUNCH_DELAY_MS,
		"startup_timeout_ms": DEFAULT_STARTUP_TIMEOUT_MS,
		"rules": [
			{"prefix": "Busto", "template": "Gravacao"},
			{"prefix": "Corpo", "template": "CorpoGravacao"},
		],
	}


static func parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var parsed := {
		"batch_launcher": false,
		"avatar_path": "",
		"template_name": "",
		"window_label": "",
		"ready_file_path": "",
		"read_only_session": false,
	}
	for raw_argument in arguments:
		var argument := str(raw_argument)
		if argument == "--batch-launcher":
			parsed["batch_launcher"] = true
		elif argument == "--read-only-session":
			parsed["read_only_session"] = true
		elif argument.begins_with("--avatar="):
			parsed["avatar_path"] = _argument_value(argument, "--avatar=")
		elif argument.begins_with("--template="):
			parsed["template_name"] = _argument_value(argument, "--template=")
		elif argument.begins_with("--window-label="):
			parsed["window_label"] = _argument_value(argument, "--window-label=")
		elif argument.begins_with("--batch-ready-file="):
			parsed["ready_file_path"] = _argument_value(
				argument, "--batch-ready-file="
			)
	return parsed


static func normalize_config(raw_config: Variant) -> Dictionary:
	var normalized := default_config()
	if not raw_config is Dictionary:
		return normalized

	var folder := str(raw_config.get("folder", "")).strip_edges()
	if not folder.is_empty():
		normalized["folder"] = folder.replace("\\", "/")

	normalized["launch_delay_ms"] = clampi(
		_as_int(
			raw_config.get("launch_delay_ms", DEFAULT_LAUNCH_DELAY_MS),
			DEFAULT_LAUNCH_DELAY_MS
		),
		MIN_LAUNCH_DELAY_MS,
		MAX_LAUNCH_DELAY_MS
	)
	normalized["startup_timeout_ms"] = clampi(
		_as_int(
			raw_config.get("startup_timeout_ms", DEFAULT_STARTUP_TIMEOUT_MS),
			DEFAULT_STARTUP_TIMEOUT_MS
		),
		MIN_STARTUP_TIMEOUT_MS,
		MAX_STARTUP_TIMEOUT_MS
	)
	normalized["selected"] = _normalize_string_list(raw_config.get("selected", []))
	normalized["known_files"] = _normalize_string_list(
		raw_config.get("known_files", [])
	)

	var normalized_rules: Array = []
	var raw_rules: Variant = raw_config.get("rules", [])
	if raw_rules is Array:
		for raw_rule in raw_rules:
			if normalized_rules.size() >= MAX_RULES:
				break
			if not raw_rule is Dictionary:
				continue
			var prefix := str(raw_rule.get("prefix", "")).strip_edges()
			var template_name := str(raw_rule.get("template", "")).strip_edges()
			if prefix.is_empty() or template_name.is_empty():
				continue
			normalized_rules.append({
				"prefix": prefix,
				"template": template_name,
			})
	normalized["rules"] = normalized_rules
	return normalized


static func load_config(path: String = CONFIG_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return default_config()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return normalize_config(parsed)


static func save_config(config: Variant, path: String = CONFIG_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_line(JSON.stringify(normalize_config(config), "\t"))
	file.close()
	return OK


static func matching_template(file_name: String, rules: Variant) -> String:
	if not rules is Array:
		return ""
	var folded_name := file_name.get_basename().to_lower()
	var best_template := ""
	var best_length := -1
	for raw_rule in rules:
		if not raw_rule is Dictionary:
			continue
		var prefix := str(raw_rule.get("prefix", "")).strip_edges()
		var template_name := str(raw_rule.get("template", "")).strip_edges()
		if prefix.is_empty() or template_name.is_empty():
			continue
		var folded_prefix := prefix.to_lower()
		if folded_name.begins_with(folded_prefix) and folded_prefix.length() > best_length:
			best_template = template_name
			best_length = folded_prefix.length()
	return best_template


static func scan_folder(config: Variant, available_templates: Variant) -> Array:
	var normalized := normalize_config(config)
	var folder := str(normalized["folder"])
	var directory := DirAccess.open(folder)
	if directory == null:
		return []

	var file_names: Array[String] = []
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if (
			not directory.current_is_dir()
			and entry_name.get_extension().to_lower() == "save"
		):
			file_names.append(entry_name)
		entry_name = directory.get_next()
	directory.list_dir_end()
	file_names.sort_custom(_natural_name_less)

	var selected: Array = normalized["selected"]
	var known_files: Array = normalized["known_files"]
	var entries: Array = []
	for file_name in file_names:
		var template_name := matching_template(file_name, normalized["rules"])
		var template_exists := _contains_case_insensitive(
			available_templates, template_name
		)
		var valid := not template_name.is_empty() and template_exists
		var is_new := not _contains_case_insensitive(known_files, file_name)
		var is_selected := valid and (
			_contains_case_insensitive(selected, file_name) or is_new
		)
		var status := "Ready"
		if template_name.is_empty():
			status = "No matching rule"
		elif not template_exists:
			status = 'Template "%s" not found' % template_name
		entries.append({
			"file_name": file_name,
			"path": folder.path_join(file_name),
			"label": label_for_path(file_name),
			"template_name": template_name,
			"selected": is_selected,
			"valid": valid,
			"status": status,
		})
	return entries


static func label_for_path(path: String) -> String:
	var label := path.get_file().get_basename()
	label = label.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	label = label.strip_edges().substr(0, MAX_LABEL_LENGTH)
	return label if not label.is_empty() else "Avatar"


static func child_arguments(
	entry: Dictionary, ready_file_path: String, log_file_path: String
) -> PackedStringArray:
	return PackedStringArray([
		"--log-file",
		log_file_path,
		"--",
		"--avatar=" + str(entry.get("path", "")),
		"--template=" + str(entry.get("template_name", "")),
		"--window-label=" + str(entry.get("label", "")),
		"--batch-ready-file=" + ready_file_path,
		"--read-only-session",
	])


static func write_ready_marker(path: String, payload: Dictionary) -> Error:
	if not _is_ready_marker_path_allowed(path):
		return ERR_INVALID_PARAMETER

	var parent_directory := path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(parent_directory)
	if directory_error != OK:
		return directory_error

	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_line(JSON.stringify(payload))
	file.close()

	DirAccess.remove_absolute(path)
	var publish_error := DirAccess.rename_absolute(temporary_path, path)
	if publish_error != OK:
		DirAccess.remove_absolute(temporary_path)
	return publish_error


static func _is_ready_marker_path_allowed(path: String) -> bool:
	if not path.is_absolute_path() or path.get_extension().to_lower() != "ready":
		return false
	var normalized_path := path.replace("\\", "/").simplify_path().to_lower()
	var batch_root := ProjectSettings.globalize_path(
		"user://batch_runs"
	).replace("\\", "/").simplify_path().to_lower()
	return normalized_path.begins_with(batch_root + "/")


static func selected_names(entries: Array) -> Array:
	var selected: Array = []
	for entry in entries:
		if entry is Dictionary and entry.get("valid", false) and entry.get("selected", false):
			selected.append(str(entry.get("file_name", "")))
	return selected


static func known_names(entries: Array) -> Array:
	var known: Array = []
	for entry in entries:
		if entry is Dictionary:
			var file_name := str(entry.get("file_name", ""))
			if not file_name.is_empty():
				known.append(file_name)
	return known


static func _argument_value(argument: String, prefix: String) -> String:
	var value := argument.substr(prefix.length()).strip_edges()
	if value.length() >= 2 and value.begins_with('"') and value.ends_with('"'):
		value = value.substr(1, value.length() - 2)
	return value


static func _normalize_string_list(raw_list: Variant) -> Array:
	var normalized: Array = []
	if not raw_list is Array:
		return normalized
	for raw_value in raw_list:
		if not raw_value is String:
			continue
		var value := str(raw_value).strip_edges()
		if value.is_empty() or _contains_case_insensitive(normalized, value):
			continue
		normalized.append(value)
	return normalized


static func _contains_case_insensitive(values: Variant, needle: String) -> bool:
	if needle.is_empty() or not values is Array:
		return false
	var folded_needle := needle.to_lower()
	for value in values:
		if str(value).to_lower() == folded_needle:
			return true
	return false


static func _natural_name_less(left: String, right: String) -> bool:
	return left.naturalnocasecmp_to(right) < 0


static func _as_int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	return fallback
