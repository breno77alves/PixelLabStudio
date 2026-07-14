extends Node2D

const ResponsiveLayout = preload("res://autoload/responsive_layout.gd")
const TOP_MARGIN := 16.0
const BOTTOM_CONTROLS_MARGIN := 120.0
const SCROLL_STEP := 48.0

var awaitingCostumeInput = -1

var hasMouse = false
var _was_visible := false
var _last_viewport_size := Vector2.ZERO
var _scrollbar: VScrollBar = null
var _scroll_bounds := Vector2.ZERO
var _syncing_scrollbar := false

# NDI UI references (built in code)
var _ndi_section: Node2D = null
var _ndi_toggle: CheckBox = null
var _ndi_status_label: Label = null
var _ndi_width_option: OptionButton = null
var _ndi_mode_option: OptionButton = null
var _ndi_manual_w: SpinBox = null
var _ndi_manual_h: SpinBox = null
var _ndi_manual_container: HBoxContainer = null
var _ndi_source_name_input: LineEdit = null

# Recording UI references (built in code)
var _recording_section: Node2D = null
var _recording_format_option: OptionButton = null
var _recording_fps_option: OptionButton = null


func _ready() -> void:
	_scrollbar = VScrollBar.new()
	_scrollbar.name = "SettingsViewportScrollbar"
	_scrollbar.z_index = z_index
	_scrollbar.step = 1.0
	_scrollbar.value_changed.connect(_on_viewport_scrollbar_changed)
	get_parent().add_child.call_deferred(_scrollbar)

func setvalues():
	
	$Background/ColorPickerButton.color = Global.backgroundColor
	if Global.backgroundColor == Color(0.0,0.0,0.0,0.0):
		$Background/ColorPickerButton.color = Color(1.0,1.0,1.0,1.0)
	
	
	$MaxFPS/fpslabel.text = str(Engine.max_fps)
	$MaxFPS/fpsDrag.value = Engine.max_fps
	if Engine.max_fps == 0:
		$MaxFPS/fpslabel.text = "Unlimited"
		$MaxFPS/fpsDrag.value = 241
	
	$BounceForce/bounce.text = str(Saving.settings["bounce"])
	$BounceForce/bounceForce.value = Saving.settings["bounce"]
	$BounceGravity/bounce.text = str(Saving.settings["gravity"])
	$BounceGravity/bounceGravity.value = Saving.settings["gravity"]
	
	_on_check_box_toggled(Global.filtering)
	
	$BlinkSpeed/blinkSpeed.value = int(1.0/Global.blinkSpeed)
	$BlinkSpeed/Label.text = "blink speed: " + str(int(1.0/Global.blinkSpeed))
	
	$BlinkChance/blinkChance.value = Global.blinkChance
	$BlinkChance/Label.text = "blink chance: 1 in " + str(Global.blinkChance) 
	
	$bounceOnCostume/costumeCheck.button_pressed = Global.main.bounceOnCostumeChange

	_build_ndi_section()
	_update_ndi_ui()
	_build_recording_section()
	_update_recording_ui()

	# Right-click resets each slider to its factory default
	Global.make_slider_resettable($MaxFPS/fpsDrag, 60)
	Global.make_slider_resettable($BounceForce/bounceForce, 250)
	Global.make_slider_resettable($BounceGravity/bounceGravity, 1000)
	Global.make_slider_resettable($BlinkSpeed/blinkSpeed, 1)
	Global.make_slider_resettable($BlinkChance/blinkChance, 200)

	var costumeLabels = [$CostumeInputs/ScrollContainer/VBoxContainer/costumeButton1/Label,$CostumeInputs/ScrollContainer/VBoxContainer/costumeButton2/Label,$CostumeInputs/ScrollContainer/VBoxContainer/costumeButton3/Label,$CostumeInputs/ScrollContainer/VBoxContainer/costumeButton4/Label,$CostumeInputs/ScrollContainer/VBoxContainer/costumeButton5/Label,$CostumeInputs/ScrollContainer/VBoxContainer/costumeButton6/Label,$CostumeInputs/ScrollContainer/VBoxContainer/costumeButton7/Label,$CostumeInputs/ScrollContainer/VBoxContainer/costumeButton8/Label,$CostumeInputs/ScrollContainer/VBoxContainer/costumeButton9/Label,$CostumeInputs/ScrollContainer/VBoxContainer/costumeButton10/Label,]
	var tag = 1
	for label in costumeLabels:
		label.text = "costume " + str(tag) + " key: \"" + Global.main.costumeKeys[tag-1] + "\""
		tag += 1
	
func _on_color_picker_button_color_changed(color):
	get_viewport().transparent_bg = false
	RenderingServer.set_default_clear_color(color)
	Global.backgroundColor = color
	Saving.settings["backgroundColor"] = var_to_str(color)
	
	Global.pushUpdate("Background color set to CUSTOM COLOR.")

func _on_button_pressed():
	get_viewport().transparent_bg = true
	Global.backgroundColor = Color(0.0,0.0,0.0,0.0)
	Saving.settings["backgroundColor"] = var_to_str(Color(0.0,0.0,0.0,0.0))
	
	Global.pushUpdate("Background color set to TRANSPARENT.")

func _on_color_picker_button_picker_created():
	get_viewport().transparent_bg = false
	RenderingServer.set_default_clear_color($Background/ColorPickerButton.color)
	
func _on_fps_drag_value_changed(value):
	if $MaxFPS/fpsDrag.value == 241:
		$MaxFPS/fpslabel.text = "Unlimited"
		return
	$MaxFPS/fpslabel.text = str(value)


func _on_confirm_pressed():
	if $MaxFPS/fpsDrag.value == 241:
		Engine.max_fps = 0
		Saving.settings["maxFPS"] = 0
		Global.pushUpdate("Max fps set to unlimited.")
		return
	Engine.max_fps = $MaxFPS/fpsDrag.value
	Saving.settings["maxFPS"] = $MaxFPS/fpsDrag.value
	
	Global.pushUpdate("Max fps set to " + str(Engine.max_fps) + ".")

func _on_green_button_pressed():
	get_viewport().transparent_bg = false
	Global.backgroundColor = Color(0.0,1.0,0.0,1.0)
	Saving.settings["backgroundColor"] = var_to_str(Color(0.0,1.0,0.0,1.0))
	RenderingServer.set_default_clear_color(Color(0.0,1.0,0.0,1.0))
	
	Global.pushUpdate("Background color set to GREEN.")

func _on_blue_button_pressed():
	get_viewport().transparent_bg = false
	Global.backgroundColor = Color(0.0,0.0,1.0,1.0)
	Saving.settings["backgroundColor"] = var_to_str(Color(0.0,0.0,1.0,1.0))
	RenderingServer.set_default_clear_color(Color(0.0,0.0,1.0,1.0))
	
	Global.pushUpdate("Background color set to BLUE.")

func _on_magenta_button_pressed():
	get_viewport().transparent_bg = false
	Global.backgroundColor = Color(1.0,0.0,1.0,1.0)
	Saving.settings["backgroundColor"] = var_to_str(Color(1.0,0.0,1.0,1.0))
	RenderingServer.set_default_clear_color(Color(1.0,0.0,1.0,1.0))
	
	Global.pushUpdate("Background color set to MAGENTA.")

func _on_check_box_toggled(button_pressed):
	var new = 0
	if button_pressed:
		new = 2
	var nodes = get_tree().get_nodes_in_group("saved")
	for sprite in nodes:
		sprite.sprite.texture_filter = new
	Global.filtering = button_pressed
	Saving.settings["filtering"] = button_pressed
	$AntiAliasing/CheckBox.button_pressed = button_pressed
	
	Global.pushUpdate("Texture filtering set to: " + str(button_pressed))

func _on_bounce_force_value_changed(value):
	$BounceForce/bounce.text = str(value)
	Global.main.bounceSlider = value
	Saving.settings["bounce"] = value
	Global.main.ndi_mark_dirty()

	Global.pushUpdate("Bounce force value changed.")

func _on_bounce_gravity_value_changed(value):
	$BounceGravity/bounce.text = str(value)
	Global.main.bounceGravity = value
	Saving.settings["gravity"] = value
	Global.main.ndi_mark_dirty()

	Global.pushUpdate("Bounce gravity value changed.")

func costumeButtonsPressed(label,id):
	label.text = "AWAITING INPUT"
	await Global.main.emptiedCapture
	awaitingCostumeInput = id - 1
	
	
	await Global.main.pressedKey
	label.text = "costume " + str(id) + " key: \"" + Global.main.costumeKeys[id - 1] + "\""
	await Global.main.emptiedCapture
	awaitingCostumeInput = -1

func _on_costume_button_1_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton1/Label
	costumeButtonsPressed(label,1)
func _on_costume_button_2_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton2/Label
	costumeButtonsPressed(label,2)
func _on_costume_button_3_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton3/Label
	costumeButtonsPressed(label,3)
func _on_costume_button_4_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton4/Label
	costumeButtonsPressed(label,4)
func _on_costume_button_5_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton5/Label
	costumeButtonsPressed(label,5)
func _on_costume_button_6_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton6/Label
	costumeButtonsPressed(label,6)
func _on_costume_button_7_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton7/Label
	costumeButtonsPressed(label,7)
func _on_costume_button_8_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton8/Label
	costumeButtonsPressed(label,8)
func _on_costume_button_9_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton9/Label
	costumeButtonsPressed(label,9)
func _on_costume_button_10_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton10/Label
	costumeButtonsPressed(label,10)


func _on_blink_speed_value_changed(value):
	if value == 0:
		Global.blinkSpeed = 0.0
		Saving.settings["blinkSpeed"] = 0.0
		$BlinkSpeed/Label.text = "blink speed: 0"
		return
	Global.blinkSpeed = 1.0/float(value)
	Saving.settings["blinkSpeed"] = 1.0/float(value)
	$BlinkSpeed/Label.text = "blink speed: " + str(value)


func _on_blink_chance_value_changed(value):
	Global.blinkChance = value
	Saving.settings["blinkChance"] = value
	$BlinkChance/Label.text = "blink chance: 1 in " + str(value)


func _on_costume_check_toggled(button_pressed):
	Global.main.bounceOnCostumeChange = button_pressed
	Saving.settings["bounceOnCostumeChange"] = button_pressed


func _process(_delta):
	var viewport_size := get_viewport().get_visible_rect().size
	var opened_now := visible and not _was_visible
	var resized_while_open := visible and viewport_size != _last_viewport_size

	if visible:
		_apply_viewport_constraints(opened_now or resized_while_open)
		hasMouse = _visible_panel_rect(viewport_size).has_point(get_global_mouse_position())
		_scroll_from_input_actions()
	else:
		hasMouse = false
		if _scrollbar != null:
			_scrollbar.visible = false

	_was_visible = visible
	_last_viewport_size = viewport_size


func _scroll_from_input_actions() -> void:
	if not hasMouse:
		return
	if $CostumeInputs/ScrollContainer.get_global_rect().has_point(get_global_mouse_position()):
		return

	if Input.is_action_just_pressed("scrollUp"):
		position.y += SCROLL_STEP
	elif Input.is_action_just_pressed("scrollDown"):
		position.y -= SCROLL_STEP
	else:
		return
	_apply_viewport_constraints(false)


func _apply_viewport_constraints(prefer_primary_settings: bool) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var panel := $NinePatchRect
	var parent_global_y: float = (get_parent() as Node2D).global_position.y
	var bounds := ResponsiveLayout.vertical_panel_bounds(
		viewport_size.y,
		parent_global_y,
		panel.position.y,
		panel.size.y,
		TOP_MARGIN,
		BOTTOM_CONTROLS_MARGIN
	)
	var top_aligned_y: float = TOP_MARGIN - parent_global_y - panel.position.y
	var bottom_aligned_y: float = (
		viewport_size.y
		- BOTTOM_CONTROLS_MARGIN
		- parent_global_y
		- panel.position.y
		- panel.size.y
	)
	var panel_fits := ResponsiveLayout.panel_fits_vertical_space(
		panel.size.y, viewport_size.y, TOP_MARGIN, BOTTOM_CONTROLS_MARGIN
	)

	if prefer_primary_settings:
		position.y = bottom_aligned_y if panel_fits else top_aligned_y
	else:
		position.y = clampf(position.y, bounds.x, bounds.y)

	_update_scrollbar(viewport_size, bounds, panel_fits)


func _update_scrollbar(viewport_size: Vector2, bounds: Vector2, panel_fits: bool) -> void:
	if _scrollbar == null or not is_instance_valid(_scrollbar):
		return

	_scroll_bounds = bounds
	_scrollbar.visible = visible and not panel_fits
	if not _scrollbar.visible:
		return

	var panel := $NinePatchRect
	var parent_node := get_parent() as Node2D
	var available_height := maxf(viewport_size.y - TOP_MARGIN - BOTTOM_CONTROLS_MARGIN, 1.0)
	_scrollbar.position = Vector2(
		position.x + panel.position.x + panel.size.x - 12.0,
		TOP_MARGIN - parent_node.global_position.y
	)
	_scrollbar.size = Vector2(12.0, available_height)
	var scroll_range := maxf(bounds.y - bounds.x, 1.0)
	var metrics := ResponsiveLayout.scrollbar_metrics(scroll_range, available_height, panel.size.y)
	_scrollbar.min_value = 0.0
	_scrollbar.max_value = metrics.x
	_scrollbar.page = metrics.y

	_syncing_scrollbar = true
	_scrollbar.value = clampf(bounds.y - position.y, 0.0, scroll_range)
	_syncing_scrollbar = false


func _on_viewport_scrollbar_changed(value: float) -> void:
	if _syncing_scrollbar or not visible:
		return
	position.y = clampf(_scroll_bounds.y - value, _scroll_bounds.x, _scroll_bounds.y)


func _visible_panel_rect(viewport_size: Vector2) -> Rect2:
	var panel_rect := Rect2(global_position + $NinePatchRect.position, $NinePatchRect.size)
	var usable_height := maxf(viewport_size.y - TOP_MARGIN - BOTTOM_CONTROLS_MARGIN, 1.0)
	var usable_rect := Rect2(
		Vector2(0.0, TOP_MARGIN),
		Vector2(viewport_size.x, usable_height)
	)
	return panel_rect.intersection(usable_rect)

func deleteKey(label,id):
	Global.main.costumeKeys[id-1] = "null"
	label.text = "costume " + str(id) + " key: \"" + Global.main.costumeKeys[id-1] + "\""
	Global.pushUpdate("Deleted costume hotkey " + str(id) + ".")
	
func _on_delete_1_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton1/Label
	deleteKey(label,1)

func _on_delete_2_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton2/Label
	deleteKey(label,2)

func _on_delete_3_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton3/Label
	deleteKey(label,3)

func _on_delete_4_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton4/Label
	deleteKey(label,4)

func _on_delete_5_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton5/Label
	deleteKey(label,5)

func _on_delete_6_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton6/Label
	deleteKey(label,6)

func _on_delete_7_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton7/Label
	deleteKey(label,7)

func _on_delete_8_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton8/Label
	deleteKey(label,8)

func _on_delete_9_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton9/Label
	deleteKey(label,9)

func _on_delete_10_pressed():
	var label = $CostumeInputs/ScrollContainer/VBoxContainer/costumeButton10/Label
	deleteKey(label,10)

# --- NDI Settings ---

func _build_ndi_section():
	if _ndi_section != null:
		return

	# Expand background to fit NDI section and shift menu up so it doesn't cover the settings icon
	$NinePatchRect.offset_bottom += 160
	position.y -= 160

	_ndi_section = Node2D.new()
	_ndi_section.name = "NDISettings"
	_ndi_section.position = Vector2(22, 405)
	add_child(_ndi_section)

	# Separator line
	var sep = ColorRect.new()
	sep.position = Vector2(-4, 0)
	sep.size = Vector2(380, 2)
	sep.color = Color(0.5, 0.5, 0.5, 0.4)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ndi_section.add_child(sep)

	# Title label
	var title = Label.new()
	title.position = Vector2(0, 6)
	title.text = "NDI Output"
	title.add_theme_font_size_override("font_size", 14)
	_ndi_section.add_child(title)

	# Status label (shows "plugin not installed" if needed)
	_ndi_status_label = Label.new()
	_ndi_status_label.position = Vector2(100, 6)
	_ndi_status_label.add_theme_font_size_override("font_size", 11)
	_ndi_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	_ndi_section.add_child(_ndi_status_label)

	# Enable toggle
	var toggle_label = Label.new()
	toggle_label.position = Vector2(0, 30)
	toggle_label.text = "enabled"
	_ndi_section.add_child(toggle_label)

	_ndi_toggle = CheckBox.new()
	_ndi_toggle.position = Vector2(130, 32)
	_ndi_toggle.size = Vector2(24, 24)
	_ndi_toggle.toggled.connect(_on_ndi_toggle)
	_ndi_section.add_child(_ndi_toggle)

	# Width preset
	var width_label = Label.new()
	width_label.position = Vector2(0, 58)
	width_label.text = "width"
	_ndi_section.add_child(width_label)

	_ndi_width_option = OptionButton.new()
	_ndi_width_option.position = Vector2(77, 58)
	_ndi_width_option.size = Vector2(100, 26)
	_ndi_width_option.add_item("512", 0)
	_ndi_width_option.add_item("720", 1)
	_ndi_width_option.add_item("1080", 2)
	_ndi_width_option.add_item("1920", 3)
	_ndi_width_option.item_selected.connect(_on_ndi_width_selected)
	_ndi_section.add_child(_ndi_width_option)

	# Mode selector
	var mode_label = Label.new()
	mode_label.position = Vector2(195, 58)
	mode_label.text = "mode"
	_ndi_section.add_child(mode_label)

	_ndi_mode_option = OptionButton.new()
	_ndi_mode_option.position = Vector2(240, 58)
	_ndi_mode_option.size = Vector2(110, 26)
	_ndi_mode_option.add_item("auto", 0)
	_ndi_mode_option.add_item("manual", 1)
	_ndi_mode_option.item_selected.connect(_on_ndi_mode_selected)
	_ndi_section.add_child(_ndi_mode_option)

	# Manual resolution inputs
	_ndi_manual_container = HBoxContainer.new()
	_ndi_manual_container.position = Vector2(0, 90)
	_ndi_manual_container.visible = false
	_ndi_section.add_child(_ndi_manual_container)

	var mw_label = Label.new()
	mw_label.text = "w:"
	_ndi_manual_container.add_child(mw_label)

	_ndi_manual_w = SpinBox.new()
	_ndi_manual_w.min_value = 128
	_ndi_manual_w.max_value = 3840
	_ndi_manual_w.step = 1
	_ndi_manual_w.custom_minimum_size = Vector2(80, 0)
	_ndi_manual_w.value_changed.connect(_on_ndi_manual_size_changed)
	_ndi_manual_container.add_child(_ndi_manual_w)

	var mh_label = Label.new()
	mh_label.text = "  h:"
	_ndi_manual_container.add_child(mh_label)

	_ndi_manual_h = SpinBox.new()
	_ndi_manual_h.min_value = 128
	_ndi_manual_h.max_value = 3840
	_ndi_manual_h.step = 1
	_ndi_manual_h.custom_minimum_size = Vector2(80, 0)
	_ndi_manual_h.value_changed.connect(_on_ndi_manual_size_changed)
	_ndi_manual_container.add_child(_ndi_manual_h)

	# Source name (applied on Enter or focus-out to avoid recycling NDI per keystroke)
	var name_label = Label.new()
	name_label.position = Vector2(0, 122)
	name_label.text = "source name"
	_ndi_section.add_child(name_label)

	_ndi_source_name_input = LineEdit.new()
	_ndi_source_name_input.position = Vector2(105, 120)
	_ndi_source_name_input.size = Vector2(245, 26)
	_ndi_source_name_input.placeholder_text = "PixelLab Studio"
	_ndi_source_name_input.text_submitted.connect(_on_ndi_source_name_committed)
	_ndi_source_name_input.focus_exited.connect(_on_ndi_source_name_focus_exited)
	_ndi_section.add_child(_ndi_source_name_input)

func _update_ndi_ui():
	if _ndi_section == null:
		return

	var ndi = Global.main.ndi_manager
	if ndi == null:
		return

	var plugin_ok = ndi.is_plugin_available()

	if !plugin_ok:
		_ndi_status_label.text = "(plugin not installed)"
		_ndi_toggle.disabled = true
		_ndi_toggle.button_pressed = false
		_ndi_width_option.disabled = true
		_ndi_mode_option.disabled = true
		if _ndi_source_name_input != null:
			_ndi_source_name_input.editable = false
		return

	_ndi_status_label.text = ""
	_ndi_toggle.disabled = false
	_ndi_toggle.button_pressed = ndi.is_enabled()

	if _ndi_source_name_input != null:
		_ndi_source_name_input.text = Saving.settings.get("ndiSourceName", "PixelLab Studio")
		_ndi_source_name_input.editable = true

	# Width preset
	var widths = [512, 720, 1080, 1920]
	var current_w = Saving.settings["ndiWidth"]
	var idx = widths.find(current_w)
	if idx >= 0:
		_ndi_width_option.selected = idx
	else:
		_ndi_width_option.selected = 0

	# Mode
	var mode = Saving.settings["ndiMode"]
	_ndi_mode_option.selected = 1 if mode == "manual" else 0
	_ndi_manual_container.visible = mode == "manual"

	if mode == "manual":
		_ndi_manual_w.value = Saving.settings["ndiManualWidth"]
		_ndi_manual_h.value = Saving.settings["ndiManualHeight"]

	var enabled = ndi.is_enabled()
	_ndi_width_option.disabled = !enabled
	_ndi_mode_option.disabled = !enabled

func _on_ndi_toggle(pressed: bool):
	var ndi = Global.main.ndi_manager
	if ndi == null:
		return
	ndi.set_enabled(pressed)
	_update_ndi_ui()
	# Update crop box visibility
	if Global.main.editMode:
		ndi.set_crop_visible(pressed)
	# Refresh window transparency (NDI disables it for performance)
	Global.main.updateWindowTransparency()
	if pressed:
		Global.pushUpdate("NDI output enabled.")
	else:
		Global.pushUpdate("NDI output disabled.")

func _on_ndi_width_selected(idx: int):
	var widths = [512, 720, 1080, 1920]
	if idx < widths.size():
		var ndi = Global.main.ndi_manager
		if ndi:
			ndi.set_width(widths[idx])
		Global.pushUpdate("NDI width set to " + str(widths[idx]) + ".")

func _on_ndi_mode_selected(idx: int):
	var mode = "auto" if idx == 0 else "manual"
	var ndi = Global.main.ndi_manager
	if ndi:
		ndi.set_mode(mode)
	_ndi_manual_container.visible = mode == "manual"
	Global.pushUpdate("NDI mode set to " + mode + ".")

func _on_ndi_manual_size_changed(_value: float):
	var ndi = Global.main.ndi_manager
	if ndi and _ndi_manual_w and _ndi_manual_h:
		ndi.set_manual_size(int(_ndi_manual_w.value), int(_ndi_manual_h.value))

func _on_ndi_source_name_committed(new_text: String):
	_apply_ndi_source_name(new_text)
	if _ndi_source_name_input != null:
		_ndi_source_name_input.release_focus()

func _on_ndi_source_name_focus_exited():
	if _ndi_source_name_input != null:
		_apply_ndi_source_name(_ndi_source_name_input.text)

func _apply_ndi_source_name(new_text: String):
	var ndi = Global.main.ndi_manager
	if ndi == null:
		return
	var prev = Saving.settings.get("ndiSourceName", "PixelLab Studio")
	ndi.set_source_name(new_text)
	var applied = Saving.settings.get("ndiSourceName", "PixelLab Studio")
	if _ndi_source_name_input != null:
		_ndi_source_name_input.text = applied
	if applied != prev:
		Global.pushUpdate("NDI source name set to \"" + applied + "\".")

# --- Recording Settings ---

func _build_recording_section():
	if _recording_section != null:
		return

	$NinePatchRect.offset_bottom += 60
	position.y -= 60

	_recording_section = Node2D.new()
	_recording_section.name = "RecordingSettings"
	_recording_section.position = Vector2(22, 565)
	add_child(_recording_section)

	# Separator line
	var sep = ColorRect.new()
	sep.position = Vector2(-4, 0)
	sep.size = Vector2(380, 2)
	sep.color = Color(0.5, 0.5, 0.5, 0.4)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recording_section.add_child(sep)

	# Title label
	var title = Label.new()
	title.position = Vector2(0, 6)
	title.text = "Recording"
	title.add_theme_font_size_override("font_size", 14)
	_recording_section.add_child(title)

	# Format label
	var fmt_label = Label.new()
	fmt_label.position = Vector2(0, 30)
	fmt_label.text = "format"
	_recording_section.add_child(fmt_label)

	# Format OptionButton
	_recording_format_option = OptionButton.new()
	_recording_format_option.position = Vector2(77, 30)
	_recording_format_option.size = Vector2(160, 26)
	_recording_format_option.add_item("Video (WebM)", 0)
	_recording_format_option.add_item("Animated PNG", 1)
	_recording_format_option.add_item("GIF", 2)
	_recording_format_option.item_selected.connect(_on_recording_format_selected)
	_recording_section.add_child(_recording_format_option)

	# FPS label
	var fps_label = Label.new()
	fps_label.position = Vector2(250, 30)
	fps_label.text = "fps"
	_recording_section.add_child(fps_label)

	# FPS OptionButton
	_recording_fps_option = OptionButton.new()
	_recording_fps_option.position = Vector2(285, 30)
	_recording_fps_option.size = Vector2(80, 26)
	_recording_fps_option.add_item("15", 0)
	_recording_fps_option.add_item("30", 1)
	_recording_fps_option.add_item("60", 2)
	_recording_fps_option.item_selected.connect(_on_recording_fps_selected)
	_recording_section.add_child(_recording_fps_option)

func _update_recording_ui():
	if _recording_format_option == null:
		return
	var fmt = Saving.settings.get("recordingFormat", "webm")
	var formats = ["webm", "apng", "gif"]
	var idx = formats.find(fmt)
	if idx >= 0:
		_recording_format_option.selected = idx
	else:
		_recording_format_option.selected = 0

	if _recording_fps_option != null:
		var fps = Saving.settings.get("recordingFPS", 30)
		var fps_values = [15, 30, 60]
		var fps_idx = fps_values.find(fps)
		if fps_idx >= 0:
			_recording_fps_option.selected = fps_idx
		else:
			_recording_fps_option.selected = 1

func _on_recording_format_selected(idx: int):
	var formats = ["webm", "apng", "gif"]
	if idx < formats.size():
		Saving.settings["recordingFormat"] = formats[idx]
		# Auto-set FPS based on format
		var fmt = formats[idx]
		if fmt == "apng" or fmt == "gif":
			Saving.settings["recordingFPS"] = 15
		elif fmt == "webm":
			Saving.settings["recordingFPS"] = 30
		_update_recording_ui()
		Global.pushUpdate("Recording format set to " + _recording_format_option.get_item_text(idx) + ".")

func _on_recording_fps_selected(idx: int):
	var fps_values = [15, 30, 60]
	if idx < fps_values.size():
		Saving.settings["recordingFPS"] = fps_values[idx]
		Global.pushUpdate("Recording FPS set to " + str(fps_values[idx]) + ".")
