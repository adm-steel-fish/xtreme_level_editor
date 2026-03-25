@tool
class_name XtremePaintMode
extends XtremeEditorMode

## Paint Mode - Apply material overrides to placed tiles.
## Click on existing tiles to assign materials/colors.
## Supports brush painting, fill, and eyedropper tools.

enum PaintTool { BRUSH, FILL, EYEDROPPER }

var _paint_tool: PaintTool = PaintTool.BRUSH
var _brush_size: int = 1
var _paint_color: Color = Color.WHITE
var _paint_material_path: String = ""
var _paint_roughness: float = 0.5
var _paint_metallic: float = 0.0
var _status_label: Label
var _color_picker: ColorPickerButton
var _material_path_edit: LineEdit
var _roughness_spin: SpinBox
var _metallic_spin: SpinBox
var _is_painting: bool = false


func activate() -> void:
	super.activate()
	set_status("Paint Mode - Click tiles to paint")


func deactivate() -> void:
	_is_painting = false
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
	header.text = "PAINT MODE"
	header.add_theme_font_size_override("font_size", 14)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)

	content.add_child(HSeparator.new())

	# Tool selector
	content.add_child(make_label("Tool:"))
	var tool_row := HBoxContainer.new()
	var tool_group := ButtonGroup.new()

	var brush_btn := Button.new()
	brush_btn.text = "Brush"
	brush_btn.toggle_mode = true
	brush_btn.button_pressed = true
	brush_btn.button_group = tool_group
	brush_btn.pressed.connect(func(): _paint_tool = PaintTool.BRUSH)
	tool_row.add_child(brush_btn)

	var fill_btn := Button.new()
	fill_btn.text = "Fill"
	fill_btn.toggle_mode = true
	fill_btn.button_group = tool_group
	fill_btn.pressed.connect(func(): _paint_tool = PaintTool.FILL)
	tool_row.add_child(fill_btn)

	var eyedropper_btn := Button.new()
	eyedropper_btn.text = "Eyedropper"
	eyedropper_btn.toggle_mode = true
	eyedropper_btn.button_group = tool_group
	eyedropper_btn.pressed.connect(func(): _paint_tool = PaintTool.EYEDROPPER)
	tool_row.add_child(eyedropper_btn)

	content.add_child(tool_row)

	content.add_child(HSeparator.new())

	# Brush size
	var brush_row := HBoxContainer.new()
	brush_row.add_child(make_label("Brush Size:"))
	var brush_spin := SpinBox.new()
	brush_spin.min_value = 1
	brush_spin.max_value = 10
	brush_spin.value = 1
	brush_spin.value_changed.connect(func(v): _brush_size = int(v))
	brush_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brush_row.add_child(brush_spin)
	content.add_child(brush_row)

	content.add_child(HSeparator.new())

	# Material Properties
	content.add_child(_make_section_label("Material Properties"))

	# Color
	content.add_child(make_label("Color:"))
	_color_picker = ColorPickerButton.new()
	_color_picker.color = Color.WHITE
	_color_picker.custom_minimum_size.y = 30
	_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_picker.color_changed.connect(func(c): _paint_color = c)
	content.add_child(_color_picker)

	# Material path (optional override)
	content.add_child(make_label("Material (optional):"))
	var mat_row := HBoxContainer.new()
	_material_path_edit = LineEdit.new()
	_material_path_edit.placeholder_text = "res://materials/..."
	_material_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_material_path_edit.text_changed.connect(func(t): _paint_material_path = t)
	mat_row.add_child(_material_path_edit)
	var browse_btn := Button.new()
	browse_btn.text = "..."
	browse_btn.pressed.connect(_browse_material)
	mat_row.add_child(browse_btn)
	content.add_child(mat_row)

	# Roughness
	var rough_row := HBoxContainer.new()
	rough_row.add_child(make_label("Roughness:"))
	_roughness_spin = SpinBox.new()
	_roughness_spin.min_value = 0.0
	_roughness_spin.max_value = 1.0
	_roughness_spin.step = 0.05
	_roughness_spin.value = 0.5
	_roughness_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roughness_spin.value_changed.connect(func(v): _paint_roughness = v)
	rough_row.add_child(_roughness_spin)
	content.add_child(rough_row)

	# Metallic
	var metal_row := HBoxContainer.new()
	metal_row.add_child(make_label("Metallic:"))
	_metallic_spin = SpinBox.new()
	_metallic_spin.min_value = 0.0
	_metallic_spin.max_value = 1.0
	_metallic_spin.step = 0.05
	_metallic_spin.value = 0.0
	_metallic_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_metallic_spin.value_changed.connect(func(v): _paint_metallic = v)
	metal_row.add_child(_metallic_spin)
	content.add_child(metal_row)

	content.add_child(HSeparator.new())

	# Clear material button
	var clear_btn := Button.new()
	clear_btn.text = "Clear Paint from Selection"
	clear_btn.pressed.connect(_clear_paint_from_selection)
	content.add_child(clear_btn)

	# Status
	content.add_child(HSeparator.new())
	_status_label = Label.new()
	_status_label.text = "Click on tiles to paint them"
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)

	# Tips
	var tips := Label.new()
	tips.text = "Tips:\n- Brush: Click/drag to paint tiles\n- Fill: Click to paint all connected same-type tiles\n- Eyedropper: Click to pick color from tile\n- Paint data is stored as instance properties"
	tips.add_theme_font_size_override("font_size", 11)
	tips.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(tips)

	return scroll


func handle_3d_input(camera: Camera3D, event: InputEvent) -> int:
	if not level_data or not grid_settings:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var from := camera.project_ray_origin(mb.position)
			var dir := camera.project_ray_normal(mb.position)
			var pos := _raycast_to_tile(from, dir)

			if mb.pressed:
				_is_painting = true
				if pos.x >= 0:
					_handle_paint_click(pos)
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			else:
				_is_painting = false

	elif event is InputEventMouseMotion and _is_painting:
		var mm := event as InputEventMouseMotion
		var from := camera.project_ray_origin(mm.position)
		var dir := camera.project_ray_normal(mm.position)
		var pos := _raycast_to_tile(from, dir)

		if pos.x >= 0 and _paint_tool == PaintTool.BRUSH:
			_apply_paint_at(pos)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	# Let scroll wheel through for layer changes
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _handle_paint_click(pos: Vector3i) -> void:
	match _paint_tool:
		PaintTool.BRUSH:
			_apply_paint_at(pos)
		PaintTool.FILL:
			_flood_paint(pos)
		PaintTool.EYEDROPPER:
			_pick_paint_from(pos)


func _apply_paint_at(center: Vector3i) -> void:
	if not level_data:
		return

	var half := _brush_size / 2
	var count := 0
	for x in range(-half, -half + _brush_size):
		for z in range(-half, -half + _brush_size):
			var pos := center + Vector3i(x, 0, z)
			if level_data.has_tile(pos):
				_set_paint_properties(pos)
				count += 1

	if count > 0:
		_set_paint_status("Painted %d tile(s)" % count)
		if grid_visualizer:
			grid_visualizer.rebuild()


func _set_paint_properties(pos: Vector3i) -> void:
	var props := level_data.get_tile_instance_properties(pos)
	props["_paint_color"] = _paint_color.to_html()
	props["_paint_roughness"] = _paint_roughness
	props["_paint_metallic"] = _paint_metallic
	if not _paint_material_path.is_empty():
		props["_material_override"] = _paint_material_path
	else:
		props.erase("_material_override")
	level_data.set_tile_instance_properties(pos, props)


func _flood_paint(start_pos: Vector3i) -> void:
	if not level_data or not level_data.has_tile(start_pos):
		return

	var target_tile := level_data.get_tile(start_pos)
	var visited: Dictionary = {}
	var queue: Array[Vector3i] = [start_pos]
	var count := 0

	while not queue.is_empty():
		var pos: Vector3i = queue.pop_front()
		var key := "%d,%d,%d" % [pos.x, pos.y, pos.z]
		if key in visited:
			continue
		visited[key] = true

		if not level_data.has_tile(pos) or level_data.get_tile(pos) != target_tile:
			continue

		_set_paint_properties(pos)
		count += 1

		# Check 6-connected neighbors
		var directions: Array[Vector3i] = [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
		for dir in directions:
			var neighbor: Vector3i = pos + dir
			var nkey := "%d,%d,%d" % [neighbor.x, neighbor.y, neighbor.z]
			if nkey not in visited:
				queue.append(neighbor)

	if count > 0:
		_set_paint_status("Flood painted %d tile(s)" % count)
		if grid_visualizer:
			grid_visualizer.rebuild()


func _pick_paint_from(pos: Vector3i) -> void:
	if not level_data or not level_data.has_tile(pos):
		_set_paint_status("No tile at position")
		return

	var props := level_data.get_tile_instance_properties(pos)
	if props.has("_paint_color"):
		_paint_color = Color.html(props["_paint_color"])
		if _color_picker:
			_color_picker.color = _paint_color
	if props.has("_paint_roughness"):
		_paint_roughness = props["_paint_roughness"]
		if _roughness_spin:
			_roughness_spin.value = _paint_roughness
	if props.has("_paint_metallic"):
		_paint_metallic = props["_paint_metallic"]
		if _metallic_spin:
			_metallic_spin.value = _paint_metallic
	if props.has("_material_override"):
		_paint_material_path = props["_material_override"]
		if _material_path_edit:
			_material_path_edit.text = _paint_material_path

	_set_paint_status("Picked paint from (%d, %d, %d)" % [pos.x, pos.y, pos.z])


func _clear_paint_from_selection() -> void:
	if not level_data or not plugin:
		return

	# Try to get selection from plugin
	var has_sel = plugin.get("_has_selection")
	if not has_sel:
		_set_paint_status("No selection - use Build mode Select tool first")
		return

	var sel_start: Vector3i = plugin.get("_selection_start")
	var sel_end: Vector3i = plugin.get("_selection_end")
	var min_pos := Vector3i(mini(sel_start.x, sel_end.x), mini(sel_start.y, sel_end.y), mini(sel_start.z, sel_end.z))
	var max_pos := Vector3i(maxi(sel_start.x, sel_end.x), maxi(sel_start.y, sel_end.y), maxi(sel_start.z, sel_end.z))

	var count := 0
	for x in range(min_pos.x, max_pos.x + 1):
		for y in range(min_pos.y, max_pos.y + 1):
			for z in range(min_pos.z, max_pos.z + 1):
				var pos := Vector3i(x, y, z)
				var props := level_data.get_tile_instance_properties(pos)
				var changed := false
				for key in ["_paint_color", "_paint_roughness", "_paint_metallic", "_material_override"]:
					if props.has(key):
						props.erase(key)
						changed = true
				if changed:
					level_data.set_tile_instance_properties(pos, props)
					count += 1

	_set_paint_status("Cleared paint from %d tile(s)" % count)
	if grid_visualizer:
		grid_visualizer.rebuild()


func _raycast_to_tile(origin: Vector3, direction: Vector3) -> Vector3i:
	# Use the plugin's raycast method if available
	if plugin and plugin.has_method("_raycast_grid"):
		return plugin.call("_raycast_grid", origin, direction)
	return Vector3i(-1, -1, -1)


func _browse_material() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres,*.res,*.material", "Material Files")
	dialog.file_selected.connect(func(path: String):
		_paint_material_path = path
		if _material_path_edit:
			_material_path_edit.text = path
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))


func _set_paint_status(text: String) -> void:
	if _status_label:
		_status_label.text = text
	set_status(text)


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	return label
