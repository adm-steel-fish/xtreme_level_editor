extends Control
class_name XtremeResultsScreen
## Animated level-complete tally screen.
## Connects to XtremeLevelCompletion signals for score breakdown and rank display.

#region Configuration
@export_group("Layout")
@export var panel_width: float = 400.0
@export var panel_height: float = 320.0
@export var row_height: float = 32.0

@export_group("Colors")
@export var bg_color: Color = Color(0.05, 0.05, 0.1, 0.85)
@export var header_color: Color = Color(1.0, 0.85, 0.0)
@export var label_color: Color = Color(0.7, 0.7, 0.8)
@export var value_color: Color = Color.WHITE
@export var rank_color_s: Color = Color(1.0, 0.85, 0.0)
@export var rank_color_a: Color = Color(0.3, 0.8, 1.0)
@export var rank_color_b: Color = Color(0.3, 1.0, 0.3)
@export var rank_color_default: Color = Color.WHITE

@export_group("Animation")
@export var appear_duration: float = 0.3
@export var row_stagger: float = 0.15
#endregion

#region Internal
var _level_completion: XtremeLevelCompletion
var _game_manager: XtremeGameManager

var _panel: PanelContainer
var _vbox: VBoxContainer
var _header_label: Label
var _row_container: VBoxContainer
var _rank_label: Label
var _continue_label: Label

var _tally_rows: Dictionary = {}  # category -> {label, value_label}
var _showing: bool = false
var _tally_done: bool = false
#endregion


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	call_deferred("_find_and_connect")


func _input(event: InputEvent) -> void:
	if not _showing or not _tally_done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_dismiss()
	elif event is InputEventJoypadButton and event.pressed:
		_dismiss()


#region UI Construction
func _build_ui() -> void:
	# Centered panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-panel_width * 0.5, -panel_height * 0.5)
	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Style the panel background
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	_panel.add_theme_stylebox_override("panel", style)

	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_vbox)

	# Header
	_header_label = Label.new()
	_header_label.text = "LEVEL COMPLETE"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 28)
	_header_label.add_theme_color_override("font_color", header_color)
	_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_header_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(spacer)

	# Row container
	_row_container = VBoxContainer.new()
	_row_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_row_container)

	# Rank display
	var rank_spacer := Control.new()
	rank_spacer.custom_minimum_size = Vector2(0, 16)
	rank_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(rank_spacer)

	_rank_label = Label.new()
	_rank_label.text = ""
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_label.add_theme_font_size_override("font_size", 48)
	_rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_rank_label)

	# Continue prompt
	_continue_label = Label.new()
	_continue_label.text = "Press any button to continue"
	_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_label.add_theme_font_size_override("font_size", 14)
	_continue_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue_label.visible = false
	_vbox.add_child(_continue_label)

	add_child(_panel)
#endregion


#region Connection
func _find_and_connect() -> void:
	var tree := get_tree()
	if not tree:
		return

	var gm := tree.get_first_node_in_group("xtreme_game_manager")
	if gm is XtremeGameManager:
		_game_manager = gm
		_level_completion = _game_manager.level_completion

	if _level_completion:
		_level_completion.tally_started.connect(_on_tally_started)
		_level_completion.tally_progress.connect(_on_tally_progress)
		_level_completion.tally_completed.connect(_on_tally_completed)
		_level_completion.rank_calculated.connect(_on_rank_calculated)

	if _game_manager:
		_game_manager.level_completed.connect(_on_level_completed)
#endregion


#region Display
func _on_level_completed(results: Dictionary) -> void:
	_show(results)
	# Start animated tally after a brief delay
	if _level_completion:
		var tree := get_tree()
		if tree:
			await tree.create_timer(0.5).timeout
		if is_instance_valid(self) and _level_completion:
			_level_completion.start_tally()


func _show(results: Dictionary) -> void:
	_showing = true
	_tally_done = false
	_clear_rows()

	# Populate categories
	var time_str := XtremeLevelCompletion.format_time(results.get("time", 0.0))
	_add_row("time_display", "TIME", time_str)

	if results.has("rings"):
		_add_row("rings", "RING BONUS", "0")
	if results.has("time_bonus"):
		_add_row("time_bonus", "TIME BONUS", "0")
	if results.has("no_damage"):
		_add_row("no_damage", "NO DAMAGE", "0")
	if results.has("perfect_rings"):
		_add_row("perfect_rings", "PERFECT RINGS", "0")
	if results.has("secret_exit"):
		_add_row("secret_exit", "SECRET EXIT", "0")
	_add_row("total", "TOTAL", "0")

	_rank_label.text = ""
	_continue_label.visible = false
	visible = true

	# Animate panel in
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.9
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, appear_duration)
	tween.tween_property(_panel, "scale", Vector2.ONE, appear_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _dismiss() -> void:
	_showing = false
	visible = false
	if _game_manager:
		_game_manager.return_to_world_map()
#endregion


#region Tally Callbacks
func _on_tally_started() -> void:
	pass


func _on_tally_progress(category: String, current: int, _target: int) -> void:
	if category in _tally_rows:
		_tally_rows[category]["value_label"].text = XtremeLevelCompletion.format_score(current)

	# Update total
	var running_total := 0
	for key in _tally_rows:
		if key == "total" or key == "time_display":
			continue
		var val_text: String = _tally_rows[key]["value_label"].text
		var cleaned := val_text.replace(",", "")
		if cleaned.is_valid_int():
			running_total += cleaned.to_int()
	if "total" in _tally_rows:
		_tally_rows["total"]["value_label"].text = XtremeLevelCompletion.format_score(running_total)


func _on_tally_completed(results: Dictionary) -> void:
	_tally_done = true
	# Set final total
	if "total" in _tally_rows and results.has("total"):
		_tally_rows["total"]["value_label"].text = XtremeLevelCompletion.format_score(results["total"])
	_continue_label.visible = true


func _on_rank_calculated(rank: String, _score: int) -> void:
	_rank_label.text = rank
	match rank:
		"S":
			_rank_label.add_theme_color_override("font_color", rank_color_s)
		"A":
			_rank_label.add_theme_color_override("font_color", rank_color_a)
		"B":
			_rank_label.add_theme_color_override("font_color", rank_color_b)
		_:
			_rank_label.add_theme_color_override("font_color", rank_color_default)

	# Scale-in animation for rank
	_rank_label.scale = Vector2.ONE * 2.0
	var tween := create_tween()
	tween.tween_property(_rank_label, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
#endregion


#region Row Management
func _add_row(key: String, label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, row_height)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", label_color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 18)
	val.add_theme_color_override("font_color", value_color)
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val)

	_row_container.add_child(row)
	_tally_rows[key] = {"row": row, "label": lbl, "value_label": val}


func _clear_rows() -> void:
	for child in _row_container.get_children():
		child.queue_free()
	_tally_rows.clear()
#endregion
