@tool
extends EditorPlugin

## Xtreme Level Editor - Main Plugin
## A 3D cubemap/tilemap level editor inspired by Sonic Xtreme

const PLUGIN_NAME := "Xtreme Level Editor"
const SETTINGS_PATH := "res://xtreme_level_editor_settings.tres"
const MAX_UNDO_HISTORY := 10

# Colors for brush preview
const BRUSH_COLOR_VALID := Color(0.0, 1.0, 0.5, 0.35)  # Green - can place
const BRUSH_COLOR_BLOCKED := Color(1.0, 0.2, 0.2, 0.45)  # Red - blocked

# UI Elements
var _main_dock: Control
var _tile_selector: OptionButton
var _y_level_spinbox: SpinBox
var _brush_size_spinbox: SpinBox
var _grid_visible_check: CheckBox
var _context_menu: PopupMenu
var _rotation_x_spinbox: SpinBox
var _rotation_y_spinbox: SpinBox
var _rotation_z_spinbox: SpinBox

# Scene elements
var _grid_visualizer: XtremeGridVisualizer
var _grid_lines_mesh: MeshInstance3D
var _selection_box_mesh: MeshInstance3D
var _brush_preview_mesh: MeshInstance3D
var _brush_preview_material: StandardMaterial3D
var _rect_preview_mesh: MeshInstance3D
var _select_preview_mesh: MeshInstance3D

# State
var _current_level: XtremeLevelData
var _current_palette: XtremeTilePalette
var _grid_settings: XtremeGridSettings
var _selected_tile_id: StringName = &"solid"
var _edit_mode: int = 0  # 0=paint, 1=erase, 2=select, 3=rect_fill, 4=bucket_fill, 5=water_zone
var _current_y_level: int = 0
var _brush_size: int = 1
var _is_plugin_active: bool = false
var _editing_enabled: bool = false

# Rotation state (in 90-degree increments: 0, 1, 2, 3)
var _current_rotation: Vector3i = Vector3i.ZERO

# Grid orientation: 0=XZ (horizontal), 1=XY (vertical front), 2=YZ (vertical side)
var _grid_orientation: int = 0
const GRID_XZ := 0  # Horizontal floor/ceiling (default)
const GRID_XY := 1  # Vertical wall facing Z
const GRID_YZ := 2  # Vertical wall facing X

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

# ============ Phase 3: Level Systems ============

# Level manifest for multi-chunk-set levels
var _current_manifest: XtremeLevelManifest
var _current_chunk_set: XtremeChunkSetData

# Water zone editing state
var _water_zone_start: Vector3i = Vector3i(-1, -1, -1)
var _water_zone_dragging: bool = false
var _water_zone_preview: MeshInstance3D

# Pipe/portal editing
var _editing_pipe: XtremePipeConnection
var _pipe_edit_popup: Window

# Level Overview panel
var _level_overview_window: Window
var _level_overview_graph: Control

# Ghost chunk sets (semi-transparent neighboring chunk sets)
var _ghost_enabled: bool = false
var _ghost_visualizers: Array[Node3D] = []

# Chunk set dropdown
var _chunk_set_selector: OptionButton

# ============ Phase 4: Path Systems ============

# Path editing mode: 0=Rail, 1=Coaster, 2=Light Dash
var _path_edit_mode: int = 0

# Path tool mode: 0=Place, 1=Select, 2=Edit, 3=Delete
var _path_tool_mode: int = 0

# Currently editing path
var _current_rail: XtremeGrindRail
var _current_coaster: XtremeRollerCoaster
var _current_dash_trail: XtremeLightDashTrail

# All paths in current chunk set
var _rails: Array[XtremeGrindRail] = []
var _coasters: Array[XtremeRollerCoaster] = []
var _dash_trails: Array[XtremeLightDashTrail] = []

# Selected path for editing
var _selected_path_index: int = -1

# Path preview meshes
var _path_preview_mesh: MeshInstance3D
var _path_points_mesh: MeshInstance3D

# Is path currently being drawn
var _path_drawing: bool = false

func _get_plugin_name() -> String:
	return PLUGIN_NAME

func _enter_tree() -> void:
	_load_or_create_settings()
	_create_default_palette()
	_register_custom_types()
	_create_editor_dock()
	_create_context_menu()
	_is_plugin_active = true
	
	# Connect to scene change signal to handle persistence
	EditorInterface.get_editor_main_screen().get_parent().child_entered_tree.connect(_on_scene_changed)
	
	# Try to recover existing visualizer if present
	call_deferred("_try_recover_existing_visualizer")
	
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

func _on_scene_changed(_node: Node) -> void:
	# When scene changes, clean up any old temp nodes and reset state
	call_deferred("_on_scene_loaded")

func _on_scene_loaded() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return
	
	# Clean up any leftover TEMP nodes from previous session
	_cleanup_leftover_temp_nodes(scene_root)
	
	# Reset our references since temp nodes don't persist
	_grid_visualizer = null
	_grid_lines_mesh = null
	_selection_box_mesh = null
	_brush_preview_mesh = null
	_rect_preview_mesh = null
	_select_preview_mesh = null
	
	# Check if there's saved level data we should offer to load
	# (This would be a .tres file, not embedded nodes)
	_set_status("Scene loaded - Enable editing and click New/Load")

func _cleanup_leftover_temp_nodes(root: Node) -> void:
	# Remove any TEMP nodes that might have been left behind
	var nodes_to_remove: Array[Node] = []
	_find_temp_nodes(root, nodes_to_remove)
	for node in nodes_to_remove:
		node.queue_free()

func _find_temp_nodes(node: Node, result: Array[Node]) -> void:
	if node.name.ends_with("_TEMP"):
		result.append(node)
	for child in node.get_children():
		_find_temp_nodes(child, result)

func _try_recover_existing_visualizer() -> void:
	# This is now mainly for cleanup - temp nodes shouldn't persist
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return
	
	# Clean up any old saved nodes (from before this fix)
	_cleanup_old_saved_nodes(scene_root)

func _cleanup_old_saved_nodes(root: Node) -> void:
	# Remove old-style saved nodes (without _TEMP suffix) that cause conflicts
	var old_names := ["XtremeGridVisualizer", "XtremeGridLines", "XtremeSelectionBox", 
					  "XtremeBrushPreview", "XtremeRectPreview", "XtremeSelectPreview"]
	for old_name in old_names:
		var old_node := root.find_child(old_name, true, false)
		if old_node:
			print("[%s] Removing old saved node: %s" % [PLUGIN_NAME, old_name])
			old_node.queue_free()

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
	# Use the full default palette from default_tiles.gd
	var DefaultTiles := preload("res://addons/xtreme_level_editor/scripts/default_tiles.gd")
	_current_palette = DefaultTiles.create_default_palette()

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
	_context_menu.add_separator()
	
	# Grid orientation
	_context_menu.add_item("Grid: XZ (Floor) [1]", 40)
	_context_menu.add_item("Grid: XY (Front) [2]", 41)
	_context_menu.add_item("Grid: YZ (Side) [3]", 42)
	
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
		40: _set_grid_orientation(GRID_XZ)
		41: _set_grid_orientation(GRID_XY)
		42: _set_grid_orientation(GRID_YZ)

func _set_tool(tool_id: int) -> void:
	_edit_mode = tool_id
	_clear_selection()
	var tool_names := ["Paint", "Erase", "Select", "Rect Fill", "Bucket Fill", "Water Zone"]
	if tool_id < tool_names.size():
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
	var water_btn := _main_dock.find_child("WaterZoneBtn", true, false) as Button
	
	if paint_btn: paint_btn.button_pressed = (_edit_mode == 0)
	if erase_btn: erase_btn.button_pressed = (_edit_mode == 1)
	if select_btn: select_btn.button_pressed = (_edit_mode == 2)
	if rect_btn: rect_btn.button_pressed = (_edit_mode == 3)
	if bucket_btn: bucket_btn.button_pressed = (_edit_mode == 4)
	if water_btn: water_btn.button_pressed = (_edit_mode == 5)

func _change_y_level(delta: int) -> void:
	if not _current_level:
		return
	
	# Determine max based on grid orientation
	var max_level: int
	match _grid_orientation:
		GRID_XZ: max_level = _current_level.size_y - 1
		GRID_XY: max_level = _current_level.size_z - 1
		GRID_YZ: max_level = _current_level.size_x - 1
		_: max_level = _current_level.size_y - 1
	
	var new_level := clampi(_current_y_level + delta, 0, max_level)
	if new_level != _current_y_level:
		_current_y_level = new_level
		if _y_level_spinbox:
			_y_level_spinbox.value = _current_y_level
		_update_grid_lines()
		_update_selection_visual()
		
		# Status message based on orientation
		var axis_name: String
		match _grid_orientation:
			GRID_XZ: axis_name = "Y"
			GRID_XY: axis_name = "Z"
			GRID_YZ: axis_name = "X"
		_set_status("%s Level: %d" % [axis_name, _current_y_level])

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
	
	# Editing Toggle (outside tabs - always visible)
	var edit_toggle := CheckBox.new()
	edit_toggle.name = "EditingEnabled"
	edit_toggle.text = "Enable Level Editing"
	edit_toggle.toggled.connect(_on_editing_toggled)
	_main_dock.add_child(edit_toggle)
	
	_main_dock.add_child(HSeparator.new())
	
	# Tab Container for Level Tools and Rail Tools
	var tab_container := TabContainer.new()
	tab_container.name = "ToolTabs"
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_dock.add_child(tab_container)
	
	# Create Level Tools tab
	var level_tools := _create_level_tools_tab()
	level_tools.name = "Level Tools"
	tab_container.add_child(level_tools)
	
	# Create Rail Tools tab
	var rail_tools := _create_rail_tools_tab()
	rail_tools.name = "Rail Tools"
	tab_container.add_child(rail_tools)
	
	# Status label (outside tabs - always visible)
	var status := Label.new()
	status.name = "Status"
	status.text = "Check 'Enable Level Editing' to start"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color.GRAY)
	_main_dock.add_child(status)
	
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _main_dock)

func _create_level_tools_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	
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
	
	# ============ CHUNK SET MANAGEMENT (Phase 3) ============
	content.add_child(_make_label("Chunk Set"))
	
	var chunk_row := HBoxContainer.new()
	_chunk_set_selector = OptionButton.new()
	_chunk_set_selector.name = "ChunkSetSelector"
	_chunk_set_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chunk_set_selector.item_selected.connect(_on_chunk_set_selected)
	chunk_row.add_child(_chunk_set_selector)
	
	var add_chunk_btn := Button.new()
	add_chunk_btn.text = "+"
	add_chunk_btn.tooltip_text = "Add new Chunk Set"
	add_chunk_btn.custom_minimum_size.x = 30
	add_chunk_btn.pressed.connect(_on_add_chunk_set)
	chunk_row.add_child(add_chunk_btn)
	content.add_child(chunk_row)
	
	var chunk_buttons := HBoxContainer.new()
	var overview_btn := Button.new()
	overview_btn.name = "LevelOverviewBtn"
	overview_btn.text = "Level Overview"
	overview_btn.pressed.connect(_show_level_overview)
	overview_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chunk_buttons.add_child(overview_btn)
	
	var ghost_toggle := CheckBox.new()
	ghost_toggle.name = "GhostToggle"
	ghost_toggle.text = "Ghosts"
	ghost_toggle.tooltip_text = "Show neighboring chunk sets as ghosts"
	ghost_toggle.toggled.connect(_on_ghost_toggled)
	chunk_buttons.add_child(ghost_toggle)
	content.add_child(chunk_buttons)
	
	content.add_child(HSeparator.new())
	
	# ============ TILE PALETTE ============
	var palette_header := Label.new()
	palette_header.text = "TILE PALETTE"
	palette_header.add_theme_font_size_override("font_size", 14)
	palette_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(palette_header)
	
	# Category filter dropdown
	var category_row := HBoxContainer.new()
	var cat_label := Label.new()
	cat_label.text = "Category:"
	cat_label.custom_minimum_size.x = 70
	category_row.add_child(cat_label)
	
	var category_filter := OptionButton.new()
	category_filter.name = "CategoryFilter"
	category_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_filter.item_selected.connect(_on_category_filter_changed)
	category_row.add_child(category_filter)
	content.add_child(category_row)
	
	# Tile icon grid (scrollable)
	var tile_scroll := ScrollContainer.new()
	tile_scroll.name = "TilePaletteScroll"
	tile_scroll.custom_minimum_size = Vector2(0, 180)
	tile_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var tile_grid := GridContainer.new()
	tile_grid.name = "TilePaletteGrid"
	tile_grid.columns = 4
	tile_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_grid.add_theme_constant_override("h_separation", 4)
	tile_grid.add_theme_constant_override("v_separation", 4)
	tile_scroll.add_child(tile_grid)
	content.add_child(tile_scroll)
	
	# Selected tile info panel
	var info_panel := PanelContainer.new()
	info_panel.name = "SelectedTilePanel"
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.15, 0.15, 0.15)
	info_style.set_border_width_all(1)
	info_style.border_color = Color(0.3, 0.3, 0.3)
	info_style.set_corner_radius_all(4)
	info_style.set_content_margin_all(8)
	info_panel.add_theme_stylebox_override("panel", info_style)
	
	var selected_tile_info := VBoxContainer.new()
	selected_tile_info.name = "SelectedTileInfo"
	
	var selected_label := Label.new()
	selected_label.name = "SelectedTileName"
	selected_label.text = "Selected: None"
	selected_label.add_theme_font_size_override("font_size", 13)
	selected_tile_info.add_child(selected_label)
	
	var info_row := HBoxContainer.new()
	var selected_category := Label.new()
	selected_category.name = "SelectedTileCategory"
	selected_category.text = "Category: -"
	selected_category.add_theme_font_size_override("font_size", 11)
	selected_category.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_row.add_child(selected_category)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(spacer)
	
	var selected_size := Label.new()
	selected_size.name = "SelectedTileSize"
	selected_size.text = "Size: -"
	selected_size.add_theme_font_size_override("font_size", 11)
	selected_size.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_row.add_child(selected_size)
	
	selected_tile_info.add_child(info_row)
	info_panel.add_child(selected_tile_info)
	content.add_child(info_panel)
	
	# Hidden legacy dropdown for compatibility
	_tile_selector = OptionButton.new()
	_tile_selector.name = "TileSelector"
	_tile_selector.visible = false
	_tile_selector.item_selected.connect(_on_tile_selected)
	content.add_child(_tile_selector)
	
	# Initialize the tile palette (populates categories and grid)
	call_deferred("_initialize_tile_palette")
	
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
	
	var water_btn := Button.new()
	water_btn.name = "WaterZoneBtn"
	water_btn.text = "Water"
	water_btn.toggle_mode = true
	water_btn.button_group = tool_group
	water_btn.pressed.connect(func(): _set_tool(5))
	water_btn.tooltip_text = "Draw water zone volumes"
	tool_row2.add_child(water_btn)
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
	
	content.add_child(HSeparator.new())
	
	# Grid Orientation
	content.add_child(_make_label("Grid Orientation (1, 2, 3)"))
	var grid_orient_row := HBoxContainer.new()
	var grid_orient_group := ButtonGroup.new()
	
	var xz_btn := Button.new()
	xz_btn.name = "GridXZ"
	xz_btn.text = "XZ (Floor)"
	xz_btn.toggle_mode = true
	xz_btn.button_pressed = true
	xz_btn.button_group = grid_orient_group
	xz_btn.pressed.connect(func(): _set_grid_orientation(GRID_XZ))
	xz_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_orient_row.add_child(xz_btn)
	
	var xy_btn := Button.new()
	xy_btn.name = "GridXY"
	xy_btn.text = "XY (Front)"
	xy_btn.toggle_mode = true
	xy_btn.button_group = grid_orient_group
	xy_btn.pressed.connect(func(): _set_grid_orientation(GRID_XY))
	xy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_orient_row.add_child(xy_btn)
	
	var yz_btn := Button.new()
	yz_btn.name = "GridYZ"
	yz_btn.text = "YZ (Side)"
	yz_btn.toggle_mode = true
	yz_btn.button_group = grid_orient_group
	yz_btn.pressed.connect(func(): _set_grid_orientation(GRID_YZ))
	yz_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_orient_row.add_child(yz_btn)
	
	content.add_child(grid_orient_row)
	
	# Layer control (changes based on grid orientation)
	var layer_container := HBoxContainer.new()
	var layer_label := Label.new()
	layer_label.name = "LayerLabel"
	layer_label.text = "Y Level: "
	layer_container.add_child(layer_label)
	_y_level_spinbox = SpinBox.new()
	_y_level_spinbox.name = "YLevel"
	_y_level_spinbox.min_value = 0
	_y_level_spinbox.max_value = 100
	_y_level_spinbox.value = 0
	_y_level_spinbox.value_changed.connect(_on_y_level_changed)
	_y_level_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_container.add_child(_y_level_spinbox)
	content.add_child(layer_container)
	
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
	
	# Rotation Controls
	content.add_child(_make_label("Rotation (90° increments)"))
	var rotation_grid := GridContainer.new()
	rotation_grid.columns = 6
	
	rotation_grid.add_child(_make_label("X:"))
	_rotation_x_spinbox = SpinBox.new()
	_rotation_x_spinbox.name = "RotationX"
	_rotation_x_spinbox.min_value = 0
	_rotation_x_spinbox.max_value = 3
	_rotation_x_spinbox.value = 0
	_rotation_x_spinbox.custom_minimum_size.x = 50
	_rotation_x_spinbox.value_changed.connect(_on_rotation_x_changed)
	rotation_grid.add_child(_rotation_x_spinbox)
	
	rotation_grid.add_child(_make_label("Y:"))
	_rotation_y_spinbox = SpinBox.new()
	_rotation_y_spinbox.name = "RotationY"
	_rotation_y_spinbox.min_value = 0
	_rotation_y_spinbox.max_value = 3
	_rotation_y_spinbox.value = 0
	_rotation_y_spinbox.custom_minimum_size.x = 50
	_rotation_y_spinbox.value_changed.connect(_on_rotation_y_changed)
	rotation_grid.add_child(_rotation_y_spinbox)
	
	rotation_grid.add_child(_make_label("Z:"))
	_rotation_z_spinbox = SpinBox.new()
	_rotation_z_spinbox.name = "RotationZ"
	_rotation_z_spinbox.min_value = 0
	_rotation_z_spinbox.max_value = 3
	_rotation_z_spinbox.value = 0
	_rotation_z_spinbox.custom_minimum_size.x = 50
	_rotation_z_spinbox.value_changed.connect(_on_rotation_z_changed)
	rotation_grid.add_child(_rotation_z_spinbox)
	
	content.add_child(rotation_grid)
	
	var rotation_hint := Label.new()
	rotation_hint.text = "(R=Y, Shift+R=X, Ctrl+R=Z)"
	rotation_hint.add_theme_font_size_override("font_size", 11)
	rotation_hint.add_theme_color_override("font_color", Color.GRAY)
	content.add_child(rotation_hint)
	
	var reset_rotation_btn := Button.new()
	reset_rotation_btn.text = "Reset Rotation"
	reset_rotation_btn.pressed.connect(_reset_rotation)
	content.add_child(reset_rotation_btn)
	
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
	
	# Distance Effects
	content.add_child(_make_label("Distance Effects"))
	var dist_effects_check := CheckBox.new()
	dist_effects_check.name = "DistanceEffectsEnabled"
	dist_effects_check.text = "Enable Wireframe + Dissolve"
	dist_effects_check.button_pressed = true
	dist_effects_check.toggled.connect(_on_distance_effects_toggled)
	content.add_child(dist_effects_check)
	
	# Effect max distance
	var dist_hbox := HBoxContainer.new()
	dist_hbox.add_child(_make_label("Max Dist:"))
	var dist_slider := HSlider.new()
	dist_slider.name = "EffectMaxDistance"
	dist_slider.min_value = 20.0
	dist_slider.max_value = 300.0
	dist_slider.step = 5.0
	dist_slider.value = 150.0
	dist_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dist_slider.value_changed.connect(_on_effect_distance_changed)
	dist_hbox.add_child(dist_slider)
	content.add_child(dist_hbox)
	
	# Wireframe start
	var wire_hbox := HBoxContainer.new()
	wire_hbox.add_child(_make_label("Wire Start:"))
	var wire_slider := HSlider.new()
	wire_slider.name = "WireframeStart"
	wire_slider.min_value = 0.0
	wire_slider.max_value = 1.0
	wire_slider.step = 0.05
	wire_slider.value = 0.3
	wire_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wire_slider.value_changed.connect(_on_wireframe_start_changed)
	wire_hbox.add_child(wire_slider)
	content.add_child(wire_hbox)
	
	# Dissolve start
	var dissolve_hbox := HBoxContainer.new()
	dissolve_hbox.add_child(_make_label("Dissolve:"))
	var dissolve_slider := HSlider.new()
	dissolve_slider.name = "DissolveStart"
	dissolve_slider.min_value = 0.0
	dissolve_slider.max_value = 1.0
	dissolve_slider.step = 0.05
	dissolve_slider.value = 0.3
	dissolve_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dissolve_slider.value_changed.connect(_on_dissolve_start_changed)
	dissolve_hbox.add_child(dissolve_slider)
	content.add_child(dissolve_hbox)
	
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
	
	return scroll

func _create_rail_tools_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	
	# Rail Tools Header
	content.add_child(_make_label("Path Tools"))
	content.add_child(HSeparator.new())
	
	# Path Type Selection
	content.add_child(_make_label("Path Type"))
	var path_type_group := ButtonGroup.new()
	var path_type_row := HBoxContainer.new()
	
	var rail_btn := Button.new()
	rail_btn.name = "RailTypeBtn"
	rail_btn.text = "Rail"
	rail_btn.toggle_mode = true
	rail_btn.button_pressed = true
	rail_btn.button_group = path_type_group
	rail_btn.pressed.connect(func(): _set_path_edit_mode(0))
	rail_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_type_row.add_child(rail_btn)
	
	var coaster_btn := Button.new()
	coaster_btn.name = "CoasterTypeBtn"
	coaster_btn.text = "Coaster"
	coaster_btn.toggle_mode = true
	coaster_btn.button_group = path_type_group
	coaster_btn.pressed.connect(func(): _set_path_edit_mode(1))
	coaster_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_type_row.add_child(coaster_btn)
	
	var dash_btn := Button.new()
	dash_btn.name = "DashTypeBtn"
	dash_btn.text = "Dash"
	dash_btn.toggle_mode = true
	dash_btn.button_group = path_type_group
	dash_btn.pressed.connect(func(): _set_path_edit_mode(2))
	dash_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_type_row.add_child(dash_btn)
	content.add_child(path_type_row)
	
	content.add_child(HSeparator.new())
	
	# Rail Tools
	content.add_child(_make_label("Edit Mode"))
	var rail_tool_group := ButtonGroup.new()
	var rail_tool_row := HBoxContainer.new()
	
	var place_btn := Button.new()
	place_btn.name = "PathPlaceBtn"
	place_btn.text = "Place"
	place_btn.toggle_mode = true
	place_btn.button_pressed = true
	place_btn.button_group = rail_tool_group
	place_btn.pressed.connect(func(): _set_path_tool(0))
	place_btn.tooltip_text = "Click to place path points"
	rail_tool_row.add_child(place_btn)
	
	var select_path_btn := Button.new()
	select_path_btn.name = "PathSelectBtn"
	select_path_btn.text = "Select"
	select_path_btn.toggle_mode = true
	select_path_btn.button_group = rail_tool_group
	select_path_btn.pressed.connect(func(): _set_path_tool(1))
	select_path_btn.tooltip_text = "Click to select existing paths"
	rail_tool_row.add_child(select_path_btn)
	
	var edit_path_btn := Button.new()
	edit_path_btn.name = "PathEditBtn"
	edit_path_btn.text = "Edit"
	edit_path_btn.toggle_mode = true
	edit_path_btn.button_group = rail_tool_group
	edit_path_btn.pressed.connect(func(): _set_path_tool(2))
	edit_path_btn.tooltip_text = "Move path control points"
	rail_tool_row.add_child(edit_path_btn)
	
	var delete_path_btn := Button.new()
	delete_path_btn.name = "PathDeleteBtn"
	delete_path_btn.text = "Delete"
	delete_path_btn.toggle_mode = true
	delete_path_btn.button_group = rail_tool_group
	delete_path_btn.pressed.connect(func(): _set_path_tool(3))
	delete_path_btn.tooltip_text = "Click to delete paths"
	rail_tool_row.add_child(delete_path_btn)
	content.add_child(rail_tool_row)
	
	content.add_child(HSeparator.new())
	
	# Path Actions
	content.add_child(_make_label("Actions"))
	var action_row1 := HBoxContainer.new()
	
	var new_path_btn := Button.new()
	new_path_btn.name = "NewPathBtn"
	new_path_btn.text = "New Path"
	new_path_btn.pressed.connect(_on_new_path)
	new_path_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row1.add_child(new_path_btn)
	
	var finish_path_btn := Button.new()
	finish_path_btn.name = "FinishPathBtn"
	finish_path_btn.text = "Finish Path"
	finish_path_btn.pressed.connect(_on_finish_path)
	finish_path_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row1.add_child(finish_path_btn)
	content.add_child(action_row1)
	
	var action_row2 := HBoxContainer.new()
	
	var close_loop_btn := Button.new()
	close_loop_btn.name = "CloseLoopBtn"
	close_loop_btn.text = "Close Loop"
	close_loop_btn.pressed.connect(_on_close_path_loop)
	close_loop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row2.add_child(close_loop_btn)
	
	var auto_fill_btn := Button.new()
	auto_fill_btn.name = "AutoFillBtn"
	auto_fill_btn.text = "Auto-Fill"
	auto_fill_btn.pressed.connect(_on_auto_fill_path)
	auto_fill_btn.tooltip_text = "Fill gaps in light dash trails"
	auto_fill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row2.add_child(auto_fill_btn)
	content.add_child(action_row2)
	
	content.add_child(HSeparator.new())
	
	# Grind Rail Properties (visible when Rail selected)
	var rail_props := VBoxContainer.new()
	rail_props.name = "RailProperties"
	
	rail_props.add_child(_make_label("Rail Properties"))
	
	var speed_row := HBoxContainer.new()
	var speed_label := Label.new()
	speed_label.text = "Speed:"
	speed_label.custom_minimum_size.x = 60
	speed_row.add_child(speed_label)
	var speed_spin := SpinBox.new()
	speed_spin.name = "RailSpeedSpin"
	speed_spin.min_value = 0.1
	speed_spin.max_value = 5.0
	speed_spin.step = 0.1
	speed_spin.value = 1.0
	speed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_row.add_child(speed_spin)
	rail_props.add_child(speed_row)
	
	var allow_jump := CheckBox.new()
	allow_jump.name = "RailAllowJump"
	allow_jump.text = "Allow Jump Off"
	allow_jump.button_pressed = true
	rail_props.add_child(allow_jump)
	
	var allow_crouch := CheckBox.new()
	allow_crouch.name = "RailAllowCrouch"
	allow_crouch.text = "Crouch Boost"
	allow_crouch.button_pressed = true
	rail_props.add_child(allow_crouch)
	
	content.add_child(rail_props)
	
	# Roller Coaster Properties (visible when Coaster selected)
	var coaster_props := VBoxContainer.new()
	coaster_props.name = "CoasterProperties"
	coaster_props.visible = false
	
	coaster_props.add_child(_make_label("Coaster Properties"))
	
	var base_speed_row := HBoxContainer.new()
	var base_speed_label := Label.new()
	base_speed_label.text = "Base Speed:"
	base_speed_label.custom_minimum_size.x = 80
	base_speed_row.add_child(base_speed_label)
	var base_speed_spin := SpinBox.new()
	base_speed_spin.name = "CoasterSpeedSpin"
	base_speed_spin.min_value = 5.0
	base_speed_spin.max_value = 50.0
	base_speed_spin.step = 1.0
	base_speed_spin.value = 15.0
	base_speed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_speed_row.add_child(base_speed_spin)
	coaster_props.add_child(base_speed_row)
	
	var locked_check := CheckBox.new()
	locked_check.name = "CoasterLocked"
	locked_check.text = "Locked Ride (No Jump)"
	locked_check.button_pressed = true
	coaster_props.add_child(locked_check)
	
	content.add_child(coaster_props)
	
	# Light Dash Properties (visible when Dash selected)
	var dash_props := VBoxContainer.new()
	dash_props.name = "DashProperties"
	dash_props.visible = false
	
	dash_props.add_child(_make_label("Light Dash Properties"))
	
	var dash_speed_row := HBoxContainer.new()
	var dash_speed_label := Label.new()
	dash_speed_label.text = "Dash Speed:"
	dash_speed_label.custom_minimum_size.x = 80
	dash_speed_row.add_child(dash_speed_label)
	var dash_speed_spin := SpinBox.new()
	dash_speed_spin.name = "DashSpeedSpin"
	dash_speed_spin.min_value = 10.0
	dash_speed_spin.max_value = 60.0
	dash_speed_spin.step = 1.0
	dash_speed_spin.value = 30.0
	dash_speed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dash_speed_row.add_child(dash_speed_spin)
	dash_props.add_child(dash_speed_row)
	
	var dedicated_check := CheckBox.new()
	dedicated_check.name = "DashDedicated"
	dedicated_check.text = "Dedicated Rings"
	dedicated_check.button_pressed = true
	dedicated_check.tooltip_text = "Use transparent auto-replenish rings"
	dash_props.add_child(dedicated_check)
	
	var works_regular := CheckBox.new()
	works_regular.name = "DashWorksRegular"
	works_regular.text = "Works with Regular Rings"
	works_regular.button_pressed = true
	dash_props.add_child(works_regular)
	
	content.add_child(dash_props)
	
	content.add_child(HSeparator.new())
	
	# Path List
	content.add_child(_make_label("Paths in Level"))
	var path_list := ItemList.new()
	path_list.name = "PathList"
	path_list.custom_minimum_size.y = 100
	path_list.item_selected.connect(_on_path_list_selected)
	content.add_child(path_list)
	
	return scroll

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _update_tile_selector() -> void:
	# This is now deprecated - kept for compatibility only
	if not _tile_selector:
		return
	_tile_selector.clear()
	if _current_palette:
		for i in range(_current_palette.tiles.size()):
			var tile := _current_palette.tiles[i]
			_tile_selector.add_item(tile.display_name, i)
			_tile_selector.set_item_metadata(i, tile.tile_id)

# ============ TILE PALETTE SYSTEM ============

var _tile_icon_buttons: Dictionary = {}  # tile_id -> Button
var _current_category_filter: String = "Geometry"  # Default to Geometry
var _palette_button_group: ButtonGroup

func _initialize_tile_palette() -> void:
	if not _main_dock or not _current_palette:
		return
	
	_palette_button_group = ButtonGroup.new()
	
	# Get UI elements
	var category_filter := _main_dock.find_child("CategoryFilter", true, false) as OptionButton
	
	if not category_filter:
		push_error("[Xtreme Level Editor] CategoryFilter not found!")
		return
	
	# Build list of categories from the palette
	var categories: Array[String] = []
	for tile in _current_palette.tiles:
		if tile.category not in categories:
			categories.append(tile.category)
	
	# Sort categories in a logical order
	var category_order := ["Geometry", "Hazards", "Interactive", "Collectibles", "Enemies", "Progress", "Decoration"]
	var sorted_categories: Array[String] = []
	for cat in category_order:
		if cat in categories:
			sorted_categories.append(cat)
	# Add any remaining categories not in our predefined order
	for cat in categories:
		if cat not in sorted_categories:
			sorted_categories.append(cat)
	
	# Populate category dropdown
	category_filter.clear()
	for i in range(sorted_categories.size()):
		category_filter.add_item(sorted_categories[i], i)
	
	# Select first category (Geometry)
	if sorted_categories.size() > 0:
		_current_category_filter = sorted_categories[0]
		category_filter.select(0)
	
	# Populate the tile grid
	_refresh_tile_grid()
	
	# Select first tile
	if _current_palette.tiles.size() > 0:
		for tile in _current_palette.tiles:
			if tile.category == _current_category_filter:
				_select_tile(tile)
				break

func _refresh_tile_grid() -> void:
	if not _main_dock or not _current_palette:
		return
	
	var tile_grid := _main_dock.find_child("TilePaletteGrid", true, false) as GridContainer
	if not tile_grid:
		return
	
	# Clear existing icons
	for child in tile_grid.get_children():
		child.queue_free()
	_tile_icon_buttons.clear()
	
	# Create icon buttons for tiles in current category
	for tile in _current_palette.tiles:
		if tile.category != _current_category_filter:
			continue
		
		# Create icon button
		var icon_btn := Button.new()
		icon_btn.toggle_mode = true
		icon_btn.button_group = _palette_button_group
		icon_btn.custom_minimum_size = Vector2(60, 60)
		icon_btn.tooltip_text = "%s\n%s\nSize: %dx%dx%d" % [tile.display_name, tile.category, tile.cell_size.x, tile.cell_size.y, tile.cell_size.z]
		
		# Create a VBox for icon + label
		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Create color rect as icon (since we don't have actual textures)
		var icon_container := CenterContainer.new()
		icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var color_icon := ColorRect.new()
		color_icon.color = tile.editor_color
		color_icon.custom_minimum_size = Vector2(32, 32)
		color_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Add border effect
		var icon_panel := PanelContainer.new()
		icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = tile.editor_color
		icon_style.set_border_width_all(2)
		icon_style.border_color = tile.editor_color.lightened(0.3)
		icon_style.set_corner_radius_all(4)
		icon_panel.add_theme_stylebox_override("panel", icon_style)
		icon_panel.custom_minimum_size = Vector2(36, 36)
		
		icon_container.add_child(icon_panel)
		vbox.add_child(icon_container)
		
		# Short label
		var label := Label.new()
		label.text = _get_short_name(tile.display_name)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 9)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(label)
		
		icon_btn.add_child(vbox)
		
		# Style the button
		var btn_normal := StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.2, 0.2, 0.2)
		btn_normal.set_border_width_all(1)
		btn_normal.border_color = Color(0.3, 0.3, 0.3)
		btn_normal.set_corner_radius_all(6)
		icon_btn.add_theme_stylebox_override("normal", btn_normal)
		
		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.25, 0.25, 0.3)
		btn_hover.set_border_width_all(2)
		btn_hover.border_color = tile.editor_color.lightened(0.2)
		btn_hover.set_corner_radius_all(6)
		icon_btn.add_theme_stylebox_override("hover", btn_hover)
		
		var btn_pressed := StyleBoxFlat.new()
		btn_pressed.bg_color = Color(0.15, 0.25, 0.35)
		btn_pressed.set_border_width_all(3)
		btn_pressed.border_color = Color.WHITE
		btn_pressed.set_corner_radius_all(6)
		icon_btn.add_theme_stylebox_override("pressed", btn_pressed)
		
		# Connect selection
		icon_btn.pressed.connect(_on_tile_icon_pressed.bind(tile))
		
		# Select if this is current tile
		if tile.tile_id == _selected_tile_id:
			icon_btn.button_pressed = true
		
		tile_grid.add_child(icon_btn)
		_tile_icon_buttons[tile.tile_id] = icon_btn

func _get_short_name(name: String) -> String:
	# Shorten long names for the icon label
	if name.length() > 10:
		return name.substr(0, 8) + ".."
	return name

func _on_tile_icon_pressed(tile: XtremeTileDefinition) -> void:
	_select_tile(tile)

func _select_tile(tile: XtremeTileDefinition) -> void:
	_selected_tile_id = tile.tile_id
	
	# Update info panel
	if _main_dock:
		var name_label := _main_dock.find_child("SelectedTileName", true, false) as Label
		var category_label := _main_dock.find_child("SelectedTileCategory", true, false) as Label
		var size_label := _main_dock.find_child("SelectedTileSize", true, false) as Label
		
		if name_label:
			name_label.text = "Selected: %s" % tile.display_name
		if category_label:
			category_label.text = "Category: %s" % tile.category
		if size_label:
			size_label.text = "Size: %dx%dx%d" % [tile.cell_size.x, tile.cell_size.y, tile.cell_size.z]
	
	# Update button selection state
	for tile_id in _tile_icon_buttons:
		var btn: Button = _tile_icon_buttons[tile_id]
		if btn and is_instance_valid(btn):
			btn.button_pressed = (tile_id == _selected_tile_id)
	
	_set_status("Selected: %s" % tile.display_name)

func _on_category_filter_changed(index: int) -> void:
	var category_filter := _main_dock.find_child("CategoryFilter", true, false) as OptionButton
	if category_filter:
		_current_category_filter = category_filter.get_item_text(index)
		_refresh_tile_grid()
		
		# Select first tile in new category
		for tile in _current_palette.tiles:
			if tile.category == _current_category_filter:
				_select_tile(tile)
				break

func _on_tile_selected(index: int) -> void:
	# Legacy dropdown handler
	if _current_palette and index >= 0 and index < _current_palette.tiles.size():
		var tile := _current_palette.tiles[index]
		_select_tile(tile)

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

func _on_rotation_x_changed(value: float) -> void:
	_current_rotation.x = int(value) % 4
	_update_rotation_display()

func _on_rotation_y_changed(value: float) -> void:
	_current_rotation.y = int(value) % 4
	_update_rotation_display()

func _on_rotation_z_changed(value: float) -> void:
	_current_rotation.z = int(value) % 4
	_update_rotation_display()

func _reset_rotation() -> void:
	_current_rotation = Vector3i.ZERO
	if _rotation_x_spinbox: _rotation_x_spinbox.value = 0
	if _rotation_y_spinbox: _rotation_y_spinbox.value = 0
	if _rotation_z_spinbox: _rotation_z_spinbox.value = 0
	_set_status("Rotation reset")

func _cycle_rotation_y() -> void:
	_current_rotation.y = (_current_rotation.y + 1) % 4
	if _rotation_y_spinbox: _rotation_y_spinbox.value = _current_rotation.y
	_update_rotation_display()

func _cycle_rotation_x() -> void:
	_current_rotation.x = (_current_rotation.x + 1) % 4
	if _rotation_x_spinbox: _rotation_x_spinbox.value = _current_rotation.x
	_update_rotation_display()

func _cycle_rotation_z() -> void:
	_current_rotation.z = (_current_rotation.z + 1) % 4
	if _rotation_z_spinbox: _rotation_z_spinbox.value = _current_rotation.z
	_update_rotation_display()

func _update_rotation_display() -> void:
	var degrees := _current_rotation * 90
	_set_status("Rotation: X=%d° Y=%d° Z=%d°" % [degrees.x, degrees.y, degrees.z])

# ============ Grid Orientation ============

func _set_grid_orientation(orientation: int) -> void:
	_grid_orientation = orientation
	
	# Update the layer label based on orientation
	if _main_dock:
		var layer_label := _main_dock.find_child("LayerLabel", true, false) as Label
		if layer_label:
			match orientation:
				GRID_XZ: layer_label.text = "Y Level: "
				GRID_XY: layer_label.text = "Z Level: "
				GRID_YZ: layer_label.text = "X Level: "
	
	# Update button states
	_update_grid_orientation_buttons()
	
	# Redraw grid lines
	_update_grid_lines()
	
	var names := ["XZ (Floor)", "XY (Front Wall)", "YZ (Side Wall)"]
	_set_status("Grid: %s" % names[orientation])

func _update_grid_orientation_buttons() -> void:
	if not _main_dock:
		return
	var xz_btn := _main_dock.find_child("GridXZ", true, false) as Button
	var xy_btn := _main_dock.find_child("GridXY", true, false) as Button
	var yz_btn := _main_dock.find_child("GridYZ", true, false) as Button
	
	if xz_btn: xz_btn.button_pressed = (_grid_orientation == GRID_XZ)
	if xy_btn: xy_btn.button_pressed = (_grid_orientation == GRID_XY)
	if yz_btn: yz_btn.button_pressed = (_grid_orientation == GRID_YZ)

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
	
	# Get the current tile definition and its size
	var tile_def := _get_selected_tile_definition()
	var tile_size := Vector3i(1, 1, 1)
	if tile_def:
		tile_size = tile_def.get_rotated_size(_current_rotation)
	
	# Calculate the preview bounds based on tile size
	var anchor_pos := center_pos
	
	# For multi-cell tiles, calculate anchor position (bottom-left-front corner)
	var world_min := Vector3(
		anchor_pos.x * cell.x,
		anchor_pos.y * cell.y,
		anchor_pos.z * cell.z
	)
	var world_max := Vector3(
		(anchor_pos.x + tile_size.x) * cell.x,
		(anchor_pos.y + tile_size.y) * cell.y,
		(anchor_pos.z + tile_size.z) * cell.z
	)
	var preview_center := (world_min + world_max) / 2.0
	var preview_size := world_max - world_min
	
	# Check if placement is blocked
	var is_blocked := _is_placement_blocked(anchor_pos, tile_size)
	
	# Update material color based on blocked state
	if _brush_preview_material:
		if _edit_mode == 1:  # Erase mode - always show erase color
			_brush_preview_material.albedo_color = Color(1.0, 0.5, 0.0, 0.35)  # Orange for erase
		elif is_blocked:
			_brush_preview_material.albedo_color = BRUSH_COLOR_BLOCKED
		else:
			_brush_preview_material.albedo_color = BRUSH_COLOR_VALID
	
	var box := BoxMesh.new()
	box.size = preview_size
	_brush_preview_mesh.mesh = box
	_brush_preview_mesh.position = preview_center
	_brush_preview_mesh.visible = true

func _is_placement_blocked(anchor_pos: Vector3i, tile_size: Vector3i) -> bool:
	if not _current_level:
		return false
	
	# Check all cells that this tile would occupy
	for x in range(tile_size.x):
		for y in range(tile_size.y):
			for z in range(tile_size.z):
				var check_pos := anchor_pos + Vector3i(x, y, z)
				
				# Check bounds
				if check_pos.x < 0 or check_pos.x >= _current_level.size_x:
					return true
				if check_pos.y < 0 or check_pos.y >= _current_level.size_y:
					return true
				if check_pos.z < 0 or check_pos.z >= _current_level.size_z:
					return true
				
				# Check if cell is already occupied
				if _current_level.has_tile(check_pos):
					return true
	
	return false

func _get_selected_tile_definition() -> XtremeTileDefinition:
	if not _current_palette:
		return null
	return _current_palette.get_tile(_selected_tile_id)

func _update_rect_preview(current_pos: Vector3i) -> void:
	if not _rect_preview_mesh or not _grid_settings:
		return
	if not _rect_dragging or _rect_drag_start.x < 0 or current_pos.x < 0:
		_rect_preview_mesh.visible = false
		return
	
	# Get tile definition and size
	var tile_def := _get_selected_tile_definition()
	var tile_size := Vector3i(1, 1, 1)
	if tile_def:
		tile_size = tile_def.get_rotated_size(_current_rotation)
	
	var cell := _grid_settings.get_cell_size()
	var min_x := mini(_rect_drag_start.x, current_pos.x)
	var max_x := maxi(_rect_drag_start.x, current_pos.x) + 1
	var min_z := mini(_rect_drag_start.z, current_pos.z)
	var max_z := maxi(_rect_drag_start.z, current_pos.z) + 1
	
	# For multi-cell tiles, snap the preview to show how many tiles will fit
	var rect_width := max_x - min_x
	var rect_depth := max_z - min_z
	var tiles_x := rect_width / tile_size.x
	var tiles_z := rect_depth / tile_size.z
	
	# Show snapped preview size
	var snapped_width := tiles_x * tile_size.x
	var snapped_depth := tiles_z * tile_size.z
	
	if snapped_width < tile_size.x:
		snapped_width = tile_size.x
	if snapped_depth < tile_size.z:
		snapped_depth = tile_size.z
	
	var world_min := Vector3(min_x * cell.x, _current_y_level * cell.y, min_z * cell.z)
	var world_max := Vector3(
		(min_x + snapped_width) * cell.x, 
		(_current_y_level + tile_size.y) * cell.y, 
		(min_z + snapped_depth) * cell.z
	)
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
	
	# Create manifest with default chunk set (Phase 3)
	_current_manifest = XtremeLevelManifest.create_default(&"new_level", "New Level")
	_current_chunk_set = _current_manifest.get_chunk_set(&"main")
	if _current_chunk_set:
		_current_chunk_set.size = Vector3i(
			_current_level.size_x,
			_current_level.size_y,
			_current_level.size_z
		)
	_update_chunk_set_selector()
	
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
	
	# Curved world settings
	var curve_check := _main_dock.find_child("ExportWithCurve", true, false) as CheckBox
	exporter.apply_curved_world = curve_check.button_pressed if curve_check else true
	var intensity := _main_dock.find_child("CurveIntensity", true, false) as HSlider
	exporter.curve_intensity = intensity.value if intensity else 0.01
	
	# Distance effect settings
	var dist_check := _main_dock.find_child("DistanceEffectsEnabled", true, false) as CheckBox
	exporter.distance_effects_enabled = dist_check.button_pressed if dist_check else true
	
	var max_dist := _main_dock.find_child("EffectMaxDistance", true, false) as HSlider
	exporter.effect_max_distance = max_dist.value if max_dist else 150.0
	
	var wire_start := _main_dock.find_child("WireframeStart", true, false) as HSlider
	exporter.wireframe_start = wire_start.value if wire_start else 0.3
	
	# wireframe_full is calculated based on wireframe_start + 0.4 (gradual transition)
	exporter.wireframe_full = (wire_start.value + 0.4) if wire_start else 0.7
	
	var diss_start := _main_dock.find_child("DissolveStart", true, false) as HSlider
	exporter.dissolve_start = diss_start.value if diss_start else 0.3
	
	# dissolve_full is calculated based on dissolve_start + 0.6 (gradual transition)
	exporter.dissolve_full = (diss_start.value + 0.6) if diss_start else 0.9
	
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

func _on_distance_effects_toggled(enabled: bool) -> void:
	if _grid_visualizer:
		_grid_visualizer.distance_effects_enabled = enabled
		_grid_visualizer.rebuild()

func _on_effect_distance_changed(value: float) -> void:
	if _grid_visualizer:
		_grid_visualizer.effect_max_distance = value
		_rebuild_if_effects_enabled()

func _on_wireframe_start_changed(value: float) -> void:
	if _grid_visualizer:
		_grid_visualizer.wireframe_start = value
		_rebuild_if_effects_enabled()

func _on_dissolve_start_changed(value: float) -> void:
	if _grid_visualizer:
		_grid_visualizer.dissolve_start = value
		_rebuild_if_effects_enabled()

func _rebuild_if_effects_enabled() -> void:
	if not _grid_visualizer:
		return
	var dist_check := _main_dock.find_child("DistanceEffectsEnabled", true, false) as CheckBox
	var curve_check := _main_dock.find_child("CurveEnabled", true, false) as CheckBox
	if (dist_check and dist_check.button_pressed) or (curve_check and curve_check.button_pressed):
		_grid_visualizer.rebuild()

# ============ Visualizer ============

func _create_or_update_visualizer() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		_set_status("Open a 3D scene first!")
		return
	_cleanup_visualizer()
	_grid_visualizer = XtremeGridVisualizer.new()
	_grid_visualizer.name = "XtremeGridVisualizer_TEMP"  # Mark as temporary
	_grid_visualizer.grid_settings = _grid_settings
	_grid_visualizer.level_data = _current_level
	_grid_visualizer.tile_palette = _current_palette
	
	# Sync visualizer settings from UI checkboxes
	var curve_check := _main_dock.find_child("CurveEnabled", true, false) as CheckBox
	var dist_check := _main_dock.find_child("DistanceEffectsEnabled", true, false) as CheckBox
	var curve_slider := _main_dock.find_child("CurveIntensity", true, false) as HSlider
	var dist_slider := _main_dock.find_child("EffectMaxDist", true, false) as HSlider
	var wire_slider := _main_dock.find_child("WireframeStart", true, false) as HSlider
	var dissolve_slider := _main_dock.find_child("DissolveStart", true, false) as HSlider
	
	# Default to OFF for both previews unless explicitly enabled in UI
	_grid_visualizer.curved_preview_enabled = curve_check.button_pressed if curve_check else false
	_grid_visualizer.distance_effects_enabled = dist_check.button_pressed if dist_check else false
	
	if curve_slider:
		_grid_visualizer.curve_intensity = curve_slider.value
	if dist_slider:
		_grid_visualizer.effect_max_distance = dist_slider.value
	if wire_slider:
		_grid_visualizer.wireframe_start = wire_slider.value
		_grid_visualizer.wireframe_full = wire_slider.value + 0.3  # Sensible default
	if dissolve_slider:
		_grid_visualizer.dissolve_start = dissolve_slider.value
		_grid_visualizer.dissolve_full = dissolve_slider.value + 0.4  # Sensible default
	
	scene_root.add_child(_grid_visualizer)
	# Do NOT set owner - this prevents saving with scene
	_create_grid_lines(scene_root)
	_create_selection_box(scene_root)
	_create_brush_preview(scene_root)
	_create_rect_preview(scene_root)
	_create_select_preview(scene_root)

func _create_grid_lines(parent: Node) -> void:
	_grid_lines_mesh = MeshInstance3D.new()
	_grid_lines_mesh.name = "XtremeGridLines_TEMP"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.6, 1.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grid_lines_mesh.material_override = mat
	parent.add_child(_grid_lines_mesh)
	# Do NOT set owner - this prevents saving with scene
	_update_grid_lines()

func _create_selection_box(parent: Node) -> void:
	_selection_box_mesh = MeshInstance3D.new()
	_selection_box_mesh.name = "XtremeSelectionBox_TEMP"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 0.0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_selection_box_mesh.material_override = mat
	_selection_box_mesh.visible = false
	parent.add_child(_selection_box_mesh)
	# Do NOT set owner - this prevents saving with scene

func _create_brush_preview(parent: Node) -> void:
	_brush_preview_mesh = MeshInstance3D.new()
	_brush_preview_mesh.name = "XtremeBrushPreview_TEMP"
	_brush_preview_material = StandardMaterial3D.new()
	_brush_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_brush_preview_material.albedo_color = BRUSH_COLOR_VALID
	_brush_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_brush_preview_mesh.material_override = _brush_preview_material
	_brush_preview_mesh.visible = false
	parent.add_child(_brush_preview_mesh)
	# Do NOT set owner - this prevents saving with scene

func _create_rect_preview(parent: Node) -> void:
	_rect_preview_mesh = MeshInstance3D.new()
	_rect_preview_mesh.name = "XtremeRectPreview_TEMP"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.5, 0.3, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rect_preview_mesh.material_override = mat
	_rect_preview_mesh.visible = false
	parent.add_child(_rect_preview_mesh)
	# Do NOT set owner - this prevents saving with scene

func _create_select_preview(parent: Node) -> void:
	_select_preview_mesh = MeshInstance3D.new()
	_select_preview_mesh.name = "XtremeSelectPreview_TEMP"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.2, 0.35)  # Yellow-ish for select
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_select_preview_mesh.material_override = mat
	_select_preview_mesh.visible = false
	parent.add_child(_select_preview_mesh)
	# Do NOT set owner - this prevents saving with scene

func _update_grid_lines() -> void:
	if not _grid_lines_mesh or not _current_level or not _grid_settings:
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var cell := _grid_settings.get_cell_size()
	
	match _grid_orientation:
		GRID_XZ:  # Horizontal plane (floor/ceiling)
			var y_pos := _current_y_level * cell.y
			var width := _current_level.size_x
			var depth := _current_level.size_z
			# Lines along X axis
			for z in range(depth + 1):
				var z_pos := z * cell.z
				im.surface_add_vertex(Vector3(0, y_pos, z_pos))
				im.surface_add_vertex(Vector3(width * cell.x, y_pos, z_pos))
			# Lines along Z axis
			for x in range(width + 1):
				var x_pos := x * cell.x
				im.surface_add_vertex(Vector3(x_pos, y_pos, 0))
				im.surface_add_vertex(Vector3(x_pos, y_pos, depth * cell.z))
		
		GRID_XY:  # Vertical plane facing Z (front wall)
			var z_pos := _current_y_level * cell.z
			var width := _current_level.size_x
			var height := _current_level.size_y
			# Lines along X axis
			for y in range(height + 1):
				var y_pos := y * cell.y
				im.surface_add_vertex(Vector3(0, y_pos, z_pos))
				im.surface_add_vertex(Vector3(width * cell.x, y_pos, z_pos))
			# Lines along Y axis
			for x in range(width + 1):
				var x_pos := x * cell.x
				im.surface_add_vertex(Vector3(x_pos, 0, z_pos))
				im.surface_add_vertex(Vector3(x_pos, height * cell.y, z_pos))
		
		GRID_YZ:  # Vertical plane facing X (side wall)
			var x_pos := _current_y_level * cell.x
			var depth := _current_level.size_z
			var height := _current_level.size_y
			# Lines along Z axis
			for y in range(height + 1):
				var y_pos := y * cell.y
				im.surface_add_vertex(Vector3(x_pos, y_pos, 0))
				im.surface_add_vertex(Vector3(x_pos, y_pos, depth * cell.z))
			# Lines along Y axis
			for z in range(depth + 1):
				var z_pos := z * cell.z
				im.surface_add_vertex(Vector3(x_pos, 0, z_pos))
				im.surface_add_vertex(Vector3(x_pos, height * cell.y, z_pos))
	
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
				if _water_zone_dragging:
					_finish_water_zone(pos)
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
			
			# Update water zone preview while dragging
			if _water_zone_dragging:
				_update_water_zone_preview(pos)
	
	return AFTER_GUI_INPUT_PASS

func _show_context_menu(global_pos: Vector2) -> void:
	if _context_menu:
		_context_menu.position = Vector2i(global_pos)
		_context_menu.popup()

func _raycast_grid(origin: Vector3, direction: Vector3) -> Vector3i:
	if not _current_level or not _grid_settings:
		return Vector3i(-1, -1, -1)
	
	var cell_size := _grid_settings.get_cell_size()
	
	match _grid_orientation:
		GRID_XZ:  # Horizontal plane (Y = constant)
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
		
		GRID_XY:  # Vertical plane facing Z (Z = constant)
			var plane_z := _current_y_level * cell_size.z  # Using Y level spinbox for Z
			if abs(direction.z) > 0.001:
				var t := (plane_z - origin.z) / direction.z
				if t > 0:
					var hit := origin + direction * t
					var grid_x := floori(hit.x / cell_size.x)
					var grid_y := floori(hit.y / cell_size.y)
					if grid_x >= 0 and grid_x < _current_level.size_x \
						and grid_y >= 0 and grid_y < _current_level.size_y:
						return Vector3i(grid_x, grid_y, _current_y_level)
		
		GRID_YZ:  # Vertical plane facing X (X = constant)
			var plane_x := _current_y_level * cell_size.x  # Using Y level spinbox for X
			if abs(direction.x) > 0.001:
				var t := (plane_x - origin.x) / direction.x
				if t > 0:
					var hit := origin + direction * t
					var grid_y := floori(hit.y / cell_size.y)
					var grid_z := floori(hit.z / cell_size.z)
					if grid_y >= 0 and grid_y < _current_level.size_y \
						and grid_z >= 0 and grid_z < _current_level.size_z:
						return Vector3i(_current_y_level, grid_y, grid_z)
	
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
		5:  # Water Zone - start drag
			_start_water_zone(pos)

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

func _paint_at_single(anchor_pos: Vector3i) -> void:
	# Get tile definition and size
	var tile_def := _get_selected_tile_definition()
	var tile_size := Vector3i(1, 1, 1)
	if tile_def:
		tile_size = tile_def.get_rotated_size(_current_rotation)
	
	# Check if placement is blocked
	if _is_placement_blocked(anchor_pos, tile_size):
		return  # Can't place here
	
	# Record before state for ALL cells this tile will occupy
	var cells_to_occupy: Array[Vector3i] = []
	for x in range(tile_size.x):
		for y in range(tile_size.y):
			for z in range(tile_size.z):
				var cell_pos := anchor_pos + Vector3i(x, y, z)
				cells_to_occupy.append(cell_pos)
				
				# Record before state if not already recorded
				if cell_pos not in _stroke_before:
					if _current_level.has_tile(cell_pos):
						_stroke_before[cell_pos] = _current_level.get_tile(cell_pos)
					if cell_pos not in _stroke_affected:
						_stroke_affected.append(cell_pos)
	
	# For single-cell tiles, just place normally
	if tile_size == Vector3i(1, 1, 1):
		_current_level.set_tile(anchor_pos, _selected_tile_id, _current_rotation)
		_grid_visualizer.update_tile(anchor_pos)
	else:
		# For multi-cell tiles, use the multi-cell placement system
		# Place anchor tile
		_current_level.set_tile(anchor_pos, _selected_tile_id, _current_rotation)
		
		# Mark other cells as occupied by this multi-cell object
		for x in range(tile_size.x):
			for y in range(tile_size.y):
				for z in range(tile_size.z):
					var cell_pos := anchor_pos + Vector3i(x, y, z)
					if cell_pos != anchor_pos:
						_current_level.set_tile(cell_pos, &"_multicell_part", Vector3i.ZERO)
		
		# Update visuals for all affected cells
		for cell_pos in cells_to_occupy:
			_grid_visualizer.update_tile(cell_pos)
	
	# Auto-configure special tile types (Phase 3)
	if tile_def:
		match tile_def.tile_type:
			XtremeTileDefinition.TileType.TRANSPORT:
				_auto_configure_transport_tile(anchor_pos, _selected_tile_id)
			XtremeTileDefinition.TileType.GOAL:
				_auto_configure_goal_tile(anchor_pos, _selected_tile_id)
			XtremeTileDefinition.TileType.SPAWN:
				_auto_configure_spawn_tile(anchor_pos, _selected_tile_id)

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
	
	# Get tile definition and size
	var tile_def := _get_selected_tile_definition()
	var tile_size := Vector3i(1, 1, 1)
	if tile_def:
		tile_size = tile_def.get_rotated_size(_current_rotation)
	
	var min_x := mini(_rect_drag_start.x, pos.x)
	var max_x := maxi(_rect_drag_start.x, pos.x)
	var min_z := mini(_rect_drag_start.z, pos.z)
	var max_z := maxi(_rect_drag_start.z, pos.z)
	
	# Calculate how many tiles can fit in the rect
	var rect_width := max_x - min_x + 1
	var rect_depth := max_z - min_z + 1
	
	# For multi-cell tiles, snap to tile size grid and only place full tiles
	var tiles_x := rect_width / tile_size.x
	var tiles_z := rect_depth / tile_size.z
	
	if tiles_x < 1 or tiles_z < 1:
		_set_status("Area too small for this tile")
		return
	
	# Collect all cells that will be affected
	var affected: Array[Vector3i] = []
	var tile_anchors: Array[Vector3i] = []
	
	for tx in range(tiles_x):
		for tz in range(tiles_z):
			var anchor := Vector3i(
				min_x + tx * tile_size.x,
				_current_y_level,
				min_z + tz * tile_size.z
			)
			
			# Check if this tile position is blocked
			var blocked := false
			for x in range(tile_size.x):
				for y in range(tile_size.y):
					for z in range(tile_size.z):
						var cell_pos := anchor + Vector3i(x, y, z)
						if cell_pos.x >= _current_level.size_x or cell_pos.z >= _current_level.size_z:
							blocked = true
							break
						if cell_pos.y >= _current_level.size_y:
							blocked = true
							break
						# Don't check for existing tiles if we're filling the whole rect
						# (rect fill should overwrite)
					if blocked: break
				if blocked: break
			
			if not blocked:
				tile_anchors.append(anchor)
				# Add all cells this tile will occupy
				for x in range(tile_size.x):
					for y in range(tile_size.y):
						for z in range(tile_size.z):
							var cell_pos := anchor + Vector3i(x, y, z)
							if cell_pos not in affected:
								affected.append(cell_pos)
	
	if tile_anchors.is_empty():
		_set_status("Cannot place tiles in this area")
		return
	
	var before := _capture_tiles_in_region(affected)
	
	# Place the tiles
	var count := 0
	for anchor in tile_anchors:
		if tile_size == Vector3i(1, 1, 1):
			_current_level.set_tile(anchor, _selected_tile_id, _current_rotation)
			_grid_visualizer.update_tile(anchor)
		else:
			# Place anchor tile
			_current_level.set_tile(anchor, _selected_tile_id, _current_rotation)
			# Mark other cells as occupied
			for x in range(tile_size.x):
				for y in range(tile_size.y):
					for z in range(tile_size.z):
						var cell_pos := anchor + Vector3i(x, y, z)
						if cell_pos != anchor:
							_current_level.set_tile(cell_pos, &"_multicell_part", Vector3i.ZERO)
						_grid_visualizer.update_tile(cell_pos)
		count += 1
	
	var after := _capture_tiles_in_region(affected)
	_record_undo("Rect Fill", before, after)
	
	_set_status("Rect filled %d tiles" % count)

func _handle_select_release(pos: Vector3i) -> void:
	_select_dragging = false
	_select_preview_mesh.visible = false
	
	if pos.x < 0:
		pos = _selection_start
	
	# Calculate initial selection bounds
	var min_pos := Vector3i(
		mini(_selection_start.x, pos.x),
		mini(_selection_start.y, pos.y),
		mini(_selection_start.z, pos.z)
	)
	var max_pos := Vector3i(
		maxi(_selection_start.x, pos.x),
		maxi(_selection_start.y, pos.y),
		maxi(_selection_start.z, pos.z)
	)
	
	# Expand selection to include full multi-cell objects
	# Check each cell in selection for multi-cell parts and expand bounds
	var expanded := true
	while expanded:
		expanded = false
		for x in range(min_pos.x, max_pos.x + 1):
			for y in range(min_pos.y, max_pos.y + 1):
				for z in range(min_pos.z, max_pos.z + 1):
					var check_pos := Vector3i(x, y, z)
					var tile_id := _current_level.get_tile(check_pos)
					
					if tile_id == &"_multicell_part":
						# Find the anchor of this multi-cell object and include all its cells
						var anchor := _find_multicell_anchor(check_pos)
						if anchor.x >= 0:
							var anchor_tile_id := _current_level.get_tile(anchor)
							var anchor_def := _current_palette.get_tile(anchor_tile_id) if _current_palette else null
							if anchor_def:
								var rotation := _current_level.get_tile_rotation(anchor)
								var size := anchor_def.get_rotated_size(rotation)
								# Expand bounds to include entire multi-cell object
								var obj_max := anchor + size - Vector3i.ONE
								if anchor.x < min_pos.x or anchor.y < min_pos.y or anchor.z < min_pos.z:
									min_pos.x = mini(min_pos.x, anchor.x)
									min_pos.y = mini(min_pos.y, anchor.y)
									min_pos.z = mini(min_pos.z, anchor.z)
									expanded = true
								if obj_max.x > max_pos.x or obj_max.y > max_pos.y or obj_max.z > max_pos.z:
									max_pos.x = maxi(max_pos.x, obj_max.x)
									max_pos.y = maxi(max_pos.y, obj_max.y)
									max_pos.z = maxi(max_pos.z, obj_max.z)
									expanded = true
					elif tile_id != &"" and tile_id != &"empty":
						# Check if this is a multi-cell anchor
						var tile_def := _current_palette.get_tile(tile_id) if _current_palette else null
						if tile_def and tile_def.is_multicell():
							var rotation := _current_level.get_tile_rotation(check_pos)
							var size := tile_def.get_rotated_size(rotation)
							var obj_max := check_pos + size - Vector3i.ONE
							if obj_max.x > max_pos.x or obj_max.y > max_pos.y or obj_max.z > max_pos.z:
								max_pos.x = maxi(max_pos.x, obj_max.x)
								max_pos.y = maxi(max_pos.y, obj_max.y)
								max_pos.z = maxi(max_pos.z, obj_max.z)
								expanded = true
	
	_selection_start = min_pos
	_selection_end = max_pos
	_has_selection = true
	_update_selection_info()
	_update_selection_visual()
	
	var size := max_pos - min_pos + Vector3i.ONE
	_set_status("Selected: %dx%dx%d" % [size.x, size.y, size.z])

func _find_multicell_anchor(part_pos: Vector3i) -> Vector3i:
	# Search nearby cells for the anchor of a multi-cell object
	# The anchor is the cell that contains the actual tile_id (not _multicell_part)
	# Search in a reasonable radius (up to 9 cells in each direction for 9x9x9 max size)
	for dx in range(-8, 1):
		for dy in range(-8, 1):
			for dz in range(-8, 1):
				var check := part_pos + Vector3i(dx, dy, dz)
				if check.x < 0 or check.y < 0 or check.z < 0:
					continue
				var tile_id := _current_level.get_tile(check)
				if tile_id != &"" and tile_id != &"_multicell_part":
					# Check if this anchor's footprint includes part_pos
					var tile_def := _current_palette.get_tile(tile_id) if _current_palette else null
					if tile_def and tile_def.is_multicell():
						var rotation := _current_level.get_tile_rotation(check)
						var size := tile_def.get_rotated_size(rotation)
						var obj_min := check
						var obj_max := check + size - Vector3i.ONE
						if part_pos.x >= obj_min.x and part_pos.x <= obj_max.x \
							and part_pos.y >= obj_min.y and part_pos.y <= obj_max.y \
							and part_pos.z >= obj_min.z and part_pos.z <= obj_max.z:
							return check
	return Vector3i(-1, -1, -1)

func _bucket_fill_at(start_pos: Vector3i) -> void:
	var clicked_tile := _current_level.get_tile(start_pos)
	
	# Determine fill mode: empty fill or tile replacement
	if clicked_tile == &"" or clicked_tile == &"empty":
		# Empty cell - flood fill empty space
		_bucket_fill_empty(start_pos)
	elif clicked_tile == _selected_tile_id:
		# Same tile type - nothing to do
		_set_status("Already this tile type")
	else:
		# Different tile type - replace connected tiles of same type
		_bucket_fill_replace(start_pos, clicked_tile)

func _bucket_fill_empty(start_pos: Vector3i) -> void:
	# Get tile definition and size
	var tile_def := _get_selected_tile_definition()
	var tile_size := Vector3i(1, 1, 1)
	if tile_def:
		tile_size = tile_def.get_rotated_size(_current_rotation)
	
	# First, flood fill to find all connected empty cells
	var empty_cells: Array[Vector3i] = []
	var to_check: Array[Vector3i] = [start_pos]
	var visited := {}
	visited[start_pos] = true
	
	while to_check.size() > 0 and empty_cells.size() < 10000:
		var pos: Vector3i = to_check.pop_front()
		if pos.x < 0 or pos.x >= _current_level.size_x:
			continue
		if pos.z < 0 or pos.z >= _current_level.size_z:
			continue
		if _current_level.has_tile(pos):
			continue
		
		empty_cells.append(pos)
		
		# Only check face-adjacent neighbors (no diagonals), same Y level
		var neighbors := [
			Vector3i(pos.x + 1, pos.y, pos.z),
			Vector3i(pos.x - 1, pos.y, pos.z),
			Vector3i(pos.x, pos.y, pos.z + 1),
			Vector3i(pos.x, pos.y, pos.z - 1),
		]
		for neighbor in neighbors:
			if neighbor not in visited:
				visited[neighbor] = true
				to_check.append(neighbor)
	
	if empty_cells.is_empty():
		return
	
	# For single-cell tiles, just fill all empty cells
	if tile_size == Vector3i(1, 1, 1):
		var before := _capture_tiles_in_region(empty_cells)
		
		for pos in empty_cells:
			_current_level.set_tile(pos, _selected_tile_id, _current_rotation)
			_grid_visualizer.update_tile(pos)
		
		var after := _capture_tiles_in_region(empty_cells)
		_record_undo("Bucket Fill", before, after)
		_set_status("Bucket filled %d empty cells" % empty_cells.size())
		return
	
	# For multi-cell tiles, place tiles grid-aligned within the empty area
	# Find bounds of empty area
	var min_pos := empty_cells[0]
	var max_pos := empty_cells[0]
	for pos in empty_cells:
		min_pos.x = mini(min_pos.x, pos.x)
		min_pos.z = mini(min_pos.z, pos.z)
		max_pos.x = maxi(max_pos.x, pos.x)
		max_pos.z = maxi(max_pos.z, pos.z)
	
	# Convert empty_cells to a set for fast lookup
	var empty_set := {}
	for pos in empty_cells:
		empty_set[pos] = true
	
	# Try to place tiles grid-aligned
	var tile_anchors: Array[Vector3i] = []
	var all_affected: Array[Vector3i] = []
	
	var x := min_pos.x
	while x <= max_pos.x:
		var z := min_pos.z
		while z <= max_pos.z:
			var anchor := Vector3i(x, _current_y_level, z)
			
			# Check if ALL cells for this tile are in the empty set
			var can_place := true
			var cells_needed: Array[Vector3i] = []
			
			for tx in range(tile_size.x):
				for ty in range(tile_size.y):
					for tz in range(tile_size.z):
						var cell := anchor + Vector3i(tx, ty, tz)
						cells_needed.append(cell)
						if cell not in empty_set:
							can_place = false
							break
					if not can_place: break
				if not can_place: break
			
			if can_place:
				tile_anchors.append(anchor)
				# Mark these cells as "used" so we don't overlap
				for cell in cells_needed:
					empty_set.erase(cell)
					if cell not in all_affected:
						all_affected.append(cell)
			
			z += tile_size.z
		x += tile_size.x
	
	if tile_anchors.is_empty():
		_set_status("No space for tiles of this size")
		return
	
	var before := _capture_tiles_in_region(all_affected)
	
	# Place the tiles
	for anchor in tile_anchors:
		_current_level.set_tile(anchor, _selected_tile_id, _current_rotation)
		for tx in range(tile_size.x):
			for ty in range(tile_size.y):
				for tz in range(tile_size.z):
					var cell := anchor + Vector3i(tx, ty, tz)
					if cell != anchor:
						_current_level.set_tile(cell, &"_multicell_part", Vector3i.ZERO)
					_grid_visualizer.update_tile(cell)
	
	var after := _capture_tiles_in_region(all_affected)
	_record_undo("Bucket Fill", before, after)
	_set_status("Bucket filled %d tiles" % tile_anchors.size())

func _bucket_fill_replace(start_pos: Vector3i, target_tile_id: StringName) -> void:
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
		
		# Only fill cells that have the target tile type
		var tile_at_pos := _current_level.get_tile(pos)
		if tile_at_pos != target_tile_id:
			continue
		
		affected.append(pos)
		
		# Only check face-adjacent neighbors (no diagonals), same Y level
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
	
	if affected.is_empty():
		return
	
	var before := _capture_tiles_in_region(affected)
	
	for pos in affected:
		_current_level.set_tile(pos, _selected_tile_id, _current_rotation)
		_grid_visualizer.update_tile(pos)
	
	var after := _capture_tiles_in_region(affected)
	_record_undo("Bucket Replace", before, after)
	
	_set_status("Replaced %d tiles" % affected.size())

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
	
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			# Grid orientation hotkeys (1, 2, 3)
			if key.keycode == KEY_1:
				_set_grid_orientation(GRID_XZ)
				get_viewport().set_input_as_handled()
			elif key.keycode == KEY_2:
				_set_grid_orientation(GRID_XY)
				get_viewport().set_input_as_handled()
			elif key.keycode == KEY_3:
				_set_grid_orientation(GRID_YZ)
				get_viewport().set_input_as_handled()
			# Rotation hotkeys
			elif key.keycode == KEY_R:
				if key.shift_pressed:
					_cycle_rotation_x()
				elif key.ctrl_pressed:
					_cycle_rotation_z()
				else:
					_cycle_rotation_y()
				get_viewport().set_input_as_handled()
			# Undo/Redo
			elif key.keycode == KEY_Z and key.ctrl_pressed:
				if key.shift_pressed:
					_redo()
				else:
					_undo()
				get_viewport().set_input_as_handled()

# ============ PHASE 3: Level Systems ============

# ------------ Chunk Set Management ------------

func _on_chunk_set_selected(index: int) -> void:
	if not _current_manifest or index < 0:
		return
	
	var chunk_ids := _current_manifest.get_chunk_set_ids()
	if index >= chunk_ids.size():
		return
	
	var chunk_id := chunk_ids[index]
	_load_chunk_set(chunk_id)

func _load_chunk_set(chunk_set_id: StringName) -> void:
	if not _current_manifest:
		return
	
	var chunk_set := _current_manifest.get_chunk_set(chunk_set_id)
	if not chunk_set:
		_set_status("Chunk set '%s' not found" % chunk_set_id)
		return
	
	_current_chunk_set = chunk_set
	
	# Load the level data for this chunk set (or create new if doesn't exist)
	if chunk_set.scene_path and FileAccess.file_exists(chunk_set.scene_path):
		# In a full implementation, load the scene and extract level data
		pass
	else:
		# Create new empty level data for this chunk set
		if not _current_level:
			_current_level = XtremeLevelData.new()
			_current_level.initialize(_grid_settings)
			_current_level.resize(chunk_set.size.x, chunk_set.size.y, chunk_set.size.z)
	
	# Update ghost chunk sets if enabled
	if _ghost_enabled:
		_update_ghost_chunk_sets()
	
	_set_status("Loaded chunk set: %s" % chunk_set.display_name)

func _on_add_chunk_set() -> void:
	if not _current_manifest:
		# Create a new manifest if none exists
		_current_manifest = XtremeLevelManifest.create_default(&"new_level", "New Level")
	
	# Generate unique ID
	var base_id := "chunk_set"
	var counter := 1
	var new_id := StringName(base_id)
	while _current_manifest.get_chunk_set(new_id) != null:
		counter += 1
		new_id = StringName("%s_%d" % [base_id, counter])
	
	# Create new chunk set
	var new_chunk := XtremeChunkSetData.create_with_defaults(new_id, "New Area %d" % counter)
	_current_manifest.add_chunk_set(new_chunk)
	
	# Update dropdown
	_update_chunk_set_selector()
	
	# Select the new chunk set
	var idx := _current_manifest.chunk_sets.find(new_chunk)
	if _chunk_set_selector and idx >= 0:
		_chunk_set_selector.select(idx)
		_load_chunk_set(new_id)
	
	_set_status("Created new chunk set: %s" % new_chunk.display_name)

func _update_chunk_set_selector() -> void:
	if not _chunk_set_selector:
		return
	
	_chunk_set_selector.clear()
	
	if not _current_manifest:
		_chunk_set_selector.add_item("(No Level)")
		return
	
	for chunk_set in _current_manifest.chunk_sets:
		_chunk_set_selector.add_item(chunk_set.display_name)

# ------------ Level Overview Panel ------------

func _show_level_overview() -> void:
	if not _current_manifest:
		_set_status("No level loaded - create or load a level first")
		return
	
	if _level_overview_window:
		_level_overview_window.queue_free()
	
	_level_overview_window = Window.new()
	_level_overview_window.title = "Level Overview - %s" % _current_manifest.level_name
	_level_overview_window.size = Vector2i(800, 600)
	_level_overview_window.transient = true
	_level_overview_window.exclusive = false
	
	var main_container := VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 8)
	_level_overview_window.add_child(main_container)
	
	# Toolbar
	var toolbar := HBoxContainer.new()
	var add_btn := Button.new()
	add_btn.text = "Add Chunk Set"
	add_btn.pressed.connect(_on_add_chunk_set)
	add_btn.pressed.connect(_refresh_level_overview)
	toolbar.add_child(add_btn)
	
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_level_overview)
	toolbar.add_child(refresh_btn)
	
	toolbar.add_child(Control.new())  # Spacer
	
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): _level_overview_window.queue_free())
	toolbar.add_child(close_btn)
	
	main_container.add_child(toolbar)
	
	# Graph area
	var graph_scroll := ScrollContainer.new()
	graph_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	_level_overview_graph = Control.new()
	_level_overview_graph.name = "LevelGraph"
	_level_overview_graph.custom_minimum_size = Vector2(1200, 800)
	_level_overview_graph.draw.connect(_draw_level_overview_graph)
	graph_scroll.add_child(_level_overview_graph)
	main_container.add_child(graph_scroll)
	
	# Add chunk set nodes
	_create_level_overview_nodes()
	
	EditorInterface.get_base_control().add_child(_level_overview_window)
	_level_overview_window.popup_centered()

func _refresh_level_overview() -> void:
	if _level_overview_graph:
		for child in _level_overview_graph.get_children():
			child.queue_free()
		_create_level_overview_nodes()
		_level_overview_graph.queue_redraw()

func _create_level_overview_nodes() -> void:
	if not _level_overview_graph or not _current_manifest:
		return
	
	var node_size := Vector2(150, 80)
	var start_pos := Vector2(50, 50)
	var spacing := Vector2(200, 120)
	
	for i in range(_current_manifest.chunk_sets.size()):
		var chunk_set: XtremeChunkSetData = _current_manifest.chunk_sets[i]
		var node := _create_chunk_set_node(chunk_set, node_size)
		
		if chunk_set.editor_position != Vector2.ZERO:
			node.position = chunk_set.editor_position
		else:
			var col := i % 4
			var row := i / 4
			node.position = start_pos + Vector2(col * spacing.x, row * spacing.y)
			chunk_set.editor_position = node.position
		
		_level_overview_graph.add_child(node)

func _create_chunk_set_node(chunk_set: XtremeChunkSetData, size: Vector2) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	
	var style := StyleBoxFlat.new()
	style.bg_color = chunk_set.editor_color if chunk_set.editor_color != Color.WHITE else Color(0.2, 0.3, 0.5)
	style.set_border_width_all(2)
	style.border_color = Color.WHITE if _current_chunk_set == chunk_set else Color(0.5, 0.5, 0.5)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	var title := Label.new()
	title.text = chunk_set.display_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	var id_label := Label.new()
	id_label.text = "ID: %s" % chunk_set.chunk_set_id
	id_label.add_theme_font_size_override("font_size", 10)
	id_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(id_label)
	
	var info := Label.new()
	info.text = "%d pipes, %d goals" % [chunk_set.outgoing_connections.size(), chunk_set.goal_portals.size()]
	info.add_theme_font_size_override("font_size", 10)
	vbox.add_child(info)
	
	panel.add_child(vbox)
	
	# Make clickable
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				_load_chunk_set(chunk_set.chunk_set_id)
				_update_chunk_set_selector()
				var idx := _current_manifest.chunk_sets.find(chunk_set)
				if _chunk_set_selector and idx >= 0:
					_chunk_set_selector.select(idx)
				_set_status("Opened chunk set: %s" % chunk_set.display_name)
	)
	
	return panel

func _draw_level_overview_graph() -> void:
	if not _level_overview_graph or not _current_manifest:
		return
	
	for chunk_set in _current_manifest.chunk_sets:
		var from_node := _find_chunk_node_in_graph(chunk_set.chunk_set_id)
		if not from_node:
			continue
		
		for connection in chunk_set.outgoing_connections:
			var to_node := _find_chunk_node_in_graph(connection.destination_chunk_set)
			if not to_node:
				continue
			
			var from_pos := from_node.position + from_node.size / 2
			var to_pos := to_node.position + to_node.size / 2
			
			var color := Color.ORANGE if connection.is_one_way else Color.GREEN
			_level_overview_graph.draw_line(from_pos, to_pos, color, 2.0)
			
			var dir := (to_pos - from_pos).normalized()
			var perp := Vector2(-dir.y, dir.x)
			var arrow_pos := to_pos - dir * 20
			_level_overview_graph.draw_polygon([to_pos, arrow_pos + perp * 8, arrow_pos - perp * 8], [color])

func _find_chunk_node_in_graph(chunk_set_id: StringName) -> Control:
	if not _level_overview_graph or not _current_manifest:
		return null
	
	var idx := 0
	for chunk_set in _current_manifest.chunk_sets:
		if chunk_set.chunk_set_id == chunk_set_id:
			if idx < _level_overview_graph.get_child_count():
				return _level_overview_graph.get_child(idx) as Control
		idx += 1
	return null

# ------------ Ghost Chunk Sets ------------

func _on_ghost_toggled(enabled: bool) -> void:
	_ghost_enabled = enabled
	if enabled:
		_update_ghost_chunk_sets()
	else:
		_clear_ghost_chunk_sets()

func _update_ghost_chunk_sets() -> void:
	_clear_ghost_chunk_sets()
	
	if not _ghost_enabled or not _current_manifest or not _current_chunk_set:
		return
	
	var connected := _current_chunk_set.get_connected_chunk_sets()
	
	for chunk_set in _current_manifest.chunk_sets:
		if chunk_set == _current_chunk_set:
			continue
		for conn in chunk_set.outgoing_connections:
			if conn.destination_chunk_set == _current_chunk_set.chunk_set_id:
				if chunk_set.chunk_set_id not in connected:
					connected.append(chunk_set.chunk_set_id)
	
	for chunk_id in connected:
		var chunk_set := _current_manifest.get_chunk_set(chunk_id)
		if chunk_set:
			_create_ghost_visualizer(chunk_set)

func _create_ghost_visualizer(chunk_set: XtremeChunkSetData) -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return
	
	var ghost := MeshInstance3D.new()
	ghost.name = "Ghost_%s" % chunk_set.chunk_set_id
	
	var box := BoxMesh.new()
	var cell_size := _grid_settings.get_cell_size() if _grid_settings else Vector3(2, 2, 2)
	box.size = Vector3(chunk_set.size) * cell_size
	ghost.mesh = box
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(chunk_set.editor_color.r, chunk_set.editor_color.g, chunk_set.editor_color.b, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override = mat
	
	ghost.position = box.size / 2 + Vector3(box.size.x * 1.2, 0, 0)
	
	scene_root.add_child(ghost)
	_ghost_visualizers.append(ghost)

func _clear_ghost_chunk_sets() -> void:
	for ghost in _ghost_visualizers:
		if is_instance_valid(ghost):
			ghost.queue_free()
	_ghost_visualizers.clear()

# ------------ Water Zone Tool ------------

func _start_water_zone(pos: Vector3i) -> void:
	_water_zone_start = pos
	_water_zone_dragging = true
	_update_water_zone_preview(pos)
	_set_status("Water Zone: Drag to set size...")

func _update_water_zone_preview(current_pos: Vector3i) -> void:
	if not _water_zone_dragging:
		return
	
	if not _water_zone_preview:
		_create_water_zone_preview()
	
	var min_pos := Vector3i(
		mini(_water_zone_start.x, current_pos.x),
		mini(_water_zone_start.y, current_pos.y),
		mini(_water_zone_start.z, current_pos.z)
	)
	var max_pos := Vector3i(
		maxi(_water_zone_start.x, current_pos.x),
		maxi(_water_zone_start.y, current_pos.y),
		maxi(_water_zone_start.z, current_pos.z)
	)
	
	var cell_size := _grid_settings.get_cell_size()
	var world_min := Vector3(min_pos) * cell_size
	var world_size := Vector3(max_pos - min_pos + Vector3i.ONE) * cell_size
	
	var box := BoxMesh.new()
	box.size = world_size
	_water_zone_preview.mesh = box
	_water_zone_preview.position = world_min + world_size / 2
	_water_zone_preview.visible = true

func _create_water_zone_preview() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return
	
	_water_zone_preview = MeshInstance3D.new()
	_water_zone_preview.name = "XtremeWaterZonePreview_TEMP"
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.4, 0.9, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_water_zone_preview.material_override = mat
	_water_zone_preview.visible = false
	
	scene_root.add_child(_water_zone_preview)

func _finish_water_zone(end_pos: Vector3i) -> void:
	_water_zone_dragging = false
	
	if _water_zone_preview:
		_water_zone_preview.visible = false
	
	if not _current_chunk_set:
		_set_status("No chunk set loaded - create a level first")
		return
	
	var min_pos := Vector3i(
		mini(_water_zone_start.x, end_pos.x),
		mini(_water_zone_start.y, end_pos.y),
		mini(_water_zone_start.z, end_pos.z)
	)
	var max_pos := Vector3i(
		maxi(_water_zone_start.x, end_pos.x),
		maxi(_water_zone_start.y, end_pos.y),
		maxi(_water_zone_start.z, end_pos.z)
	)
	
	var water_zone := XtremeWaterZone.create_zone(min_pos, max_pos)
	_current_chunk_set.add_water_zone(water_zone)
	
	for x in range(min_pos.x, max_pos.x + 1):
		for y in range(min_pos.y, max_pos.y + 1):
			for z in range(min_pos.z, max_pos.z + 1):
				var pos := Vector3i(x, y, z)
				if _current_level and not _current_level.has_tile(pos):
					_current_level.set_tile(pos, &"water", Vector3i.ZERO)
					if _grid_visualizer:
						_grid_visualizer.update_tile(pos)
	
	var size := max_pos - min_pos + Vector3i.ONE
	_set_status("Created water zone: %dx%dx%d" % [size.x, size.y, size.z])

# ------------ Pipe/Portal Auto-Config ------------

func _auto_configure_transport_tile(pos: Vector3i, tile_id: StringName) -> void:
	# When a transport tile is placed, check if we should auto-create a connection
	if not _current_chunk_set or not _current_manifest:
		return
	
	# Get tile definition to check transport type
	var tile_def := _current_palette.get_tile(tile_id) if _current_palette else null
	if not tile_def:
		return
	
	var transport_type: String = tile_def.custom_properties.get("transport_type", "")
	if transport_type.is_empty():
		return
	
	# Create a new pipe connection for this tile
	var connection := XtremePipeConnection.new()
	connection.connection_id = StringName("conn_%d_%d_%d" % [pos.x, pos.y, pos.z])
	connection.grid_position = pos
	connection.world_position = Vector3(pos) * _grid_settings.get_cell_size()
	connection.display_name = tile_def.display_name
	
	# Set pipe type from tile
	match transport_type:
		"pipe": connection.pipe_type = XtremePipeConnection.PipeType.PIPE
		"door": connection.pipe_type = XtremePipeConnection.PipeType.DOOR
		"hole": connection.pipe_type = XtremePipeConnection.PipeType.HOLE
		"warp": connection.pipe_type = XtremePipeConnection.PipeType.WARP_ZONE
		_: connection.pipe_type = XtremePipeConnection.PipeType.CUSTOM
	
	connection.requires_input = tile_def.custom_properties.get("requires_input", true)
	connection.input_direction = tile_def.custom_properties.get("input_direction", 0)
	
	# Add to chunk set (destination will need to be configured manually)
	_current_chunk_set.add_connection(connection)
	_set_status("Transport tile placed - configure destination in Level Overview")

func _auto_configure_goal_tile(pos: Vector3i, tile_id: StringName) -> void:
	if not _current_chunk_set:
		return
	
	var tile_def := _current_palette.get_tile(tile_id) if _current_palette else null
	if not tile_def:
		return
	
	var goal_type_str: String = tile_def.custom_properties.get("goal_type", "standard")
	var is_secret: bool = tile_def.custom_properties.get("is_secret_exit", false)
	
	var goal: XtremeGoalPortal
	if is_secret or goal_type_str == "secret":
		goal = XtremeGoalPortal.create_secret(pos)
	else:
		goal = XtremeGoalPortal.create_standard(pos)
	
	goal.returns_to = tile_def.custom_properties.get("returns_to", "world_map")
	
	_current_chunk_set.add_goal_portal(goal)
	_set_status("Goal portal added to chunk set")

func _auto_configure_spawn_tile(pos: Vector3i, tile_id: StringName) -> void:
	if not _current_chunk_set:
		return
	
	var tile_def := _current_palette.get_tile(tile_id) if _current_palette else null
	if not tile_def:
		return
	
	var cell_size := _grid_settings.get_cell_size()
	
	var spawn := XtremeSpawnPoint.new()
	spawn.spawn_id = StringName("spawn_%d_%d_%d" % [pos.x, pos.y, pos.z])
	spawn.grid_position = pos
	# Calculate world position: center of cell horizontally, top of cell vertically
	spawn.position = Vector3(
		pos.x * cell_size.x + cell_size.x / 2.0,
		pos.y * cell_size.y + cell_size.y,  # Top of cell (player stands on it)
		pos.z * cell_size.z + cell_size.z / 2.0
	)
	spawn.is_default = tile_def.custom_properties.get("is_default", false)
	spawn.display_name = "Spawn Point"
	
	# If this is marked as default, or it's the first spawn point, make it default
	if spawn.is_default or _current_chunk_set.spawn_points.is_empty():
		# Clear default from other spawn points
		for existing_spawn in _current_chunk_set.spawn_points:
			existing_spawn.is_default = false
		spawn.is_default = true
	
	_current_chunk_set.add_spawn_point(spawn)
	_set_status("Spawn point added at world position: %s" % spawn.position)

# ============ PHASE 4: Path Systems ============

func _set_path_edit_mode(mode: int) -> void:
	_path_edit_mode = mode
	var mode_names := ["Grind Rail", "Roller Coaster", "Light Dash"]
	_set_status("Path Type: %s" % mode_names[mode])
	_update_path_properties_visibility()
	_clear_current_path()

func _set_path_tool(tool: int) -> void:
	_path_tool_mode = tool
	var tool_names := ["Place", "Select", "Edit", "Delete"]
	_set_status("Path Tool: %s" % tool_names[tool])

func _update_path_properties_visibility() -> void:
	if not _main_dock:
		return
	
	var rail_props := _main_dock.find_child("RailProperties", true, false)
	var coaster_props := _main_dock.find_child("CoasterProperties", true, false)
	var dash_props := _main_dock.find_child("DashProperties", true, false)
	
	if rail_props: rail_props.visible = (_path_edit_mode == 0)
	if coaster_props: coaster_props.visible = (_path_edit_mode == 1)
	if dash_props: dash_props.visible = (_path_edit_mode == 2)

func _clear_current_path() -> void:
	_current_rail = null
	_current_coaster = null
	_current_dash_trail = null
	_path_drawing = false
	_update_path_preview()

func _on_new_path() -> void:
	_clear_current_path()
	_path_drawing = true
	
	match _path_edit_mode:
		0:  # Rail
			_current_rail = XtremeGrindRail.new()
			_current_rail.rail_id = StringName("rail_%d" % randi())
			_current_rail.display_name = "Grind Rail %d" % (_rails.size() + 1)
			_apply_rail_properties()
			_set_status("New Grind Rail - Click to place points, then Finish Path")
		1:  # Coaster
			_current_coaster = XtremeRollerCoaster.new()
			_current_coaster.coaster_id = StringName("coaster_%d" % randi())
			_current_coaster.display_name = "Roller Coaster %d" % (_coasters.size() + 1)
			_apply_coaster_properties()
			_set_status("New Roller Coaster - Click to place points, then Finish Path")
		2:  # Light Dash
			_current_dash_trail = XtremeLightDashTrail.new()
			_current_dash_trail.trail_id = StringName("dash_%d" % randi())
			_current_dash_trail.display_name = "Light Dash %d" % (_dash_trails.size() + 1)
			_apply_dash_properties()
			_set_status("New Light Dash Trail - Click to place rings, then Finish Path")

func _apply_rail_properties() -> void:
	if not _current_rail or not _main_dock:
		return
	
	var speed_spin := _main_dock.find_child("RailSpeedSpin", true, false) as SpinBox
	var allow_jump := _main_dock.find_child("RailAllowJump", true, false) as CheckBox
	var allow_crouch := _main_dock.find_child("RailAllowCrouch", true, false) as CheckBox
	
	if speed_spin: _current_rail.speed_multiplier = speed_spin.value
	if allow_jump: _current_rail.allow_jump_off = allow_jump.button_pressed
	if allow_crouch: _current_rail.allow_crouch_boost = allow_crouch.button_pressed

func _apply_coaster_properties() -> void:
	if not _current_coaster or not _main_dock:
		return
	
	var speed_spin := _main_dock.find_child("CoasterSpeedSpin", true, false) as SpinBox
	var locked := _main_dock.find_child("CoasterLocked", true, false) as CheckBox
	
	if speed_spin: _current_coaster.base_speed = speed_spin.value
	if locked: _current_coaster.locked_ride = locked.button_pressed

func _apply_dash_properties() -> void:
	if not _current_dash_trail or not _main_dock:
		return
	
	var speed_spin := _main_dock.find_child("DashSpeedSpin", true, false) as SpinBox
	var dedicated := _main_dock.find_child("DashDedicated", true, false) as CheckBox
	var works_regular := _main_dock.find_child("DashWorksRegular", true, false) as CheckBox
	
	if speed_spin: _current_dash_trail.dash_speed = speed_spin.value
	if works_regular: _current_dash_trail.works_with_regular_rings = works_regular.button_pressed

func _on_finish_path() -> void:
	if not _path_drawing:
		_set_status("No path being drawn")
		return
	
	match _path_edit_mode:
		0:  # Rail
			if _current_rail and _current_rail.control_points.size() >= 2:
				_current_rail.calculate_occupied_cells(_grid_settings.get_cell_size())
				_rails.append(_current_rail)
				_set_status("Grind Rail saved with %d points" % _current_rail.control_points.size())
			else:
				_set_status("Rail needs at least 2 points")
		1:  # Coaster
			if _current_coaster and _current_coaster.control_points.size() >= 2:
				_current_coaster.calculate_duration()
				_coasters.append(_current_coaster)
				_set_status("Roller Coaster saved with %d points (%.1fs ride)" % [_current_coaster.control_points.size(), _current_coaster.ride_duration])
			else:
				_set_status("Coaster needs at least 2 points")
		2:  # Light Dash
			if _current_dash_trail and _current_dash_trail.ring_positions.size() >= 2:
				_dash_trails.append(_current_dash_trail)
				_set_status("Light Dash saved with %d rings" % _current_dash_trail.ring_positions.size())
			else:
				_set_status("Dash trail needs at least 2 rings")
	
	_update_path_list()
	_clear_current_path()

func _on_close_path_loop() -> void:
	match _path_edit_mode:
		0:
			if _current_rail:
				_current_rail.is_loop = true
				_set_status("Rail loop enabled")
		1:
			if _current_coaster:
				_current_coaster.is_loop = true
				_set_status("Coaster loop enabled")
		2:
			if _current_dash_trail:
				_current_dash_trail.is_loop = true
				_set_status("Dash trail loop enabled")

func _on_auto_fill_path() -> void:
	if _path_edit_mode == 2 and _current_dash_trail:
		_current_dash_trail.auto_fill_gaps()
		_set_status("Auto-filled gaps: now %d rings" % _current_dash_trail.ring_positions.size())
		_update_path_preview()

func _on_path_list_selected(index: int) -> void:
	_selected_path_index = index
	
	# Calculate which array and index
	var rail_count := _rails.size()
	var coaster_count := _coasters.size()
	
	if index < rail_count:
		_set_status("Selected: %s" % _rails[index].display_name)
	elif index < rail_count + coaster_count:
		var coaster_idx := index - rail_count
		_set_status("Selected: %s" % _coasters[coaster_idx].display_name)
	else:
		var dash_idx := index - rail_count - coaster_count
		if dash_idx < _dash_trails.size():
			_set_status("Selected: %s" % _dash_trails[dash_idx].display_name)

func _update_path_list() -> void:
	var path_list := _main_dock.find_child("PathList", true, false) as ItemList
	if not path_list:
		return
	
	path_list.clear()
	
	for rail in _rails:
		path_list.add_item("[Rail] %s" % rail.display_name)
	
	for coaster in _coasters:
		path_list.add_item("[Coaster] %s" % coaster.display_name)
	
	for trail in _dash_trails:
		path_list.add_item("[Dash] %s" % trail.display_name)

func _update_path_preview() -> void:
	# Clear existing preview
	if _path_preview_mesh and is_instance_valid(_path_preview_mesh):
		_path_preview_mesh.queue_free()
		_path_preview_mesh = null
	
	if not _path_drawing:
		return
	
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return
	
	_path_preview_mesh = MeshInstance3D.new()
	_path_preview_mesh.name = "XtremePathPreview_TEMP"
	
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	
	match _path_edit_mode:
		0:  # Rail
			if _current_rail and _current_rail.control_points.size() >= 2:
				var cell_size := _grid_settings.get_cell_size()
				for i in range(20):
					var t1 := float(i) / 20.0
					var t2 := float(i + 1) / 20.0
					var p1 := _current_rail.get_point_at(t1) * cell_size
					var p2 := _current_rail.get_point_at(t2) * cell_size
					im.surface_set_color(Color.YELLOW)
					im.surface_add_vertex(p1)
					im.surface_add_vertex(p2)
		1:  # Coaster
			if _current_coaster and _current_coaster.control_points.size() >= 2:
				for i in range(50):
					var t1 := float(i) / 50.0
					var t2 := float(i + 1) / 50.0
					var p1 := _current_coaster.get_point_at(t1)
					var p2 := _current_coaster.get_point_at(t2)
					im.surface_set_color(Color.RED)
					im.surface_add_vertex(p1)
					im.surface_add_vertex(p2)
		2:  # Light Dash
			if _current_dash_trail and _current_dash_trail.ring_positions.size() >= 2:
				var cell_size := _grid_settings.get_cell_size()
				for i in range(_current_dash_trail.ring_positions.size() - 1):
					var p1 := _current_dash_trail.get_ring_world_position(i, cell_size)
					var p2 := _current_dash_trail.get_ring_world_position(i + 1, cell_size)
					im.surface_set_color(Color.CYAN)
					im.surface_add_vertex(p1)
					im.surface_add_vertex(p2)
	
	im.surface_end()
	_path_preview_mesh.mesh = im
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	_path_preview_mesh.material_override = mat
	
	scene_root.add_child(_path_preview_mesh)

func _add_path_point(world_pos: Vector3, grid_pos: Vector3i) -> void:
	if not _path_drawing:
		return
	
	match _path_edit_mode:
		0:  # Rail - uses grid coordinates converted to path coordinates
			if _current_rail:
				var path_pos := Vector3(grid_pos)
				_current_rail.add_control_point(path_pos)
				_set_status("Rail point %d added" % _current_rail.control_points.size())
		1:  # Coaster - uses world coordinates
			if _current_coaster:
				_current_coaster.add_control_point(world_pos)
				_set_status("Coaster point %d added" % _current_coaster.control_points.size())
		2:  # Light Dash - uses grid coordinates
			if _current_dash_trail:
				var dedicated := true
				var dedicated_check := _main_dock.find_child("DashDedicated", true, false) as CheckBox
				if dedicated_check:
					dedicated = dedicated_check.button_pressed
				_current_dash_trail.add_ring(grid_pos, dedicated)
				_set_status("Ring %d added" % _current_dash_trail.ring_positions.size())
	
	_update_path_preview()
