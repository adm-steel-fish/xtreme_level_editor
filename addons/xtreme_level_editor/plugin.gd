@tool
extends EditorPlugin

## Xtreme Level Editor - Main Plugin
## A 3D cubemap/tilemap level editor inspired by Sonic Xtreme

const PLUGIN_NAME := "Xtreme Level Editor"
const SETTINGS_PATH := "res://xtreme_level_editor_settings.tres"
const MAX_UNDO_HISTORY := 10

# UI Elements
var _main_dock: Control
var _tile_selector: OptionButton
var _y_level_spinbox: SpinBox
var _brush_size_spinbox: SpinBox
var _grid_visible_check: CheckBox
var _context_menu: PopupMenu

# Scene elements
var _grid_visualizer: XtremeGridVisualizer
var _grid_lines_mesh: MeshInstance3D
var _selection_box_mesh: MeshInstance3D
var _brush_preview_mesh: MeshInstance3D
var _rect_preview_mesh: MeshInstance3D
var _select_preview_mesh: MeshInstance3D

# State
var _current_level: XtremeLevelData
var _current_palette: XtremeTilePalette
var _grid_settings: XtremeGridSettings
var _selected_tile_id: StringName = &"solid"
var _edit_mode: int = 0  # 0=paint, 1=erase, 2=select, 3=rect_fill, 4=bucket_fill
var _current_y_level: int = 0
var _brush_size: int = 1
var _is_plugin_active: bool = false
var _editing_enabled: bool = false

# Drag painting state
var _is_dragging: bool = false
var _last_drag_pos: Vector3i = Vector3i(-1, -1, -1)

# Selection state
var _selection_start: Vector3i = Vector3i(-1, -1, -1)
var _selection_end: Vector3i = Vector3i(-1, -1, -1)
var _has_selection: bool = false
var _awaiting_second_click: bool = false

# Rect fill drag state
var _rect_drag_start: Vector3i = Vector3i(-1, -1, -1)
var _rect_dragging: bool = false

# Select drag state (for preview)
var _select_dragging: bool = false

# Undo/Redo system
var _undo_history: Array[Dictionary] = []
var _redo_history: Array[Dictionary] = []

# Last known mouse position
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _get_plugin_name() -> String:
	return PLUGIN_NAME

func _enter_tree() -> void:
	_load_or_create_settings()
	_create_default_palette()
	_register_custom_types()
	_create_editor_dock()
	_create_context_menu()
	_is_plugin_active = true
	print("[%s] Plugin initialized" % PLUGIN_NAME)

func _exit_tree() -> void:
	_is_plugin_active = false
	_editing_enabled = false
	
	if _main_dock:
		remove_control_from_docks(_main_dock)
		_main_dock.queue_free()
		_main_dock = null
	
	if _context_menu:
		_context_menu.queue_free()
		_context_menu = null
	
	_cleanup_visualizer()
	_unregister_custom_types()
	print("[%s] Plugin cleaned up" % PLUGIN_NAME)

func _cleanup_visualizer() -> void:
	if _grid_visualizer and is_instance_valid(_grid_visualizer):
		_grid_visualizer.queue_free()
		_grid_visualizer = null
	if _grid_lines_mesh and is_instance_valid(_grid_lines_mesh):
		_grid_lines_mesh.queue_free()
		_grid_lines_mesh = null
	if _selection_box_mesh and is_instance_valid(_selection_box_mesh):
		_selection_box_mesh.queue_free()
		_selection_box_mesh = null
	if _brush_preview_mesh and is_instance_valid(_brush_preview_mesh):
		_brush_preview_mesh.queue_free()
		_brush_preview_mesh = null
	if _rect_preview_mesh and is_instance_valid(_rect_preview_mesh):
		_rect_preview_mesh.queue_free()
		_rect_preview_mesh = null
	if _select_preview_mesh and is_instance_valid(_select_preview_mesh):
		_select_preview_mesh.queue_free()
		_select_preview_mesh = null

func _register_custom_types() -> void:
	add_custom_type("XtremeGridSettings", "Resource",
		preload("res://addons/xtreme_level_editor/resources/grid_settings.gd"), null)
	add_custom_type("XtremeLevelData", "Resource",
		preload("res://addons/xtreme_level_editor/resources/level_data.gd"), null)
	add_custom_type("XtremeTileDefinition", "Resource",
		preload("res://addons/xtreme_level_editor/resources/tile_definition.gd"), null)
	add_custom_type("XtremeTilePalette", "Resource",
		preload("res://addons/xtreme_level_editor/resources/tile_palette.gd"), null)
	add_custom_type("XtremeLevelChunk", "Resource",
		preload("res://addons/xtreme_level_editor/resources/level_chunk.gd"), null)
	add_custom_type("XtremeTraversalProfile", "Resource",
		preload("res://addons/xtreme_level_editor/resources/traversal_profile.gd"), null)

func _unregister_custom_types() -> void:
	remove_custom_type("XtremeGridSettings")
	remove_custom_type("XtremeLevelData")
	remove_custom_type("XtremeTileDefinition")
	remove_custom_type("XtremeTilePalette")
	remove_custom_type("XtremeLevelChunk")
	remove_custom_type("XtremeTraversalProfile")

func _load_or_create_settings() -> void:
	if ResourceLoader.exists(SETTINGS_PATH):
		_grid_settings = load(SETTINGS_PATH) as XtremeGridSettings
	if not _grid_settings:
		_grid_settings = XtremeGridSettings.new()
		ResourceSaver.save(_grid_settings, SETTINGS_PATH)

func _create_default_palette() -> void:
	_current_palette = XtremeTilePalette.new()
	_current_palette.palette_name = "Default"
	
	var tiles_data := [
		{&"solid": ["Solid Block", Color(0.6, 0.6, 0.6)]},
		{&"platform": ["Platform", Color(0.4, 0.7, 0.4)]},
		{&"spike": ["Spikes", Color(1.0, 0.2, 0.2)]},
		{&"spring": ["Spring", Color(1.0, 1.0, 0.2)]},
		{&"ring": ["Ring", Color(1.0, 0.85, 0.0)]},
		{&"boost": ["Boost Pad", Color(0.2, 0.8, 1.0)]},
		{&"checkpoint": ["Checkpoint", Color(0.2, 1.0, 0.5)]},
		{&"goal": ["Goal", Color(0.3, 0.5, 1.0)]},
	]
	
	for tile_info in tiles_data:
		for tile_id in tile_info.keys():
			var data: Array = tile_info[tile_id]
			var tile := XtremeTileDefinition.new()
			tile.tile_id = tile_id
			tile.display_name = data[0]
			tile.editor_color = data[1]
			_current_palette.tiles.append(tile)

func _create_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.name = "XtremeContextMenu"
	
	# Tools
	_context_menu.add_item("Paint", 0)
	_context_menu.add_item("Erase", 1)
	_context_menu.add_item("Select Region", 2)
	_context_menu.add_item("Rect Fill (Drag)", 3)
	_context_menu.add_item("Bucket Fill", 4)
	_context_menu.add_separator()
	
	# Undo/Redo
	_context_menu.add_item("Undo", 30)
	_context_menu.add_item("Redo", 31)
	_context_menu.add_separator()
	
	# Quick actions
	_context_menu.add_item("Fill Selection", 10)
	_context_menu.add_item("Clear Selection", 11)
	_context_menu.add_item("Deselect", 12)
	_context_menu.add_separator()
	
	# Layer controls
	_context_menu.add_item("Layer Up", 20)
	_context_menu.add_item("Layer Down", 21)
	
	_context_menu.id_pressed.connect(_on_context_menu_selected)
	EditorInterface.get_base_control().add_child(_context_menu)

func _on_context_menu_selected(id: int) -> void:
	match id:
		0: _set_tool(0)
		1: _set_tool(1)
		2: _set_tool(2)
		3: _set_tool(3)
		4: _set_tool(4)
		10: _on_fill_selection()
		11: _on_clear_selection_tiles()
		12: _clear_selection()
		20: _change_y_level(1)
		21: _change_y_level(-1)
		30: _undo()
		31: _redo()

func _set_tool(tool_id: int) -> void:
	_edit_mode = tool_id
	_clear_selection()
	var tool_names := ["Paint", "Erase", "Select", "Rect Fill", "Bucket Fill"]
	_set_status("Tool: %s" % tool_names[tool_id])
	_update_tool_buttons()

func _update_tool_buttons() -> void:
	if not _main_dock:
		return
	var paint_btn := _main_dock.find_child("PaintBtn", true, false) as Button
	var erase_btn := _main_dock.find_child("EraseBtn", true, false) as Button
	var select_btn := _main_dock.find_child("SelectBtn", true, false) as Button
	var rect_btn := _main_dock.find_child("RectFillBtn", true, false) as Button
	var bucket_btn := _main_dock.find_child("BucketBtn", true, false) as Button
	
	if paint_btn: paint_btn.button_pressed = (_edit_mode == 0)
	if erase_btn: erase_btn.button_pressed = (_edit_mode == 1)
	if select_btn: select_btn.button_pressed = (_edit_mode == 2)
	if rect_btn: rect_btn.button_pressed = (_edit_mode == 3)
	if bucket_btn: bucket_btn.button_pressed = (_edit_mode == 4)

func _change_y_level(delta: int) -> void:
	if not _current_level:
		return
	var new_level := clampi(_current_y_level + delta, 0, _current_level.size_y - 1)
	if new_level != _current_y_level:
		_current_y_level = new_level
		if _y_level_spinbox:
			_y_level_spinbox.value = _current_y_level
		_update_grid_lines()
		_update_selection_visual()
		_set_status("Y Level: %d" % _current_y_level)

# ============ Undo/Redo System ============

func _record_undo(action_name: String, tiles_before: Dictionary, tiles_after: Dictionary) -> void:
	var undo_entry := {
		"action": action_name,
		"before": tiles_before.duplicate(),
		"after": tiles_after.duplicate()
	}
	
	_undo_history.push_back(undo_entry)
	
	# Limit history size
	while _undo_history.size() > MAX_UNDO_HISTORY:
		_undo_history.pop_front()
	
	# Clear redo history when new action is performed
	_redo_history.clear()

func _undo() -> void:
	if _undo_history.size() == 0:
		_set_status("Nothing to undo")
		return
	
	var entry: Dictionary = _undo_history.pop_back()
	
	# Restore tiles to before state
	for pos in entry.after.keys():
		_current_level.clear_tile(pos)
	for pos in entry.before.keys():
		_current_level.set_tile(pos, entry.before[pos])
	
	_redo_history.push_back(entry)
	
	if _grid_visualizer:
		_grid_visualizer.rebuild()
	
	_set_status("Undo: %s" % entry.action)

func _redo() -> void:
	if _redo_history.size() == 0:
		_set_status("Nothing to redo")
		return
	
	var entry: Dictionary = _redo_history.pop_back()
	
	# Restore tiles to after state
	for pos in entry.before.keys():
		_current_level.clear_tile(pos)
	for pos in entry.after.keys():
		_current_level.set_tile(pos, entry.after[pos])
	
	_undo_history.push_back(entry)
	
	if _grid_visualizer:
		_grid_visualizer.rebuild()
	
	_set_status("Redo: %s" % entry.action)

func _capture_tiles_in_region(positions: Array[Vector3i]) -> Dictionary:
	var tiles := {}
	for pos in positions:
		if _current_level.has_tile(pos):
			tiles[pos] = _current_level.get_tile(pos)
	return tiles

# ============ Editor Dock ============

func _create_editor_dock() -> void:
	_main_dock = VBoxContainer.new()
	_main_dock.name = "XtremeLevelEditorDock"
	_main_dock.custom_minimum_size = Vector2(250, 300)
	
	var header := Label.new()
	header.text = "Xtreme Level Editor"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	_main_dock.add_child(header)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_dock.add_child(scroll)
	
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	
	content.add_child(HSeparator.new())
	
	# Editing Toggle
	var edit_toggle := CheckBox.new()
	edit_toggle.name = "EditingEnabled"
	edit_toggle.text = "Enable Level Editing"
	edit_toggle.toggled.connect(_on_editing_toggled)
	content.add_child(edit_toggle)
	
	content.add_child(HSeparator.new())
	
	# Level Management
	content.add_child(_make_label("Level"))
	var level_buttons := HBoxContainer.new()
	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_on_new_level)
	level_buttons.add_child(new_btn)
	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_on_load_level)
	level_buttons.add_child(load_btn)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_level)
	level_buttons.add_child(save_btn)
	content.add_child(level_buttons)
	
	content.add_child(HSeparator.new())
	
	# Tile Selector
	content.add_child(_make_label("Selected Tile"))
	_tile_selector = OptionButton.new()
	_tile_selector.name = "TileSelector"
	_update_tile_selector()
	_tile_selector.item_selected.connect(_on_tile_selected)
	content.add_child(_tile_selector)
	
	content.add_child(HSeparator.new())
	
	# Tools
	content.add_child(_make_label("Tool (Right-click for menu)"))
	var tool_group := ButtonGroup.new()
	
	var tool_row1 := HBoxContainer.new()
	var paint_btn := Button.new()
	paint_btn.name = "PaintBtn"
	paint_btn.text = "Paint"
	paint_btn.toggle_mode = true
	paint_btn.button_pressed = true
	paint_btn.button_group = tool_group
	paint_btn.pressed.connect(func(): _set_tool(0))
	tool_row1.add_child(paint_btn)
	
	var erase_btn := Button.new()
	erase_btn.name = "EraseBtn"
	erase_btn.text = "Erase"
	erase_btn.toggle_mode = true
	erase_btn.button_group = tool_group
	erase_btn.pressed.connect(func(): _set_tool(1))
	tool_row1.add_child(erase_btn)
	
	var select_btn := Button.new()
	select_btn.name = "SelectBtn"
	select_btn.text = "Select"
	select_btn.toggle_mode = true
	select_btn.button_group = tool_group
	select_btn.pressed.connect(func(): _set_tool(2))
	tool_row1.add_child(select_btn)
	content.add_child(tool_row1)
	
	var tool_row2 := HBoxContainer.new()
	var rect_btn := Button.new()
	rect_btn.name = "RectFillBtn"
	rect_btn.text = "Rect Fill"
	rect_btn.toggle_mode = true
	rect_btn.button_group = tool_group
	rect_btn.pressed.connect(func(): _set_tool(3))
	tool_row2.add_child(rect_btn)
	
	var bucket_btn := Button.new()
	bucket_btn.name = "BucketBtn"
	bucket_btn.text = "Bucket"
	bucket_btn.toggle_mode = true
	bucket_btn.button_group = tool_group
	bucket_btn.pressed.connect(func(): _set_tool(4))
	tool_row2.add_child(bucket_btn)
	content.add_child(tool_row2)
	
	# Undo/Redo buttons
	var undo_row := HBoxContainer.new()
	var undo_btn := Button.new()
	undo_btn.text = "Undo"
	undo_btn.pressed.connect(_undo)
	undo_row.add_child(undo_btn)
	var redo_btn := Button.new()
	redo_btn.text = "Redo"
	redo_btn.pressed.connect(_redo)
	undo_row.add_child(redo_btn)
	content.add_child(undo_row)
	
	# Y Level
	var y_container := HBoxContainer.new()
	y_container.add_child(_make_label("Y Level: "))
	_y_level_spinbox = SpinBox.new()
	_y_level_spinbox.name = "YLevel"
	_y_level_spinbox.min_value = 0
	_y_level_spinbox.max_value = 100
	_y_level_spinbox.value = 0
	_y_level_spinbox.value_changed.connect(_on_y_level_changed)
	_y_level_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	y_container.add_child(_y_level_spinbox)
	content.add_child(y_container)
	
	var y_hint := Label.new()
	y_hint.text = "(Mouse wheel to change)"
	y_hint.add_theme_font_size_override("font_size", 11)
	y_hint.add_theme_color_override("font_color", Color.GRAY)
	content.add_child(y_hint)
	
	# Brush Size
	var brush_container := HBoxContainer.new()
	brush_container.add_child(_make_label("Brush: "))
	_brush_size_spinbox = SpinBox.new()
	_brush_size_spinbox.name = "BrushSize"
	_brush_size_spinbox.min_value = 1
	_brush_size_spinbox.max_value = 10
	_brush_size_spinbox.value = 1
	_brush_size_spinbox.value_changed.connect(_on_brush_size_changed)
	_brush_size_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brush_container.add_child(_brush_size_spinbox)
	content.add_child(brush_container)
	
	content.add_child(HSeparator.new())
	
	# Selection Operations
	content.add_child(_make_label("Selection"))
	var selection_info := Label.new()
	selection_info.name = "SelectionInfo"
	selection_info.text = "No selection"
	selection_info.add_theme_color_override("font_color", Color.GRAY)
	content.add_child(selection_info)
	
	var selection_buttons1 := HBoxContainer.new()
	var save_chunk_btn := Button.new()
	save_chunk_btn.text = "Save Chunk"
	save_chunk_btn.pressed.connect(_on_save_chunk)
	selection_buttons1.add_child(save_chunk_btn)
	var load_chunk_btn := Button.new()
	load_chunk_btn.text = "Load Chunk"
	load_chunk_btn.pressed.connect(_on_load_chunk)
	selection_buttons1.add_child(load_chunk_btn)
	content.add_child(selection_buttons1)
	
	var selection_buttons2 := HBoxContainer.new()
	var fill_btn := Button.new()
	fill_btn.text = "Fill"
	fill_btn.pressed.connect(_on_fill_selection)
	selection_buttons2.add_child(fill_btn)
	var clear_sel_btn := Button.new()
	clear_sel_btn.text = "Clear"
	clear_sel_btn.pressed.connect(_on_clear_selection_tiles)
	selection_buttons2.add_child(clear_sel_btn)
	var deselect_btn := Button.new()
	deselect_btn.text = "Deselect"
	deselect_btn.pressed.connect(_clear_selection)
	selection_buttons2.add_child(deselect_btn)
	content.add_child(selection_buttons2)
	
	content.add_child(HSeparator.new())
	
	# Display
	_grid_visible_check = CheckBox.new()
	_grid_visible_check.name = "ShowGrid"
	_grid_visible_check.text = "Show 3D Grid"
	_grid_visible_check.button_pressed = true
	_grid_visible_check.toggled.connect(_on_grid_visible_toggled)
	content.add_child(_grid_visible_check)
	
	content.add_child(HSeparator.new())
	
	# Cell Size
	content.add_child(_make_label("Cell Size"))
	var cell_grid := GridContainer.new()
	cell_grid.columns = 4
	cell_grid.add_child(_make_label("X:"))
	var cell_x := SpinBox.new()
	cell_x.name = "CellSizeX"
	cell_x.min_value = 0.1
	cell_x.max_value = 100.0
	cell_x.step = 0.1
	cell_x.value = _grid_settings.cell_size_x
	cell_x.custom_minimum_size.x = 60
	cell_x.value_changed.connect(func(v): _grid_settings.cell_size_x = v; _save_settings(); _update_grid_lines())
	cell_grid.add_child(cell_x)
	cell_grid.add_child(_make_label("Y:"))
	var cell_y := SpinBox.new()
	cell_y.name = "CellSizeY"
	cell_y.min_value = 0.1
	cell_y.max_value = 100.0
	cell_y.step = 0.1
	cell_y.value = _grid_settings.cell_size_y
	cell_y.custom_minimum_size.x = 60
	cell_y.value_changed.connect(func(v): _grid_settings.cell_size_y = v; _save_settings(); _update_grid_lines())
	cell_grid.add_child(cell_y)
	cell_grid.add_child(_make_label("Z:"))
	var cell_z := SpinBox.new()
	cell_z.name = "CellSizeZ"
	cell_z.min_value = 0.1
	cell_z.max_value = 100.0
	cell_z.step = 0.1
	cell_z.value = _grid_settings.cell_size_z
	cell_z.custom_minimum_size.x = 60
	cell_z.value_changed.connect(func(v): _grid_settings.cell_size_z = v; _save_settings(); _update_grid_lines())
	cell_grid.add_child(cell_z)
	content.add_child(cell_grid)
	
	content.add_child(HSeparator.new())
	
	# Level Size
	content.add_child(_make_label("Level Size (cells)"))
	var size_grid := GridContainer.new()
	size_grid.columns = 4
	size_grid.add_child(_make_label("W:"))
	var size_x := SpinBox.new()
	size_x.name = "LevelSizeX"
	size_x.min_value = 1
	size_x.max_value = 500
	size_x.value = 64
	size_x.custom_minimum_size.x = 60
	size_x.value_changed.connect(_on_level_size_changed)
	size_grid.add_child(size_x)
	size_grid.add_child(_make_label("H:"))
	var size_y := SpinBox.new()
	size_y.name = "LevelSizeY"
	size_y.min_value = 1
	size_y.max_value = 500
	size_y.value = 32
	size_y.custom_minimum_size.x = 60
	size_y.value_changed.connect(_on_level_size_changed)
	size_grid.add_child(size_y)
	size_grid.add_child(_make_label("D:"))
	var size_z := SpinBox.new()
	size_z.name = "LevelSizeZ"
	size_z.min_value = 1
	size_z.max_value = 500
	size_z.value = 64
	size_z.custom_minimum_size.x = 60
	size_z.value_changed.connect(_on_level_size_changed)
	size_grid.add_child(size_z)
	content.add_child(size_grid)
	
	content.add_child(HSeparator.new())
	
	# Curved World
	content.add_child(_make_label("Curved World"))
	var curve_check := CheckBox.new()
	curve_check.name = "CurveEnabled"
	curve_check.text = "Enable Preview"
	curve_check.toggled.connect(_on_curve_toggled)
	content.add_child(curve_check)
	var intensity_hbox := HBoxContainer.new()
	intensity_hbox.add_child(_make_label("Curve:"))
	var intensity := HSlider.new()
	intensity.name = "CurveIntensity"
	intensity.min_value = 0.0
	intensity.max_value = 0.1
	intensity.step = 0.001
	intensity.value = 0.01
	intensity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intensity.value_changed.connect(_on_curve_intensity_changed)
	intensity_hbox.add_child(intensity)
	content.add_child(intensity_hbox)
	
	content.add_child(HSeparator.new())
	
	# Export
	content.add_child(_make_label("Export"))
	var export_curve := CheckBox.new()
	export_curve.name = "ExportWithCurve"
	export_curve.text = "Apply Curved Shader"
	export_curve.button_pressed = true
	content.add_child(export_curve)
	var export_btn := Button.new()
	export_btn.text = "Export Level"
	export_btn.pressed.connect(_on_export_level)
	content.add_child(export_btn)
	
	content.add_child(HSeparator.new())
	
	# Status
	var status := Label.new()
	status.name = "Status"
	status.text = "Check 'Enable Level Editing' to start"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color.GRAY)
	_main_dock.add_child(status)
	
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _main_dock)

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _update_tile_selector() -> void:
	if not _tile_selector:
		return
	_tile_selector.clear()
	if _current_palette:
		for i in range(_current_palette.tiles.size()):
			var tile := _current_palette.tiles[i]
			_tile_selector.add_item(tile.display_name, i)
			_tile_selector.set_item_metadata(i, tile.tile_id)
	if _tile_selector.item_count > 0:
		_tile_selector.select(0)
		_selected_tile_id = _tile_selector.get_item_metadata(0)

func _on_tile_selected(index: int) -> void:
	_selected_tile_id = _tile_selector.get_item_metadata(index)
	_set_status("Tile: %s" % _current_palette.tiles[index].display_name)

func _on_editing_toggled(enabled: bool) -> void:
	_editing_enabled = enabled
	if enabled:
		_set_status("Editing ON - Click 'New' or 'Load'")
		_auto_select_visualizer()
	else:
		_set_status("Editing OFF")

func _auto_select_visualizer() -> void:
	if _grid_visualizer and is_instance_valid(_grid_visualizer):
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(_grid_visualizer)

func _on_y_level_changed(value: float) -> void:
	_current_y_level = int(value)
	_update_grid_lines()
	_update_selection_visual()
	_set_status("Y Level: %d" % _current_y_level)

func _on_brush_size_changed(value: float) -> void:
	_brush_size = int(value)
	_set_status("Brush: %dx%d" % [_brush_size, _brush_size])

func _on_grid_visible_toggled(visible: bool) -> void:
	if _grid_lines_mesh:
		_grid_lines_mesh.visible = visible

func _save_settings() -> void:
	ResourceSaver.save(_grid_settings, SETTINGS_PATH)

func _set_status(text: String) -> void:
	if _main_dock:
		var status := _main_dock.find_child("Status", true, false) as Label
		if status:
			status.text = text
	print("[%s] %s" % [PLUGIN_NAME, text])

func _update_selection_info() -> void:
	if not _main_dock:
		return
	var info := _main_dock.find_child("SelectionInfo", true, false) as Label
	if not info:
		return
	
	if _has_selection:
		var min_pos := Vector3i(
			mini(_selection_start.x, _selection_end.x),
			mini(_selection_start.y, _selection_end.y),
			mini(_selection_start.z, _selection_end.z)
		)
		var max_pos := Vector3i(
			maxi(_selection_start.x, _selection_end.x),
			maxi(_selection_start.y, _selection_end.y),
			maxi(_selection_start.z, _selection_end.z)
		)
		var size := max_pos - min_pos + Vector3i.ONE
		info.text = "Selected: %dx%dx%d" % [size.x, size.y, size.z]
		info.add_theme_color_override("font_color", Color.YELLOW)
	else:
		info.text = "No selection"
		info.add_theme_color_override("font_color", Color.GRAY)

# ============ Selection and Preview Updates ============

func _clear_selection() -> void:
	_selection_start = Vector3i(-1, -1, -1)
	_selection_end = Vector3i(-1, -1, -1)
	_has_selection = false
	_awaiting_second_click = false
	_rect_dragging = false
	_select_dragging = false
	_rect_drag_start = Vector3i(-1, -1, -1)
	_update_selection_info()
	_update_selection_visual()
	_update_rect_preview(Vector3i(-1, -1, -1))
	_update_select_preview(Vector3i(-1, -1, -1))
	if _edit_mode == 2:
		_set_status("Tool: Select - Click and drag")

func _update_selection_visual() -> void:
	if not _selection_box_mesh or not _grid_settings:
		return
	if not _has_selection:
		_selection_box_mesh.visible = false
		return
	
	var cell := _grid_settings.get_cell_size()
	var min_pos := Vector3(
		mini(_selection_start.x, _selection_end.x),
		mini(_selection_start.y, _selection_end.y),
		mini(_selection_start.z, _selection_end.z)
	)
	var max_pos := Vector3(
		maxi(_selection_start.x, _selection_end.x) + 1,
		maxi(_selection_start.y, _selection_end.y) + 1,
		maxi(_selection_start.z, _selection_end.z) + 1
	)
	var world_min := min_pos * cell
	var world_max := max_pos * cell
	var center := (world_min + world_max) / 2.0
	var size := world_max - world_min
	
	var box := BoxMesh.new()
	box.size = size
	_selection_box_mesh.mesh = box
	_selection_box_mesh.position = center
	_selection_box_mesh.visible = true

func _update_brush_preview(center_pos: Vector3i) -> void:
	if not _brush_preview_mesh or not _grid_settings:
		return
	if _edit_mode != 0 and _edit_mode != 1:
		_brush_preview_mesh.visible = false
		return
	if center_pos.x < 0:
		_brush_preview_mesh.visible = false
		return
	
	var cell := _grid_settings.get_cell_size()
	var half := _brush_size / 2
	var min_x := center_pos.x - half
	var min_z := center_pos.z - half
	var max_x := min_x + _brush_size
	var max_z := min_z + _brush_size
	
	var world_min := Vector3(min_x * cell.x, _current_y_level * cell.y, min_z * cell.z)
	var world_max := Vector3(max_x * cell.x, (_current_y_level + 1) * cell.y, max_z * cell.z)
	var center := (world_min + world_max) / 2.0
	var size := world_max - world_min
	
	var box := BoxMesh.new()
	box.size = size
	_brush_preview_mesh.mesh = box
	_brush_preview_mesh.position = center
	_brush_preview_mesh.visible = true

func _update_rect_preview(current_pos: Vector3i) -> void:
	if not _rect_preview_mesh or not _grid_settings:
		return
	if not _rect_dragging or _rect_drag_start.x < 0 or current_pos.x < 0:
		_rect_preview_mesh.visible = false
		return
	
	var cell := _grid_settings.get_cell_size()
	var min_x := mini(_rect_drag_start.x, current_pos.x)
	var max_x := maxi(_rect_drag_start.x, current_pos.x) + 1
	var min_z := mini(_rect_drag_start.z, current_pos.z)
	var max_z := maxi(_rect_drag_start.z, current_pos.z) + 1
	
	var world_min := Vector3(min_x * cell.x, _current_y_level * cell.y, min_z * cell.z)
	var world_max := Vector3(max_x * cell.x, (_current_y_level + 1) * cell.y, max_z * cell.z)
	var center := (world_min + world_max) / 2.0
	var size := world_max - world_min
	
	var box := BoxMesh.new()
	box.size = size
	_rect_preview_mesh.mesh = box
	_rect_preview_mesh.position = center
	_rect_preview_mesh.visible = true

func _update_select_preview(current_pos: Vector3i) -> void:
	if not _select_preview_mesh or not _grid_settings:
		return
	if not _select_dragging or _selection_start.x < 0 or current_pos.x < 0:
		_select_preview_mesh.visible = false
		return
	
	var cell := _grid_settings.get_cell_size()
	var min_x := mini(_selection_start.x, current_pos.x)
	var max_x := maxi(_selection_start.x, current_pos.x) + 1
	var min_z := mini(_selection_start.z, current_pos.z)
	var max_z := maxi(_selection_start.z, current_pos.z) + 1
	
	var world_min := Vector3(min_x * cell.x, _current_y_level * cell.y, min_z * cell.z)
	var world_max := Vector3(max_x * cell.x, (_current_y_level + 1) * cell.y, max_z * cell.z)
	var center := (world_min + world_max) / 2.0
	var size := world_max - world_min
	
	var box := BoxMesh.new()
	box.size = size
	_select_preview_mesh.mesh = box
	_select_preview_mesh.position = center
	_select_preview_mesh.visible = true

# ============ Selection Operations ============

func _on_save_chunk() -> void:
	if not _has_selection or not _current_level:
		_set_status("Make a selection first!")
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Level Chunk")
	dialog.file_selected.connect(_save_chunk_file)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _save_chunk_file(path: String) -> void:
	var chunk := XtremeLevelChunk.create_from_region(_current_level, _selection_start, _selection_end)
	chunk.chunk_name = path.get_file().get_basename()
	var err := ResourceSaver.save(chunk, path)
	if err == OK:
		_set_status("Chunk saved: %s" % path.get_file())
	else:
		_set_status("Error saving chunk")

func _on_load_chunk() -> void:
	if not _current_level:
		_set_status("Create or load a level first!")
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Level Chunk")
	dialog.file_selected.connect(_load_chunk_file)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _load_chunk_file(path: String) -> void:
	var res := load(path)
	if not res is XtremeLevelChunk:
		_set_status("Error: Invalid chunk file")
		return
	var chunk := res as XtremeLevelChunk
	var place_pos := Vector3i(0, _current_y_level, 0)
	if _has_selection:
		place_pos = Vector3i(
			mini(_selection_start.x, _selection_end.x),
			mini(_selection_start.y, _selection_end.y),
			mini(_selection_start.z, _selection_end.z)
		)
	
	# Record for undo
	var affected: Array[Vector3i] = []
	for x in range(chunk.size.x):
		for y in range(chunk.size.y):
			for z in range(chunk.size.z):
				affected.append(place_pos + Vector3i(x, y, z))
	var before := _capture_tiles_in_region(affected)
	
	chunk.stamp_into(_current_level, place_pos, true)
	
	var after := _capture_tiles_in_region(affected)
	_record_undo("Load Chunk", before, after)
	
	if _grid_visualizer:
		_grid_visualizer.rebuild()
	_set_status("Chunk loaded at %s" % place_pos)

func _on_fill_selection() -> void:
	if not _has_selection or not _current_level:
		_set_status("Make a selection first!")
		return
	
	var min_pos := Vector3i(
		mini(_selection_start.x, _selection_end.x),
		mini(_selection_start.y, _selection_end.y),
		mini(_selection_start.z, _selection_end.z)
	)
	var max_pos := Vector3i(
		maxi(_selection_start.x, _selection_end.x),
		maxi(_selection_start.y, _selection_end.y),
		maxi(_selection_start.z, _selection_end.z)
	)
	
	# Capture before state
	var affected: Array[Vector3i] = []
	for x in range(min_pos.x, max_pos.x + 1):
		for y in range(min_pos.y, max_pos.y + 1):
			for z in range(min_pos.z, max_pos.z + 1):
				affected.append(Vector3i(x, y, z))
	var before := _capture_tiles_in_region(affected)
	
	var count := 0
	for pos in affected:
		_current_level.set_tile(pos, _selected_tile_id)
		count += 1
	
	var after := _capture_tiles_in_region(affected)
	_record_undo("Fill Selection", before, after)
	
	if _grid_visualizer:
		_grid_visualizer.rebuild()
	_set_status("Filled %d tiles" % count)

func _on_clear_selection_tiles() -> void:
	if not _has_selection or not _current_level:
		_set_status("Make a selection first!")
		return
	
	var min_pos := Vector3i(
		mini(_selection_start.x, _selection_end.x),
		mini(_selection_start.y, _selection_end.y),
		mini(_selection_start.z, _selection_end.z)
	)
	var max_pos := Vector3i(
		maxi(_selection_start.x, _selection_end.x),
		maxi(_selection_start.y, _selection_end.y),
		maxi(_selection_start.z, _selection_end.z)
	)
	
	var affected: Array[Vector3i] = []
	for x in range(min_pos.x, max_pos.x + 1):
		for y in range(min_pos.y, max_pos.y + 1):
			for z in range(min_pos.z, max_pos.z + 1):
				affected.append(Vector3i(x, y, z))
	var before := _capture_tiles_in_region(affected)
	
	var count := 0
	for pos in affected:
		_current_level.clear_tile(pos)
		count += 1
	
	var after := _capture_tiles_in_region(affected)
	_record_undo("Clear Selection", before, after)
	
	if _grid_visualizer:
		_grid_visualizer.rebuild()
	_set_status("Cleared %d tiles" % count)

# ============ Level Management ============

func _on_new_level() -> void:
	if not _editing_enabled:
		_set_status("Enable editing first!")
		return
	_current_level = XtremeLevelData.new()
	_current_level.initialize(_grid_settings)
	_current_level.level_name = "New Level"
	var size_x := _main_dock.find_child("LevelSizeX", true, false) as SpinBox
	var size_y := _main_dock.find_child("LevelSizeY", true, false) as SpinBox
	var size_z := _main_dock.find_child("LevelSizeZ", true, false) as SpinBox
	if size_x and size_y and size_z:
		_current_level.resize(int(size_x.value), int(size_y.value), int(size_z.value))
		_y_level_spinbox.max_value = size_y.value - 1
	
	# Clear undo history for new level
	_undo_history.clear()
	_redo_history.clear()
	
	_clear_selection()
	_create_or_update_visualizer()
	_auto_select_visualizer()
	_set_status("New level - Start painting!")

func _on_load_level() -> void:
	if not _editing_enabled:
		_set_status("Enable editing first!")
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Level Data")
	dialog.file_selected.connect(_load_level_file)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _load_level_file(path: String) -> void:
	var res := load(path)
	if res is XtremeLevelData:
		_current_level = res
		_current_level.initialize(_grid_settings)
		var size_x := _main_dock.find_child("LevelSizeX", true, false) as SpinBox
		var size_y := _main_dock.find_child("LevelSizeY", true, false) as SpinBox
		var size_z := _main_dock.find_child("LevelSizeZ", true, false) as SpinBox
		if size_x: size_x.value = _current_level.size_x
		if size_y: size_y.value = _current_level.size_y
		if size_z: size_z.value = _current_level.size_z
		_y_level_spinbox.max_value = _current_level.size_y - 1
		
		_undo_history.clear()
		_redo_history.clear()
		
		_clear_selection()
		_create_or_update_visualizer()
		_auto_select_visualizer()
		_set_status("Loaded: %s" % path.get_file())
	else:
		_set_status("Error: Invalid level file")

func _on_save_level() -> void:
	if not _current_level:
		_set_status("No level to save")
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Level Data")
	dialog.file_selected.connect(_save_level_file)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _save_level_file(path: String) -> void:
	var err := ResourceSaver.save(_current_level, path)
	if err == OK:
		_set_status("Saved: %s" % path.get_file())
	else:
		_set_status("Error saving")

func _on_export_level() -> void:
	if not _current_level:
		_set_status("No level to export")
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tscn", "Scene")
	dialog.file_selected.connect(_export_level_file)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _export_level_file(path: String) -> void:
	var exporter := XtremeLevelExporter.new()
	exporter.grid_settings = _grid_settings
	exporter.tile_palette = _current_palette
	exporter.level_data = _current_level
	var curve_check := _main_dock.find_child("ExportWithCurve", true, false) as CheckBox
	exporter.apply_curved_world = curve_check.button_pressed if curve_check else true
	var intensity := _main_dock.find_child("CurveIntensity", true, false) as HSlider
	exporter.curve_intensity = intensity.value if intensity else 0.01
	var err := exporter.export_level(path)
	if err == OK:
		_set_status("Exported: %s" % path.get_file())
	else:
		_set_status("Export error")

func _on_level_size_changed(_value: float) -> void:
	if not _current_level:
		return
	var size_x := _main_dock.find_child("LevelSizeX", true, false) as SpinBox
	var size_y := _main_dock.find_child("LevelSizeY", true, false) as SpinBox
	var size_z := _main_dock.find_child("LevelSizeZ", true, false) as SpinBox
	if size_x and size_y and size_z:
		_current_level.resize(int(size_x.value), int(size_y.value), int(size_z.value))
		_y_level_spinbox.max_value = size_y.value - 1
		if _grid_visualizer:
			_grid_visualizer.rebuild()
		_update_grid_lines()

func _on_curve_toggled(enabled: bool) -> void:
	if _grid_visualizer:
		_grid_visualizer.curved_preview_enabled = enabled
		_grid_visualizer.rebuild()

func _on_curve_intensity_changed(value: float) -> void:
	if _grid_visualizer:
		_grid_visualizer.curve_intensity = value
		# Live update - rebuild if curve is enabled
		var curve_check := _main_dock.find_child("CurveEnabled", true, false) as CheckBox
		if curve_check and curve_check.button_pressed:
			_grid_visualizer.rebuild()

# ============ Visualizer ============

func _create_or_update_visualizer() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		_set_status("Open a 3D scene first!")
		return
	_cleanup_visualizer()
	_grid_visualizer = XtremeGridVisualizer.new()
	_grid_visualizer.name = "XtremeGridVisualizer"
	_grid_visualizer.grid_settings = _grid_settings
	_grid_visualizer.level_data = _current_level
	_grid_visualizer.tile_palette = _current_palette
	scene_root.add_child(_grid_visualizer)
	_grid_visualizer.owner = scene_root
	_create_grid_lines(scene_root)
	_create_selection_box(scene_root)
	_create_brush_preview(scene_root)
	_create_rect_preview(scene_root)
	_create_select_preview(scene_root)

func _create_grid_lines(parent: Node) -> void:
	_grid_lines_mesh = MeshInstance3D.new()
	_grid_lines_mesh.name = "XtremeGridLines"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.6, 1.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grid_lines_mesh.material_override = mat
	parent.add_child(_grid_lines_mesh)
	_grid_lines_mesh.owner = parent
	_update_grid_lines()

func _create_selection_box(parent: Node) -> void:
	_selection_box_mesh = MeshInstance3D.new()
	_selection_box_mesh.name = "XtremeSelectionBox"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 0.0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_selection_box_mesh.material_override = mat
	_selection_box_mesh.visible = false
	parent.add_child(_selection_box_mesh)
	_selection_box_mesh.owner = parent

func _create_brush_preview(parent: Node) -> void:
	_brush_preview_mesh = MeshInstance3D.new()
	_brush_preview_mesh.name = "XtremeBrushPreview"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 1.0, 0.5, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_brush_preview_mesh.material_override = mat
	_brush_preview_mesh.visible = false
	parent.add_child(_brush_preview_mesh)
	_brush_preview_mesh.owner = parent

func _create_rect_preview(parent: Node) -> void:
	_rect_preview_mesh = MeshInstance3D.new()
	_rect_preview_mesh.name = "XtremeRectPreview"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.5, 0.3, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rect_preview_mesh.material_override = mat
	_rect_preview_mesh.visible = false
	parent.add_child(_rect_preview_mesh)
	_rect_preview_mesh.owner = parent

func _create_select_preview(parent: Node) -> void:
	_select_preview_mesh = MeshInstance3D.new()
	_select_preview_mesh.name = "XtremeSelectPreview"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.2, 0.35)  # Yellow-ish for select
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_select_preview_mesh.material_override = mat
	_select_preview_mesh.visible = false
	parent.add_child(_select_preview_mesh)
	_select_preview_mesh.owner = parent

func _update_grid_lines() -> void:
	if not _grid_lines_mesh or not _current_level or not _grid_settings:
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var cell := _grid_settings.get_cell_size()
	var y_pos := _current_y_level * cell.y
	var width := _current_level.size_x
	var depth := _current_level.size_z
	for z in range(depth + 1):
		var z_pos := z * cell.z
		im.surface_add_vertex(Vector3(0, y_pos, z_pos))
		im.surface_add_vertex(Vector3(width * cell.x, y_pos, z_pos))
	for x in range(width + 1):
		var x_pos := x * cell.x
		im.surface_add_vertex(Vector3(x_pos, y_pos, 0))
		im.surface_add_vertex(Vector3(x_pos, y_pos, depth * cell.z))
	im.surface_end()
	_grid_lines_mesh.mesh = im
	if _grid_visible_check:
		_grid_lines_mesh.visible = _grid_visible_check.button_pressed

# ============ 3D Input ============

func _handles(obj: Object) -> bool:
	return _editing_enabled and _current_level != null and _grid_visualizer != null

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not _editing_enabled or not _current_level or not _grid_settings:
		return AFTER_GUI_INPUT_PASS
	
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		
		# Scroll wheel - change Y level (completely block default zoom behavior)
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed:
				_change_y_level(1)
			return AFTER_GUI_INPUT_STOP
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_change_y_level(-1)
			return AFTER_GUI_INPUT_STOP
		
		# Right click - context menu
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_show_context_menu(mb.global_position)
			return AFTER_GUI_INPUT_STOP
		
		# Left click
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var from := camera.project_ray_origin(mb.position)
			var dir := camera.project_ray_normal(mb.position)
			var pos := _raycast_grid(from, dir)
			
			if mb.pressed:
				_is_dragging = true
				_last_drag_pos = Vector3i(-1, -1, -1)
				if pos.x >= 0:
					_handle_click_pressed(pos)
					return AFTER_GUI_INPUT_STOP
			else:  # Released
				_is_dragging = false
				if _rect_dragging:
					_handle_rect_release(pos)
					return AFTER_GUI_INPUT_STOP
				if _select_dragging:
					_handle_select_release(pos)
					return AFTER_GUI_INPUT_STOP
	
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var from := camera.project_ray_origin(mm.position)
		var dir := camera.project_ray_normal(mm.position)
		var pos := _raycast_grid(from, dir)
		
		if pos.x >= 0:
			if _grid_visualizer:
				_grid_visualizer.set_hover_position(pos)
			_update_brush_preview(pos)
			
			# Handle drag painting/erasing
			if _is_dragging and (_edit_mode == 0 or _edit_mode == 1):
				if pos != _last_drag_pos:
					_handle_drag_paint(pos)
					_last_drag_pos = pos
			
			# Update rect preview while dragging
			if _rect_dragging:
				_update_rect_preview(pos)
			
			# Update select preview while dragging
			if _select_dragging:
				_update_select_preview(pos)
	
	return AFTER_GUI_INPUT_PASS

func _show_context_menu(global_pos: Vector2) -> void:
	if _context_menu:
		_context_menu.position = Vector2i(global_pos)
		_context_menu.popup()

func _raycast_grid(origin: Vector3, direction: Vector3) -> Vector3i:
	if not _current_level or not _grid_settings:
		return Vector3i(-1, -1, -1)
	var cell_size := _grid_settings.get_cell_size()
	var plane_y := _current_y_level * cell_size.y
	if abs(direction.y) > 0.001:
		var t := (plane_y - origin.y) / direction.y
		if t > 0:
			var hit := origin + direction * t
			var grid_x := floori(hit.x / cell_size.x)
			var grid_z := floori(hit.z / cell_size.z)
			if grid_x >= 0 and grid_x < _current_level.size_x \
				and grid_z >= 0 and grid_z < _current_level.size_z:
				return Vector3i(grid_x, _current_y_level, grid_z)
	return Vector3i(-1, -1, -1)

func _handle_click_pressed(pos: Vector3i) -> void:
	match _edit_mode:
		0:  # Paint
			_start_paint_stroke(pos)
		1:  # Erase
			_start_erase_stroke(pos)
		2:  # Select - start drag
			_selection_start = pos
			_select_dragging = true
			_update_select_preview(pos)
			_set_status("Select: Drag to size...")
		3:  # Rect Fill - start drag
			_rect_drag_start = pos
			_rect_dragging = true
			_update_rect_preview(pos)
			_set_status("Rect Fill: Drag to size...")
		4:  # Bucket Fill
			_bucket_fill_at(pos)

# Paint/Erase with undo support for strokes
var _stroke_before: Dictionary = {}
var _stroke_affected: Array[Vector3i] = []

func _start_paint_stroke(pos: Vector3i) -> void:
	_stroke_before.clear()
	_stroke_affected.clear()
	_paint_at_single(pos)

func _start_erase_stroke(pos: Vector3i) -> void:
	_stroke_before.clear()
	_stroke_affected.clear()
	_erase_at_single(pos)

func _handle_drag_paint(pos: Vector3i) -> void:
	if _edit_mode == 0:
		_paint_at_single(pos)
	elif _edit_mode == 1:
		_erase_at_single(pos)

func _paint_at_single(center_pos: Vector3i) -> void:
	var half := _brush_size / 2
	for dx in range(_brush_size):
		for dz in range(_brush_size):
			var pos := Vector3i(
				center_pos.x - half + dx,
				center_pos.y,
				center_pos.z - half + dz
			)
			if pos.x < 0 or pos.x >= _current_level.size_x:
				continue
			if pos.z < 0 or pos.z >= _current_level.size_z:
				continue
			
			# Record before state if not already recorded
			if pos not in _stroke_before:
				if _current_level.has_tile(pos):
					_stroke_before[pos] = _current_level.get_tile(pos)
				_stroke_affected.append(pos)
			
			_current_level.set_tile(pos, _selected_tile_id)
			_grid_visualizer.update_tile(pos)

func _erase_at_single(center_pos: Vector3i) -> void:
	var half := _brush_size / 2
	for dx in range(_brush_size):
		for dz in range(_brush_size):
			var pos := Vector3i(
				center_pos.x - half + dx,
				center_pos.y,
				center_pos.z - half + dz
			)
			if pos.x < 0 or pos.x >= _current_level.size_x:
				continue
			if pos.z < 0 or pos.z >= _current_level.size_z:
				continue
			
			if pos not in _stroke_before:
				if _current_level.has_tile(pos):
					_stroke_before[pos] = _current_level.get_tile(pos)
				_stroke_affected.append(pos)
			
			_current_level.clear_tile(pos)
			_grid_visualizer.update_tile(pos)

func _finalize_stroke(action_name: String) -> void:
	if _stroke_affected.size() > 0:
		var after := _capture_tiles_in_region(_stroke_affected)
		_record_undo(action_name, _stroke_before.duplicate(), after)
	_stroke_before.clear()
	_stroke_affected.clear()

func _handle_rect_release(pos: Vector3i) -> void:
	_rect_dragging = false
	_rect_preview_mesh.visible = false
	
	if pos.x < 0:
		pos = _rect_drag_start
	
	var min_x := mini(_rect_drag_start.x, pos.x)
	var max_x := maxi(_rect_drag_start.x, pos.x)
	var min_z := mini(_rect_drag_start.z, pos.z)
	var max_z := maxi(_rect_drag_start.z, pos.z)
	
	var affected: Array[Vector3i] = []
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			affected.append(Vector3i(x, _current_y_level, z))
	var before := _capture_tiles_in_region(affected)
	
	var count := 0
	for tile_pos in affected:
		_current_level.set_tile(tile_pos, _selected_tile_id)
		_grid_visualizer.update_tile(tile_pos)
		count += 1
	
	var after := _capture_tiles_in_region(affected)
	_record_undo("Rect Fill", before, after)
	
	_set_status("Rect filled %d tiles" % count)

func _handle_select_release(pos: Vector3i) -> void:
	_select_dragging = false
	_select_preview_mesh.visible = false
	
	if pos.x < 0:
		pos = _selection_start
	
	_selection_end = pos
	_has_selection = true
	_update_selection_info()
	_update_selection_visual()
	
	var size := Vector3i(
		absi(_selection_end.x - _selection_start.x) + 1,
		1,
		absi(_selection_end.z - _selection_start.z) + 1
	)
	_set_status("Selected: %dx%dx%d" % [size.x, size.y, size.z])

func _bucket_fill_at(start_pos: Vector3i) -> void:
	if _current_level.has_tile(start_pos):
		_set_status("Bucket Fill: Click on empty cell")
		return
	
	var affected: Array[Vector3i] = []
	var to_fill: Array[Vector3i] = [start_pos]
	var visited := {}
	visited[start_pos] = true
	
	while to_fill.size() > 0 and affected.size() < 10000:
		var pos: Vector3i = to_fill.pop_front()
		if pos.x < 0 or pos.x >= _current_level.size_x:
			continue
		if pos.z < 0 or pos.z >= _current_level.size_z:
			continue
		if _current_level.has_tile(pos):
			continue
		
		affected.append(pos)
		
		var neighbors := [
			Vector3i(pos.x + 1, pos.y, pos.z),
			Vector3i(pos.x - 1, pos.y, pos.z),
			Vector3i(pos.x, pos.y, pos.z + 1),
			Vector3i(pos.x, pos.y, pos.z - 1),
		]
		for neighbor in neighbors:
			if neighbor not in visited:
				visited[neighbor] = true
				to_fill.append(neighbor)
	
	var before := _capture_tiles_in_region(affected)
	
	for pos in affected:
		_current_level.set_tile(pos, _selected_tile_id)
		_grid_visualizer.update_tile(pos)
	
	var after := _capture_tiles_in_region(affected)
	_record_undo("Bucket Fill", before, after)
	
	_set_status("Bucket filled %d tiles" % affected.size())

# Need to finalize stroke when mouse is released
func _input(event: InputEvent) -> void:
	if not _editing_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			# Mouse released - finalize any paint/erase stroke
			if _edit_mode == 0 and _stroke_affected.size() > 0:
				_finalize_stroke("Paint")
			elif _edit_mode == 1 and _stroke_affected.size() > 0:
				_finalize_stroke("Erase")
