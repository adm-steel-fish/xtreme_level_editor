@tool
class_name XtremeLogicMode
extends XtremeEditorMode

## Logic Mode - Place triggers and wire them to actions using a visual node graph.
## Triggers appear as colored volumes in the 3D viewport.
## Connections are managed via a list-based UI (with future GraphEdit support).

enum LogicTool { PLACE_TRIGGER, SELECT_TRIGGER, DELETE_TRIGGER }

var _logic_tool: LogicTool = LogicTool.PLACE_TRIGGER
var _trigger_type: XtremeTriggerData.TriggerType = XtremeTriggerData.TriggerType.AREA
var _trigger_radius: float = 3.0
var _trigger_timer_duration: float = 5.0
var _selected_trigger_index: int = -1
var _next_trigger_id: int = 1

# UI elements
var _status_label: Label
var _trigger_list: ItemList
var _connection_list: ItemList
var _trigger_name_edit: LineEdit
var _trigger_radius_spin: SpinBox
var _trigger_timer_spin: SpinBox
var _action_type_selector: OptionButton
var _target_id_edit: LineEdit
var _delay_spin: SpinBox

# 3D visualization
var _trigger_preview_meshes: Array[MeshInstance3D] = []
var _preview_root: Node3D


func activate() -> void:
	super.activate()
	_rebuild_trigger_previews()
	set_status("Logic Mode - Place and configure triggers")


func deactivate() -> void:
	_cleanup_previews()
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
	header.text = "LOGIC MODE"
	header.add_theme_font_size_override("font_size", 14)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)

	content.add_child(HSeparator.new())

	# Tool selector
	content.add_child(make_label("Tool:"))
	var tool_row := HBoxContainer.new()
	var tool_group := ButtonGroup.new()

	var place_btn := Button.new()
	place_btn.text = "Place"
	place_btn.toggle_mode = true
	place_btn.button_pressed = true
	place_btn.button_group = tool_group
	place_btn.pressed.connect(func(): _logic_tool = LogicTool.PLACE_TRIGGER)
	tool_row.add_child(place_btn)

	var select_btn := Button.new()
	select_btn.text = "Select"
	select_btn.toggle_mode = true
	select_btn.button_group = tool_group
	select_btn.pressed.connect(func(): _logic_tool = LogicTool.SELECT_TRIGGER)
	tool_row.add_child(select_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.toggle_mode = true
	delete_btn.button_group = tool_group
	delete_btn.pressed.connect(func(): _logic_tool = LogicTool.DELETE_TRIGGER)
	tool_row.add_child(delete_btn)

	content.add_child(tool_row)

	content.add_child(HSeparator.new())

	# Trigger type
	content.add_child(_make_section_label("New Trigger"))
	content.add_child(make_label("Type:"))
	var type_selector := OptionButton.new()
	type_selector.add_item("Area (Enter Zone)", 0)
	type_selector.add_item("Touch (Hit Tile)", 1)
	type_selector.add_item("Timer (Delayed)", 2)
	type_selector.add_item("Condition (Expression)", 3)
	type_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_selector.item_selected.connect(func(idx):
		_trigger_type = idx as XtremeTriggerData.TriggerType
		_update_trigger_params_visibility()
	)
	content.add_child(type_selector)

	# Trigger name
	content.add_child(make_label("Name:"))
	_trigger_name_edit = LineEdit.new()
	_trigger_name_edit.placeholder_text = "trigger_door_open"
	_trigger_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_trigger_name_edit)

	# Trigger radius (for area triggers)
	var radius_row := HBoxContainer.new()
	radius_row.name = "RadiusRow"
	radius_row.add_child(make_label("Radius:"))
	_trigger_radius_spin = SpinBox.new()
	_trigger_radius_spin.min_value = 1.0
	_trigger_radius_spin.max_value = 50.0
	_trigger_radius_spin.step = 0.5
	_trigger_radius_spin.value = 3.0
	_trigger_radius_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trigger_radius_spin.value_changed.connect(func(v): _trigger_radius = v)
	radius_row.add_child(_trigger_radius_spin)
	content.add_child(radius_row)

	# Timer duration (for timer triggers)
	var timer_row := HBoxContainer.new()
	timer_row.name = "TimerRow"
	timer_row.add_child(make_label("Duration:"))
	_trigger_timer_spin = SpinBox.new()
	_trigger_timer_spin.min_value = 0.1
	_trigger_timer_spin.max_value = 300.0
	_trigger_timer_spin.step = 0.5
	_trigger_timer_spin.value = 5.0
	_trigger_timer_spin.suffix = "s"
	_trigger_timer_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trigger_timer_spin.value_changed.connect(func(v): _trigger_timer_duration = v)
	timer_row.add_child(_trigger_timer_spin)
	content.add_child(timer_row)

	content.add_child(HSeparator.new())

	# Triggers list
	content.add_child(_make_section_label("Triggers"))
	_trigger_list = ItemList.new()
	_trigger_list.custom_minimum_size.y = 100
	_trigger_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trigger_list.item_selected.connect(_on_trigger_selected)
	content.add_child(_trigger_list)

	var trigger_btns := HBoxContainer.new()
	var remove_trigger_btn := Button.new()
	remove_trigger_btn.text = "Remove Selected"
	remove_trigger_btn.pressed.connect(_remove_selected_trigger)
	trigger_btns.add_child(remove_trigger_btn)
	content.add_child(trigger_btns)

	content.add_child(HSeparator.new())

	# Connections
	content.add_child(_make_section_label("Connections"))

	content.add_child(make_label("Action:"))
	_action_type_selector = OptionButton.new()
	_action_type_selector.add_item("Activate", 0)
	_action_type_selector.add_item("Deactivate", 1)
	_action_type_selector.add_item("Toggle", 2)
	_action_type_selector.add_item("Spawn", 3)
	_action_type_selector.add_item("Destroy", 4)
	_action_type_selector.add_item("Move", 5)
	_action_type_selector.add_item("Play Sound", 6)
	_action_type_selector.add_item("Play Anim", 7)
	_action_type_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_action_type_selector)

	content.add_child(make_label("Target ID:"))
	_target_id_edit = LineEdit.new()
	_target_id_edit.placeholder_text = "tile key (e.g. 5,3,8) or object ID"
	_target_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_target_id_edit)

	var delay_row := HBoxContainer.new()
	delay_row.add_child(make_label("Delay:"))
	_delay_spin = SpinBox.new()
	_delay_spin.min_value = 0.0
	_delay_spin.max_value = 60.0
	_delay_spin.step = 0.1
	_delay_spin.value = 0.0
	_delay_spin.suffix = "s"
	_delay_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delay_row.add_child(_delay_spin)
	content.add_child(delay_row)

	var add_conn_btn := Button.new()
	add_conn_btn.text = "Add Connection"
	add_conn_btn.pressed.connect(_add_connection)
	content.add_child(add_conn_btn)

	_connection_list = ItemList.new()
	_connection_list.custom_minimum_size.y = 80
	_connection_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_connection_list)

	var conn_btns := HBoxContainer.new()
	var remove_conn_btn := Button.new()
	remove_conn_btn.text = "Remove Connection"
	remove_conn_btn.pressed.connect(_remove_selected_connection)
	conn_btns.add_child(remove_conn_btn)
	content.add_child(conn_btns)

	content.add_child(HSeparator.new())

	# Status
	_status_label = Label.new()
	_status_label.text = "Click in viewport to place triggers"
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)

	return scroll


func handle_3d_input(camera: Camera3D, event: InputEvent) -> int:
	if not level_data or not grid_settings:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var from := camera.project_ray_origin(mb.position)
			var dir := camera.project_ray_normal(mb.position)
			var pos := _raycast_to_grid(from, dir)

			if pos.x >= 0:
				match _logic_tool:
					LogicTool.PLACE_TRIGGER:
						_place_trigger_at(pos)
						return EditorPlugin.AFTER_GUI_INPUT_STOP
					LogicTool.SELECT_TRIGGER:
						_select_trigger_at(pos)
						return EditorPlugin.AFTER_GUI_INPUT_STOP
					LogicTool.DELETE_TRIGGER:
						_delete_trigger_at(pos)
						return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _place_trigger_at(pos: Vector3i) -> void:
	if not level_data:
		return

	var trigger := XtremeTriggerData.new()
	trigger.trigger_id = _generate_trigger_id()
	trigger.trigger_type = _trigger_type
	trigger.position = pos
	trigger.radius = _trigger_radius
	trigger.timer_duration = _trigger_timer_duration

	if _trigger_name_edit and not _trigger_name_edit.text.is_empty():
		trigger.display_name = _trigger_name_edit.text
	else:
		trigger.display_name = "%s_%s" % [
			XtremeTriggerData.TriggerType.keys()[_trigger_type].to_lower(),
			trigger.trigger_id
		]

	# Set color based on type
	match _trigger_type:
		XtremeTriggerData.TriggerType.AREA:
			trigger.editor_color = Color(1.0, 0.5, 0.0, 0.4)
		XtremeTriggerData.TriggerType.TOUCH:
			trigger.editor_color = Color(0.0, 1.0, 0.5, 0.4)
		XtremeTriggerData.TriggerType.TIMER:
			trigger.editor_color = Color(0.0, 0.5, 1.0, 0.4)
		XtremeTriggerData.TriggerType.CONDITION:
			trigger.editor_color = Color(1.0, 0.0, 1.0, 0.4)

	level_data._triggers.append(trigger)
	_refresh_trigger_list()
	_rebuild_trigger_previews()
	_set_logic_status("Placed %s at (%d, %d, %d)" % [trigger.display_name, pos.x, pos.y, pos.z])


func _select_trigger_at(pos: Vector3i) -> void:
	if not level_data:
		return

	# Find the closest trigger to this position
	var closest_idx := -1
	var closest_dist := 999999.0
	for i in range(level_data._triggers.size()):
		var t: XtremeTriggerData = level_data._triggers[i]
		var dist := Vector3(pos).distance_to(Vector3(t.position))
		if dist < t.radius and dist < closest_dist:
			closest_dist = dist
			closest_idx = i

	if closest_idx >= 0:
		_selected_trigger_index = closest_idx
		if _trigger_list:
			_trigger_list.select(closest_idx)
		_on_trigger_selected(closest_idx)
		_set_logic_status("Selected: %s" % level_data._triggers[closest_idx].display_name)
	else:
		_set_logic_status("No trigger at this position")


func _delete_trigger_at(pos: Vector3i) -> void:
	if not level_data:
		return

	for i in range(level_data._triggers.size() - 1, -1, -1):
		var t: XtremeTriggerData = level_data._triggers[i]
		if Vector3(pos).distance_to(Vector3(t.position)) < t.radius:
			# Also remove any connections referencing this trigger
			var trigger_id := t.trigger_id
			level_data._logic_connections = level_data._logic_connections.filter(
				func(c: XtremeLogicConnection): return c.source_id != trigger_id
			)
			level_data._triggers.remove_at(i)
			_refresh_trigger_list()
			_refresh_connection_list()
			_rebuild_trigger_previews()
			_set_logic_status("Deleted trigger")
			return

	_set_logic_status("No trigger at this position")


func _generate_trigger_id() -> String:
	var id := "trigger_%d" % _next_trigger_id
	_next_trigger_id += 1
	return id


func _on_trigger_selected(index: int) -> void:
	_selected_trigger_index = index
	_refresh_connection_list()

	if level_data and index >= 0 and index < level_data._triggers.size():
		var t: XtremeTriggerData = level_data._triggers[index]
		_set_logic_status("Selected: %s (type: %s)" % [
			t.display_name,
			XtremeTriggerData.TriggerType.keys()[t.trigger_type]
		])


func _remove_selected_trigger() -> void:
	if not level_data or _selected_trigger_index < 0:
		return
	if _selected_trigger_index >= level_data._triggers.size():
		return

	var trigger_id := level_data._triggers[_selected_trigger_index].trigger_id
	level_data._triggers.remove_at(_selected_trigger_index)

	# Remove associated connections
	level_data._logic_connections = level_data._logic_connections.filter(
		func(c: XtremeLogicConnection): return c.source_id != trigger_id
	)

	_selected_trigger_index = -1
	_refresh_trigger_list()
	_refresh_connection_list()
	_rebuild_trigger_previews()
	_set_logic_status("Trigger removed")


func _add_connection() -> void:
	if not level_data or _selected_trigger_index < 0:
		_set_logic_status("Select a trigger first")
		return
	if _selected_trigger_index >= level_data._triggers.size():
		return

	var source := level_data._triggers[_selected_trigger_index]
	var target_id := _target_id_edit.text if _target_id_edit else ""
	if target_id.is_empty():
		_set_logic_status("Enter a target ID")
		return

	var connection := XtremeLogicConnection.new()
	connection.source_id = source.trigger_id
	connection.target_id = target_id
	connection.action_type = _action_type_selector.get_selected_id() as XtremeLogicConnection.ActionType
	connection.delay = _delay_spin.value if _delay_spin else 0.0
	connection.display_name = "%s -> %s (%s)" % [
		source.display_name,
		target_id,
		XtremeLogicConnection.ActionType.keys()[connection.action_type]
	]

	level_data._logic_connections.append(connection)
	source.connected_actions.append(connection.target_id)
	_refresh_connection_list()
	_set_logic_status("Connection added")


func _remove_selected_connection() -> void:
	if not level_data or not _connection_list:
		return
	var selected := _connection_list.get_selected_items()
	if selected.is_empty():
		return

	# Get connections for the selected trigger
	if _selected_trigger_index < 0 or _selected_trigger_index >= level_data._triggers.size():
		return

	var source_id := level_data._triggers[_selected_trigger_index].trigger_id
	var trigger_connections: Array[int] = []
	for i in range(level_data._logic_connections.size()):
		if level_data._logic_connections[i].source_id == source_id:
			trigger_connections.append(i)

	var sel_idx: int = selected[0]
	if sel_idx < trigger_connections.size():
		level_data._logic_connections.remove_at(trigger_connections[sel_idx])
		_refresh_connection_list()
		_set_logic_status("Connection removed")


func _refresh_trigger_list() -> void:
	if not _trigger_list or not level_data:
		return
	_trigger_list.clear()
	for trigger in level_data._triggers:
		var type_name: String = XtremeTriggerData.TriggerType.keys()[trigger.trigger_type]
		_trigger_list.add_item("%s [%s] @ (%d,%d,%d)" % [
			trigger.display_name, type_name,
			trigger.position.x, trigger.position.y, trigger.position.z
		])


func _refresh_connection_list() -> void:
	if not _connection_list or not level_data:
		return
	_connection_list.clear()

	if _selected_trigger_index < 0 or _selected_trigger_index >= level_data._triggers.size():
		return

	var source_id := level_data._triggers[_selected_trigger_index].trigger_id
	for conn in level_data._logic_connections:
		if conn.source_id == source_id:
			var action_name: String = XtremeLogicConnection.ActionType.keys()[conn.action_type]
			_connection_list.add_item("-> %s [%s] (delay: %.1fs)" % [
				conn.target_id, action_name, conn.delay
			])


func _rebuild_trigger_previews() -> void:
	_cleanup_previews()

	if not level_data or not grid_settings:
		return

	var scene_root := get_scene_root()
	if not scene_root:
		return

	_preview_root = Node3D.new()
	_preview_root.name = "XtremeTriggerPreviews_TEMP"
	scene_root.add_child(_preview_root)

	var cell_size := grid_settings.get_cell_size()

	for i in range(level_data._triggers.size()):
		var trigger: XtremeTriggerData = level_data._triggers[i]
		var mesh_inst := MeshInstance3D.new()

		var sphere := SphereMesh.new()
		sphere.radius = trigger.radius * cell_size.x
		sphere.height = trigger.radius * cell_size.y * 2.0
		mesh_inst.mesh = sphere

		var mat := StandardMaterial3D.new()
		mat.albedo_color = trigger.editor_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_inst.material_override = mat

		mesh_inst.position = Vector3(
			trigger.position.x * cell_size.x + cell_size.x * 0.5,
			trigger.position.y * cell_size.y + cell_size.y * 0.5,
			trigger.position.z * cell_size.z + cell_size.z * 0.5
		)

		# Highlight selected trigger
		if i == _selected_trigger_index:
			mat.albedo_color.a = 0.7

		_preview_root.add_child(mesh_inst)
		_trigger_preview_meshes.append(mesh_inst)


func _cleanup_previews() -> void:
	for mesh in _trigger_preview_meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	_trigger_preview_meshes.clear()
	if _preview_root and is_instance_valid(_preview_root):
		_preview_root.queue_free()
		_preview_root = null


func _raycast_to_grid(origin: Vector3, direction: Vector3) -> Vector3i:
	if plugin and plugin.has_method("_raycast_grid"):
		return plugin.call("_raycast_grid", origin, direction)
	return Vector3i(-1, -1, -1)


func _update_trigger_params_visibility() -> void:
	# Could show/hide radius vs timer rows based on type
	pass


func _set_logic_status(text: String) -> void:
	if _status_label:
		_status_label.text = text
	set_status(text)


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	return label
