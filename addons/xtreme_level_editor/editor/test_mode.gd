@tool
class_name XtremeTestMode
extends XtremeEditorMode

## Test Mode - Play-test levels directly from the editor.
## Exports to a temporary scene, injects the player, and launches it.

const TEMP_EXPORT_DIR := "res://addons/xtreme_level_editor/temp/"
const TEMP_LEVEL_PATH := "res://addons/xtreme_level_editor/temp/test_level.tscn"
const PLAYER_SCENE_PATH := "res://scenes/prefabs/player_1_4.tscn"

var _play_button: Button
var _stop_button: Button
var _status_label: Label
var _spawn_x: SpinBox
var _spawn_y: SpinBox
var _spawn_z: SpinBox
var _camera_mode_selector: OptionButton
var _is_playing: bool = false


func activate() -> void:
	super.activate()
	_update_play_state()


func deactivate() -> void:
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
	header.text = "PLAY TEST"
	header.add_theme_font_size_override("font_size", 14)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)

	content.add_child(HSeparator.new())

	# Spawn Point
	content.add_child(make_label("Spawn Point"))
	var spawn_grid := GridContainer.new()
	spawn_grid.columns = 6
	spawn_grid.add_child(make_label("X:"))
	_spawn_x = SpinBox.new()
	_spawn_x.min_value = -500
	_spawn_x.max_value = 500
	_spawn_x.value = 0
	_spawn_x.custom_minimum_size.x = 60
	spawn_grid.add_child(_spawn_x)
	spawn_grid.add_child(make_label("Y:"))
	_spawn_y = SpinBox.new()
	_spawn_y.min_value = -500
	_spawn_y.max_value = 500
	_spawn_y.value = 5
	_spawn_y.custom_minimum_size.x = 60
	spawn_grid.add_child(_spawn_y)
	spawn_grid.add_child(make_label("Z:"))
	_spawn_z = SpinBox.new()
	_spawn_z.min_value = -500
	_spawn_z.max_value = 500
	_spawn_z.value = 0
	_spawn_z.custom_minimum_size.x = 60
	spawn_grid.add_child(_spawn_z)
	content.add_child(spawn_grid)

	var auto_spawn_btn := Button.new()
	auto_spawn_btn.text = "Auto-detect Spawn"
	auto_spawn_btn.tooltip_text = "Find spawn tile in level data and use its position"
	auto_spawn_btn.pressed.connect(_auto_detect_spawn)
	content.add_child(auto_spawn_btn)

	content.add_child(HSeparator.new())

	# Camera Mode
	content.add_child(make_label("Camera Mode"))
	_camera_mode_selector = OptionButton.new()
	_camera_mode_selector.add_item("Curved World Follow", 0)
	_camera_mode_selector.add_item("Side Scroller", 1)
	_camera_mode_selector.add_item("Free Camera", 2)
	_camera_mode_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_camera_mode_selector)

	content.add_child(HSeparator.new())

	# Play/Stop buttons
	var button_row := HBoxContainer.new()
	_play_button = Button.new()
	_play_button.text = "Play"
	_play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_button.custom_minimum_size.y = 40
	_play_button.pressed.connect(_on_play_pressed)
	button_row.add_child(_play_button)

	_stop_button = Button.new()
	_stop_button.text = "Stop"
	_stop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stop_button.custom_minimum_size.y = 40
	_stop_button.disabled = true
	_stop_button.pressed.connect(_on_stop_pressed)
	button_row.add_child(_stop_button)
	content.add_child(button_row)

	content.add_child(HSeparator.new())

	# Status
	_status_label = Label.new()
	_status_label.text = "Ready to test"
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)

	# Tips
	content.add_child(HSeparator.new())
	var tips := Label.new()
	tips.text = "Tips:\n- Set spawn point above solid ground\n- Auto-detect finds 'spawn' tiles\n- Uses current curve/effect settings"
	tips.add_theme_font_size_override("font_size", 11)
	tips.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(tips)

	return scroll


func _auto_detect_spawn() -> void:
	if not level_data:
		_set_test_status("No level loaded")
		return

	# Look for spawn tiles in the level data
	var spawn_positions := level_data.get_tiles_of_type(&"spawn")
	if spawn_positions.is_empty():
		spawn_positions = level_data.get_tiles_of_type(&"player_spawn")
	if spawn_positions.is_empty():
		spawn_positions = level_data.get_tiles_of_type(&"start")

	if spawn_positions.size() > 0:
		var spawn_pos: Vector3i = spawn_positions[0]
		var cell_size := grid_settings.get_cell_size() if grid_settings else Vector3(2, 2, 2)
		# Place spawn slightly above the tile
		_spawn_x.value = spawn_pos.x * cell_size.x + cell_size.x * 0.5
		_spawn_y.value = spawn_pos.y * cell_size.y + cell_size.y + 1.0
		_spawn_z.value = spawn_pos.z * cell_size.z + cell_size.z * 0.5
		_set_test_status("Spawn detected at tile (%d, %d, %d)" % [spawn_pos.x, spawn_pos.y, spawn_pos.z])
	else:
		# Default: center of level, above ground
		var cx := level_data.size_x / 2
		var cz := level_data.size_z / 2
		var cell_size := grid_settings.get_cell_size() if grid_settings else Vector3(2, 2, 2)
		_spawn_x.value = cx * cell_size.x
		_spawn_y.value = 5 * cell_size.y
		_spawn_z.value = cz * cell_size.z
		_set_test_status("No spawn tile found, using center of level")


func _on_play_pressed() -> void:
	if not level_data:
		_set_test_status("No level loaded - load or create a level first")
		return

	if not grid_settings:
		_set_test_status("No grid settings available")
		return

	_set_test_status("Exporting test level...")

	# Ensure temp directory exists
	if not DirAccess.dir_exists_absolute(TEMP_EXPORT_DIR):
		DirAccess.make_dir_recursive_absolute(TEMP_EXPORT_DIR)

	# Export using the existing exporter
	var exporter := XtremeLevelExporter.new()
	exporter.grid_settings = grid_settings
	exporter.level_data = level_data
	if palette:
		exporter.tile_palette = palette
	exporter.export_mode = XtremeLevelExporter.ExportMode.HYBRID_CHUNKED

	# Read curve settings from the plugin's dock if available
	_apply_curve_settings_from_dock(exporter)

	# Export grind rails/coasters/dash trails if the plugin has them
	_apply_path_data_from_plugin(exporter)

	var err := exporter.export_level(TEMP_LEVEL_PATH)
	if err != OK:
		_set_test_status("Export failed (error %d)" % err)
		return

	# Now modify the exported scene to inject player and spawn point
	var packed := load(TEMP_LEVEL_PATH) as PackedScene
	if not packed:
		_set_test_status("Failed to load exported scene")
		return

	var scene := packed.instantiate()

	# Add player
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene:
		var player := player_scene.instantiate()
		player.name = "TestPlayer"
		var spawn_pos := Vector3(_spawn_x.value, _spawn_y.value, _spawn_z.value)
		player.position = spawn_pos
		scene.add_child(player)
		player.owner = scene
	else:
		_set_test_status("Warning: Player scene not found at %s" % PLAYER_SCENE_PATH)

	# Add a camera if the player doesn't have one, or use the XtremeCameraSystem
	var camera_script_path := "res://addons/xtreme_level_editor/nodes/xtreme_camera_system.gd"
	if ResourceLoader.exists(camera_script_path):
		var cam := Camera3D.new()
		cam.name = "TestCamera"
		var cam_script = load(camera_script_path)
		if cam_script:
			cam.set_script(cam_script)
			# Set camera mode based on selector
			var mode_id := _camera_mode_selector.get_selected_id()
			cam.set("initial_mode", mode_id)
		cam.position = Vector3(_spawn_x.value, _spawn_y.value + 5, _spawn_z.value + 10)
		scene.add_child(cam)
		cam.owner = scene

	# Save the modified scene
	var modified_packed := PackedScene.new()
	modified_packed.pack(scene)
	err = ResourceSaver.save(modified_packed, TEMP_LEVEL_PATH)
	scene.queue_free()

	if err != OK:
		_set_test_status("Failed to save test scene")
		return

	# Launch the test scene
	EditorInterface.play_custom_scene(TEMP_LEVEL_PATH)
	_is_playing = true
	_update_play_state()
	_set_test_status("Playing test level...")


func _on_stop_pressed() -> void:
	EditorInterface.stop_playing_scene()
	_is_playing = false
	_update_play_state()
	_set_test_status("Stopped")


func _update_play_state() -> void:
	if _play_button:
		_play_button.disabled = _is_playing
	if _stop_button:
		_stop_button.disabled = not _is_playing


func _set_test_status(text: String) -> void:
	if _status_label:
		_status_label.text = text
	set_status(text)


func _apply_curve_settings_from_dock(exporter: XtremeLevelExporter) -> void:
	if not plugin:
		return
	# Try to read current curve settings from plugin's dock
	var dock = plugin.get("_main_dock")
	if not dock or not is_instance_valid(dock):
		return

	var curve_check = dock.find_child("ExportWithCurve", true, false) as CheckBox
	exporter.apply_curved_world = curve_check.button_pressed if curve_check else true

	var h_curve = dock.find_child("CurveHorizontal", true, false) as HSlider
	exporter.curve_horizontal = h_curve.value if h_curve else 0.15

	var v_curve = dock.find_child("CurveVertical", true, false) as HSlider
	exporter.curve_vertical = v_curve.value if v_curve else 0.08

	var falloff = dock.find_child("CurveFalloff", true, false) as HSlider
	exporter.curve_falloff_exponent = falloff.value if falloff else 2.0

	var dist_check = dock.find_child("DistanceEffectsEnabled", true, false) as CheckBox
	exporter.distance_effects_enabled = dist_check.button_pressed if dist_check else true

	var max_dist = dock.find_child("EffectMaxDistance", true, false) as HSlider
	exporter.effect_max_distance = max_dist.value if max_dist else 150.0

	var wire_start = dock.find_child("WireframeStart", true, false) as HSlider
	exporter.wireframe_start = wire_start.value if wire_start else 0.3
	exporter.wireframe_full = (wire_start.value + 0.4) if wire_start else 0.7

	var diss_start = dock.find_child("DissolveStart", true, false) as HSlider
	exporter.dissolve_start = diss_start.value if diss_start else 0.3
	exporter.dissolve_full = (diss_start.value + 0.6) if diss_start else 0.9


func _apply_path_data_from_plugin(exporter: XtremeLevelExporter) -> void:
	if not plugin:
		return
	# Copy path data from the plugin if available
	var rails = plugin.get("_rails")
	if rails is Array:
		exporter.grind_rails = rails.duplicate()
	var coasters = plugin.get("_coasters")
	if coasters is Array:
		exporter.roller_coasters = coasters.duplicate()
	var dash_trails = plugin.get("_dash_trails")
	if dash_trails is Array:
		exporter.light_dash_trails = dash_trails.duplicate()
