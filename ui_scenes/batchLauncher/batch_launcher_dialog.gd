extends Control

const BatchLauncherUtil = preload("res://autoload/batch_launcher.gd")
const SceneTemplateUtil = preload("res://autoload/scene_template.gd")

@onready var folder_edit: LineEdit = %FolderEdit
@onready var delay_spin: SpinBox = %DelaySpin
@onready var rules_list: VBoxContainer = %RulesList
@onready var files_list: VBoxContainer = %FilesList
@onready var empty_label: Label = %EmptyLabel
@onready var status_label: Label = %StatusLabel
@onready var launch_button: Button = %LaunchButton
@onready var folder_dialog: FileDialog = %FolderDialog

var _config: Dictionary = {}
var _entries: Array = []
var _rule_rows: Array[Dictionary] = []
var _available_templates: Array[String] = []
var _launching := false


func _ready() -> void:
	%CloseButton.pressed.connect(_on_close_pressed)
	%BrowseButton.pressed.connect(_on_browse_pressed)
	%RescanButton.pressed.connect(_refresh_files)
	%AddRuleButton.pressed.connect(_on_add_rule_pressed)
	%SelectAllButton.pressed.connect(_on_select_all_pressed)
	%ClearButton.pressed.connect(_on_clear_pressed)
	launch_button.pressed.connect(_on_launch_pressed)
	folder_dialog.dir_selected.connect(_on_folder_selected)

	var saving := get_node_or_null("/root/Saving")
	var saved_templates: Variant = []
	if saving != null:
		saved_templates = saving.settings.get("sceneTemplates", [])
	var templates := SceneTemplateUtil.normalize_list(
		saved_templates, get_window().min_size
	)
	for template in templates:
		_available_templates.append(str(template["name"]))

	_config = BatchLauncherUtil.load_config()
	folder_edit.text = str(_config["folder"])
	delay_spin.value = float(_config["launch_delay_ms"]) / 1000.0
	for rule in _config["rules"]:
		_add_rule_row(str(rule["prefix"]), str(rule["template"]))
	_refresh_files()
	folder_edit.grab_focus()


func _add_rule_row(prefix: String = "", template_name: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var prefix_edit := LineEdit.new()
	prefix_edit.placeholder_text = "Filename prefix"
	prefix_edit.text = prefix
	prefix_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prefix_edit.tooltip_text = "Case-insensitive; the longest matching prefix wins"
	row.add_child(prefix_edit)

	var template_option := OptionButton.new()
	template_option.custom_minimum_size.x = 190
	for available_name in _available_templates:
		template_option.add_item(available_name)
	var selected_index := _available_templates.find(template_name)
	if selected_index < 0 and not template_name.is_empty():
		template_option.add_item(template_name + " (missing)")
		selected_index = template_option.item_count - 1
	template_option.selected = maxi(selected_index, 0)
	template_option.disabled = _available_templates.is_empty()
	row.add_child(template_option)

	var remove_button := Button.new()
	remove_button.text = "Remove"
	remove_button.tooltip_text = "Remove this matching rule"
	row.add_child(remove_button)

	var references := {
		"row": row,
		"prefix": prefix_edit,
		"template": template_option,
	}
	_rule_rows.append(references)
	rules_list.add_child(row)
	prefix_edit.text_changed.connect(func(_text): _on_rules_changed())
	template_option.item_selected.connect(func(_index): _on_rules_changed())
	remove_button.pressed.connect(_remove_rule_row.bind(references))


func _remove_rule_row(references: Dictionary) -> void:
	_rule_rows.erase(references)
	references["row"].queue_free()
	call_deferred("_refresh_files")


func _collect_rules() -> Array:
	var rules: Array = []
	for references in _rule_rows:
		var prefix := str(references["prefix"].text).strip_edges()
		var option: OptionButton = references["template"]
		if prefix.is_empty() or option.item_count <= 0:
			continue
		var template_name := option.get_item_text(option.selected)
		if template_name.ends_with(" (missing)"):
			template_name = template_name.trim_suffix(" (missing)")
		rules.append({"prefix": prefix, "template": template_name})
	return rules


func _refresh_files() -> void:
	if _launching:
		return
	_store_current_selection()
	_config["folder"] = folder_edit.text.strip_edges()
	_config["launch_delay_ms"] = int(delay_spin.value * 1000.0)
	_config["rules"] = _collect_rules()
	_entries = BatchLauncherUtil.scan_folder(_config, _available_templates)
	_rebuild_file_rows()


func _rebuild_file_rows() -> void:
	for child in files_list.get_children():
		child.queue_free()

	var valid_count := 0
	var selected_count := 0
	for entry in _entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var checkbox := CheckBox.new()
		checkbox.button_pressed = bool(entry["selected"])
		checkbox.disabled = not bool(entry["valid"])
		checkbox.tooltip_text = str(entry["status"])
		checkbox.toggled.connect(_on_file_toggled.bind(entry))
		row.add_child(checkbox)

		var name_label := Label.new()
		name_label.text = str(entry["file_name"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name_label)

		var template_label := Label.new()
		template_label.text = str(entry["template_name"])
		template_label.custom_minimum_size.x = 180
		row.add_child(template_label)

		var state_label := Label.new()
		state_label.text = str(entry["status"])
		state_label.custom_minimum_size.x = 170
		state_label.add_theme_color_override(
			"font_color",
			Color(0.65, 0.9, 0.72) if entry["valid"] else Color(1.0, 0.62, 0.55)
		)
		row.add_child(state_label)
		files_list.add_child(row)

		if entry["valid"]:
			valid_count += 1
		if entry["valid"] and entry["selected"]:
			selected_count += 1

	empty_label.visible = _entries.is_empty()
	if _entries.is_empty():
		empty_label.text = "No .save files found in this folder."
	status_label.text = "%d selected · %d valid · %d total" % [
		selected_count, valid_count, _entries.size()
	]
	launch_button.disabled = selected_count == 0


func _on_file_toggled(pressed: bool, entry: Dictionary) -> void:
	entry["selected"] = pressed
	_rebuild_summary()


func _rebuild_summary() -> void:
	var selected_count := 0
	var valid_count := 0
	for entry in _entries:
		if entry["valid"]:
			valid_count += 1
		if entry["valid"] and entry["selected"]:
			selected_count += 1
	status_label.text = "%d selected · %d valid · %d total" % [
		selected_count, valid_count, _entries.size()
	]
	launch_button.disabled = selected_count == 0


func _store_current_selection() -> void:
	if _entries.is_empty():
		return
	_config["selected"] = BatchLauncherUtil.selected_names(_entries)
	_config["known_files"] = BatchLauncherUtil.known_names(_entries)


func _persist_config() -> Error:
	_store_current_selection()
	_config["folder"] = folder_edit.text.strip_edges()
	_config["launch_delay_ms"] = int(delay_spin.value * 1000.0)
	_config["rules"] = _collect_rules()
	return BatchLauncherUtil.save_config(_config)


func _on_rules_changed() -> void:
	call_deferred("_refresh_files")


func _on_add_rule_pressed() -> void:
	_add_rule_row("", _available_templates[0] if not _available_templates.is_empty() else "")
	_rule_rows.back()["prefix"].grab_focus()


func _on_select_all_pressed() -> void:
	for entry in _entries:
		entry["selected"] = bool(entry["valid"])
	_rebuild_file_rows()


func _on_clear_pressed() -> void:
	for entry in _entries:
		entry["selected"] = false
	_rebuild_file_rows()


func _on_browse_pressed() -> void:
	folder_dialog.current_dir = folder_edit.text
	folder_dialog.popup_file_dialog()


func _on_folder_selected(path: String) -> void:
	folder_edit.text = path
	_entries = []
	_config["selected"] = []
	_config["known_files"] = []
	_refresh_files()


func _on_close_pressed() -> void:
	if _launching:
		return
	_persist_config()
	get_tree().quit()


func _on_launch_pressed() -> void:
	if _launching:
		return
	if _persist_config() != OK:
		status_label.text = "Could not save launcher configuration."
		return

	var requests: Array = []
	for entry in _entries:
		if entry["valid"] and entry["selected"]:
			requests.append(entry)
	if requests.is_empty():
		return

	_launching = true
	launch_button.disabled = true
	var failures: Array[String] = []
	for index in range(requests.size()):
		var entry: Dictionary = requests[index]
		status_label.text = "Starting %d of %d: %s" % [
			index + 1, requests.size(), entry["file_name"]
		]
		var arguments := PackedStringArray([
			"--",
			"--avatar=" + str(entry["path"]),
			"--template=" + str(entry["template_name"]),
			"--window-label=" + str(entry["label"]),
			"--read-only-session",
		])
		if OS.create_instance(arguments) < 0:
			failures.append(str(entry["file_name"]))
		if index < requests.size() - 1:
			await get_tree().create_timer(float(_config["launch_delay_ms"]) / 1000.0).timeout

	if failures.is_empty():
		get_tree().quit()
		return
	_launching = false
	launch_button.disabled = false
	status_label.text = "Could not start: " + ", ".join(failures)
