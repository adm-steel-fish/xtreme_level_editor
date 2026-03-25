@tool
class_name XtremeSettingsMode
extends XtremeEditorMode

## Settings Mode - Edit level metadata, visual settings, and game properties.
## No 3D viewport interaction — purely form-based.

# UI references
var _name_edit: LineEdit
var _author_edit: LineEdit
var _description_edit: TextEdit
var _time_limit_spin: SpinBox
var _music_edit: LineEdit
var _ring_target_spin: SpinBox
var _time_bonus_a_spin: SpinBox
var _time_bonus_b_spin: SpinBox
var _time_bonus_c_spin: SpinBox
var _zone_preset_selector: OptionButton
var _status_label: Label

# Zone visual settings for editing
var _editing_zone_settings: ZoneVisualSettings


func activate() -> void:
	super.activate()
	_load_from_level_data()


func deactivate() -> void:
	# Save any pending changes back to level data
	_save_to_level_data()
	super.deactivate()


func create_ui() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# Header
	var header := Label.new()
	header.text = "LEVEL SETTINGS"
	header.add_theme_font_size_override("font_size", 14)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)

	content.add_child(HSeparator.new())

	# ===== Level Metadata =====
	content.add_child(_make_section_label("Level Info"))

	content.add_child(make_label("Name:"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Level Name"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_name_edit)

	content.add_child(make_label("Author:"))
	_author_edit = LineEdit.new()
	_author_edit.placeholder_text = "Author Name"
	_author_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_author_edit)

	content.add_child(make_label("Description:"))
	_description_edit = TextEdit.new()
	_description_edit.placeholder_text = "Level description..."
	_description_edit.custom_minimum_size.y = 60
	_description_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_description_edit)

	content.add_child(HSeparator.new())

	# ===== Gameplay Settings =====
	content.add_child(_make_section_label("Gameplay"))

	var time_row := HBoxContainer.new()
	time_row.add_child(make_label("Time Limit (s):"))
	_time_limit_spin = SpinBox.new()
	_time_limit_spin.min_value = 0
	_time_limit_spin.max_value = 999
	_time_limit_spin.value = 0
	_time_limit_spin.suffix = "s"
	_time_limit_spin.tooltip_text = "0 = no time limit"
	_time_limit_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(_time_limit_spin)
	content.add_child(time_row)

	content.add_child(make_label("Music Track:"))
	var music_row := HBoxContainer.new()
	_music_edit = LineEdit.new()
	_music_edit.placeholder_text = "res://audio/music/zone1.ogg"
	_music_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_row.add_child(_music_edit)
	var browse_music_btn := Button.new()
	browse_music_btn.text = "..."
	browse_music_btn.pressed.connect(_browse_music)
	music_row.add_child(browse_music_btn)
	content.add_child(music_row)

	content.add_child(HSeparator.new())

	# ===== Scoring =====
	content.add_child(_make_section_label("Scoring"))

	var ring_row := HBoxContainer.new()
	ring_row.add_child(make_label("Ring Target:"))
	_ring_target_spin = SpinBox.new()
	_ring_target_spin.min_value = 0
	_ring_target_spin.max_value = 9999
	_ring_target_spin.value = 100
	_ring_target_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ring_row.add_child(_ring_target_spin)
	content.add_child(ring_row)

	content.add_child(make_label("Time Bonuses (seconds):"))
	var bonus_grid := GridContainer.new()
	bonus_grid.columns = 6
	bonus_grid.add_child(make_label("A:"))
	_time_bonus_a_spin = SpinBox.new()
	_time_bonus_a_spin.min_value = 0
	_time_bonus_a_spin.max_value = 999
	_time_bonus_a_spin.value = 60
	_time_bonus_a_spin.custom_minimum_size.x = 60
	bonus_grid.add_child(_time_bonus_a_spin)
	bonus_grid.add_child(make_label("B:"))
	_time_bonus_b_spin = SpinBox.new()
	_time_bonus_b_spin.min_value = 0
	_time_bonus_b_spin.max_value = 999
	_time_bonus_b_spin.value = 120
	_time_bonus_b_spin.custom_minimum_size.x = 60
	bonus_grid.add_child(_time_bonus_b_spin)
	bonus_grid.add_child(make_label("C:"))
	_time_bonus_c_spin = SpinBox.new()
	_time_bonus_c_spin.min_value = 0
	_time_bonus_c_spin.max_value = 999
	_time_bonus_c_spin.value = 180
	_time_bonus_c_spin.custom_minimum_size.x = 60
	bonus_grid.add_child(_time_bonus_c_spin)
	content.add_child(bonus_grid)

	content.add_child(HSeparator.new())

	# ===== Zone Visuals Preset =====
	content.add_child(_make_section_label("Zone Visuals"))
	content.add_child(make_label("Preset:"))
	_zone_preset_selector = OptionButton.new()
	_zone_preset_selector.add_item("Custom", 0)
	_zone_preset_selector.add_item("Green Hill (Bright)", 1)
	_zone_preset_selector.add_item("Chemical Plant (Industrial)", 2)
	_zone_preset_selector.add_item("Lava Reef (Volcanic)", 3)
	_zone_preset_selector.add_item("Night Zone (Dark)", 4)
	_zone_preset_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_preset_selector.item_selected.connect(_on_zone_preset_selected)
	content.add_child(_zone_preset_selector)

	var apply_preset_btn := Button.new()
	apply_preset_btn.text = "Apply Preset to Level"
	apply_preset_btn.pressed.connect(_apply_zone_preset)
	content.add_child(apply_preset_btn)

	content.add_child(HSeparator.new())

	# ===== Actions =====
	var save_btn := Button.new()
	save_btn.text = "Save Settings to Level"
	save_btn.custom_minimum_size.y = 35
	save_btn.pressed.connect(_on_save_settings)
	content.add_child(save_btn)

	# Status
	_status_label = Label.new()
	_status_label.text = "Load or create a level to edit settings"
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)

	return scroll


func _load_from_level_data() -> void:
	if not level_data:
		_set_settings_status("No level loaded")
		return

	if _name_edit:
		_name_edit.text = level_data.level_name
	if _author_edit:
		_author_edit.text = level_data.level_author
	if _description_edit:
		_description_edit.text = level_data.level_description

	# Load extended properties (these are @export properties on XtremeLevelData)
	if _time_limit_spin:
		_time_limit_spin.value = level_data.time_limit
	if _music_edit:
		_music_edit.text = level_data.music_track
	if _ring_target_spin:
		_ring_target_spin.value = level_data.ring_target
	if _time_bonus_a_spin:
		_time_bonus_a_spin.value = level_data.time_bonus_a
	if _time_bonus_b_spin:
		_time_bonus_b_spin.value = level_data.time_bonus_b
	if _time_bonus_c_spin:
		_time_bonus_c_spin.value = level_data.time_bonus_c

	_set_settings_status("Settings loaded from '%s'" % level_data.level_name)


func _save_to_level_data() -> void:
	if not level_data:
		return

	if _name_edit:
		level_data.level_name = _name_edit.text
	if _author_edit:
		level_data.level_author = _author_edit.text
	if _description_edit:
		level_data.level_description = _description_edit.text

	# Save extended properties
	if _time_limit_spin:
		level_data.time_limit = _time_limit_spin.value
	if _music_edit:
		level_data.music_track = _music_edit.text
	if _ring_target_spin:
		level_data.ring_target = int(_ring_target_spin.value)
	if _time_bonus_a_spin:
		level_data.time_bonus_a = _time_bonus_a_spin.value
	if _time_bonus_b_spin:
		level_data.time_bonus_b = _time_bonus_b_spin.value
	if _time_bonus_c_spin:
		level_data.time_bonus_c = _time_bonus_c_spin.value


func _on_save_settings() -> void:
	_save_to_level_data()
	_set_settings_status("Settings saved")
	set_status("Level settings updated")


func _browse_music() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.ogg,*.mp3,*.wav", "Audio Files")
	dialog.file_selected.connect(func(path: String):
		if _music_edit:
			_music_edit.text = path
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))


func _on_zone_preset_selected(_index: int) -> void:
	pass  # Just selection, applied by button


func _apply_zone_preset() -> void:
	var preset_id := _zone_preset_selector.get_selected_id()
	match preset_id:
		1:
			_editing_zone_settings = ZoneVisualSettings.create_green_hill_preset()
			_set_settings_status("Applied Green Hill preset")
		2:
			_editing_zone_settings = ZoneVisualSettings.create_chemical_plant_preset()
			_set_settings_status("Applied Chemical Plant preset")
		3:
			_editing_zone_settings = ZoneVisualSettings.create_lava_reef_preset()
			_set_settings_status("Applied Lava Reef preset")
		4:
			_editing_zone_settings = ZoneVisualSettings.create_night_preset()
			_set_settings_status("Applied Night Zone preset")
		_:
			_set_settings_status("Select a preset first")
			return

	# Store the zone settings reference on the level data
	if level_data:
		level_data.zone_visual_settings = _editing_zone_settings

	set_status("Zone preset applied")


func _set_settings_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	return label
