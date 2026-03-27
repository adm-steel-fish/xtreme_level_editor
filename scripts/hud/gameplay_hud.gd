extends CanvasLayer
class_name XtremeGameplayHUD
## In-game HUD displaying rings, score, time, boost meter, and power-up slot.
## Connects to PlayerController signals and XtremeGameManager for live updates.

#region Configuration
@export_group("Layout")
@export var margin: float = 16.0
@export var font_size_large: int = 28
@export var font_size_medium: int = 20
@export var font_size_small: int = 16

@export_group("Colors")
@export var ring_color: Color = Color(1.0, 0.85, 0.0)         # Gold
@export var score_color: Color = Color.WHITE
@export var time_color: Color = Color.WHITE
@export var boost_fill_color: Color = Color(0.2, 0.6, 1.0)    # Blue
@export var boost_bg_color: Color = Color(0.15, 0.15, 0.2, 0.6)
@export var boss_health_color: Color = Color(0.9, 0.2, 0.2)
@export var boss_health_bg_color: Color = Color(0.2, 0.1, 0.1, 0.6)

@export_group("Boost Meter")
@export var boost_bar_width: float = 16.0
@export var boost_bar_height: float = 120.0

@export_group("Boss Health")
@export var boss_bar_width: float = 300.0
@export var boss_bar_height: float = 12.0

@export_group("Animation")
@export var ring_pop_scale: float = 1.4
@export var ring_pop_duration: float = 0.15
#endregion

#region Internal State
var _player: PlayerController
var _game_manager: XtremeGameManager

# UI nodes
var _root: Control
var _ring_label: Label
var _score_label: Label
var _time_label: Label
var _boost_bar: Control
var _boost_fill: ColorRect
var _powerup_icon: TextureRect
var _crystal_label: Label

# Boss health bar
var _boss_container: Control
var _boss_name_label: Label
var _boss_health_bar: Control
var _boss_health_fill: ColorRect

# Ring animation
var _ring_pop_tween: Tween
var _ring_base_scale: Vector2 = Vector2.ONE

# Cached values to reduce updates
var _last_rings: int = -1
var _last_score: int = -1
var _last_boost: float = -1.0
var _boss_visible: bool = false

# Special stage mode
var _special_stage_mode: bool = false
var _special_stage_manager: Node
var _ring_time_label: Label
var _ring_time_warning: bool = false
var _ring_icon_label: Label  # Reference to "RINGS" label to swap text
#endregion


func _ready() -> void:
	layer = 10
	_build_ui()
	call_deferred("_find_and_connect")


func _process(_delta: float) -> void:
	_update_time()
	_update_boost()


#region UI Construction
func _build_ui() -> void:
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_ring_display()
	_build_score_display()
	_build_time_display()
	_build_boost_meter()
	_build_powerup_slot()
	_build_crystal_display()
	_build_boss_health_bar()


func _build_ring_display() -> void:
	var container := HBoxContainer.new()
	container.name = "RingDisplay"
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	container.position = Vector2(margin, margin)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Ring icon (text-based for now; replace with TextureRect when art exists)
	_ring_icon_label = Label.new()
	_ring_icon_label.text = "RINGS"
	_ring_icon_label.add_theme_font_size_override("font_size", font_size_small)
	_ring_icon_label.add_theme_color_override("font_color", ring_color.darkened(0.2))
	_ring_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_ring_icon_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(8, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(spacer)

	_ring_label = Label.new()
	_ring_label.name = "RingCount"
	_ring_label.text = "0"
	_ring_label.add_theme_font_size_override("font_size", font_size_large)
	_ring_label.add_theme_color_override("font_color", ring_color)
	_ring_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_ring_label)

	_root.add_child(container)

	# Special stage: large centered ring-time counter (hidden by default)
	_ring_time_label = Label.new()
	_ring_time_label.name = "RingTimeDisplay"
	_ring_time_label.text = "30"
	_ring_time_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_ring_time_label.position = Vector2(-30, margin + 40)
	_ring_time_label.add_theme_font_size_override("font_size", 48)
	_ring_time_label.add_theme_color_override("font_color", ring_color)
	_ring_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ring_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_time_label.visible = false
	_root.add_child(_ring_time_label)


func _build_score_display() -> void:
	_score_label = Label.new()
	_score_label.name = "ScoreDisplay"
	_score_label.text = "0"
	_score_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_score_label.position = Vector2(margin, margin + 32)
	_score_label.add_theme_font_size_override("font_size", font_size_medium)
	_score_label.add_theme_color_override("font_color", score_color)
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_score_label)


func _build_time_display() -> void:
	_time_label = Label.new()
	_time_label.name = "TimeDisplay"
	_time_label.text = "0:00.00"
	_time_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_time_label.position = Vector2(-40, margin)
	_time_label.add_theme_font_size_override("font_size", font_size_large)
	_time_label.add_theme_color_override("font_color", time_color)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_time_label)


func _build_boost_meter() -> void:
	_boost_bar = Control.new()
	_boost_bar.name = "BoostMeter"
	_boost_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_boost_bar.position = Vector2(-margin - boost_bar_width, margin)
	_boost_bar.custom_minimum_size = Vector2(boost_bar_width, boost_bar_height)
	_boost_bar.size = Vector2(boost_bar_width, boost_bar_height)
	_boost_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background
	var bg := ColorRect.new()
	bg.color = boost_bg_color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boost_bar.add_child(bg)

	# Fill (grows upward from bottom)
	_boost_fill = ColorRect.new()
	_boost_fill.name = "BoostFill"
	_boost_fill.color = boost_fill_color
	_boost_fill.anchor_left = 0.0
	_boost_fill.anchor_right = 1.0
	_boost_fill.anchor_top = 1.0
	_boost_fill.anchor_bottom = 1.0
	_boost_fill.offset_top = 0.0
	_boost_fill.offset_bottom = 0.0
	_boost_fill.offset_left = 0.0
	_boost_fill.offset_right = 0.0
	_boost_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boost_bar.add_child(_boost_fill)

	# Label
	var label := Label.new()
	label.text = "BOOST"
	label.add_theme_font_size_override("font_size", font_size_small)
	label.add_theme_color_override("font_color", boost_fill_color.lightened(0.3))
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.position = Vector2(-2, 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boost_bar.add_child(label)

	_root.add_child(_boost_bar)


func _build_powerup_slot() -> void:
	_powerup_icon = TextureRect.new()
	_powerup_icon.name = "PowerUpSlot"
	_powerup_icon.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_powerup_icon.position = Vector2(margin, -margin - 48)
	_powerup_icon.custom_minimum_size = Vector2(48, 48)
	_powerup_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_powerup_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_powerup_icon.visible = false  # Hidden until Sprint 3 provides power-ups
	_root.add_child(_powerup_icon)


func _build_crystal_display() -> void:
	_crystal_label = Label.new()
	_crystal_label.name = "CrystalDisplay"
	_crystal_label.text = ""
	_crystal_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_crystal_label.position = Vector2(-margin - 100, -margin - 32)
	_crystal_label.add_theme_font_size_override("font_size", font_size_medium)
	_crystal_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	_crystal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crystal_label.visible = false  # Hidden until Sprint 7
	_root.add_child(_crystal_label)


func _build_boss_health_bar() -> void:
	_boss_container = Control.new()
	_boss_container.name = "BossHealth"
	_boss_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_container.position = Vector2(-boss_bar_width * 0.5, margin + 40)
	_boss_container.custom_minimum_size = Vector2(boss_bar_width, boss_bar_height + 24)
	_boss_container.size = Vector2(boss_bar_width, boss_bar_height + 24)
	_boss_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_container.visible = false

	# Boss name
	_boss_name_label = Label.new()
	_boss_name_label.text = ""
	_boss_name_label.add_theme_font_size_override("font_size", font_size_small)
	_boss_name_label.add_theme_color_override("font_color", Color.WHITE)
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_container.add_child(_boss_name_label)

	# Health bar container
	_boss_health_bar = Control.new()
	_boss_health_bar.position = Vector2(0, 20)
	_boss_health_bar.custom_minimum_size = Vector2(boss_bar_width, boss_bar_height)
	_boss_health_bar.size = Vector2(boss_bar_width, boss_bar_height)
	_boss_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var boss_bg := ColorRect.new()
	boss_bg.color = boss_health_bg_color
	boss_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	boss_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_health_bar.add_child(boss_bg)

	_boss_health_fill = ColorRect.new()
	_boss_health_fill.name = "BossHealthFill"
	_boss_health_fill.color = boss_health_color
	_boss_health_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_health_bar.add_child(_boss_health_fill)

	_boss_container.add_child(_boss_health_bar)
	_root.add_child(_boss_container)
#endregion


#region Connection
func _find_and_connect() -> void:
	_find_player()
	_find_game_manager()


func _find_player() -> void:
	var tree := get_tree()
	if not tree:
		return

	for node in tree.get_nodes_in_group("player"):
		if node is PlayerController:
			connect_to_player(node)
			return


func connect_to_player(player: PlayerController) -> void:
	if _player and _player != player:
		_disconnect_player()

	_player = player

	if _player.rings_changed.is_connected(_on_rings_changed):
		return

	_player.rings_changed.connect(_on_rings_changed)

	if _player.has_signal("score_changed"):
		_player.score_changed.connect(_on_score_changed)
	if _player.has_signal("boost_changed"):
		_player.boost_changed.connect(_on_boost_changed)

	# Initial sync
	_on_rings_changed(_player.current_rings)
	if "current_score" in _player:
		_on_score_changed(_player.current_score)


func _disconnect_player() -> void:
	if not _player:
		return
	if _player.rings_changed.is_connected(_on_rings_changed):
		_player.rings_changed.disconnect(_on_rings_changed)
	if _player.has_signal("score_changed") and _player.score_changed.is_connected(_on_score_changed):
		_player.score_changed.disconnect(_on_score_changed)
	if _player.has_signal("boost_changed") and _player.boost_changed.is_connected(_on_boost_changed):
		_player.boost_changed.disconnect(_on_boost_changed)
	_player = null


func _find_game_manager() -> void:
	var tree := get_tree()
	if not tree:
		return

	var gm := tree.get_first_node_in_group("xtreme_game_manager")
	if gm is XtremeGameManager:
		_game_manager = gm
#endregion


#region Signal Callbacks
func _on_rings_changed(current: int) -> void:
	if current == _last_rings:
		return
	_last_rings = current
	_ring_label.text = str(mini(current, 999))

	# Pop animation
	if _ring_pop_tween and _ring_pop_tween.is_valid():
		_ring_pop_tween.kill()
	_ring_pop_tween = create_tween()
	_ring_label.scale = Vector2.ONE * ring_pop_scale
	_ring_pop_tween.tween_property(_ring_label, "scale", Vector2.ONE, ring_pop_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_score_changed(current: int) -> void:
	if current == _last_score:
		return
	_last_score = current
	_score_label.text = XtremeLevelCompletion.format_score(current)


func _on_boost_changed(current: float) -> void:
	_last_boost = current
	_update_boost_visual(current)
#endregion


#region Updates
func _update_time() -> void:
	if _game_manager:
		_time_label.text = _game_manager.get_current_time_formatted()


func _update_boost() -> void:
	if not _player or not ("boost_meter" in _player):
		return
	var current: float = _player.boost_meter
	if absf(current - _last_boost) < 0.1:
		return
	_last_boost = current
	_update_boost_visual(current)


func _update_boost_visual(value: float) -> void:
	if not _boost_fill:
		return
	var max_val: float = 100.0
	if _player and "boost_max" in _player:
		max_val = _player.boost_max
	var fill_ratio := clampf(value / max_val, 0.0, 1.0)
	_boost_fill.offset_top = -boost_bar_height * fill_ratio
#endregion


#region Boss Health API
## Call to show boss health bar
func show_boss_health(boss_name: String, health_ratio: float = 1.0) -> void:
	_boss_name_label.text = boss_name
	_update_boss_health(health_ratio)
	_boss_container.visible = true
	_boss_visible = true


## Call to update boss health (0.0 - 1.0)
func update_boss_health(health_ratio: float) -> void:
	_update_boss_health(health_ratio)


## Call to hide boss health bar
func hide_boss_health() -> void:
	_boss_container.visible = false
	_boss_visible = false


func _update_boss_health(ratio: float) -> void:
	if _boss_health_fill:
		_boss_health_fill.anchor_right = clampf(ratio, 0.0, 1.0)
#endregion


#region Power-Up Display (Sprint 3 integration point)
func show_powerup_icon(texture: Texture2D) -> void:
	_powerup_icon.texture = texture
	_powerup_icon.visible = true


func hide_powerup_icon() -> void:
	_powerup_icon.visible = false
#endregion


#region Special Stage HUD
## Enter special stage HUD mode: swap ring display to "RING TIME", show large counter.
func enter_special_stage_mode(stage_manager: Node) -> void:
	_special_stage_mode = true
	_special_stage_manager = stage_manager

	# Swap label text
	if _ring_icon_label:
		_ring_icon_label.text = "RING TIME"
		_ring_icon_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))

	# Show the large ring-time counter
	if _ring_time_label:
		_ring_time_label.visible = true

	# Hide score and time (not relevant in special stages)
	if _score_label:
		_score_label.visible = false
	if _time_label:
		_time_label.visible = false

	# Connect to stage manager signals
	if _special_stage_manager and _special_stage_manager.has_signal("time_changed"):
		if not _special_stage_manager.time_changed.is_connected(_on_ring_time_changed):
			_special_stage_manager.time_changed.connect(_on_ring_time_changed)
	if _special_stage_manager and _special_stage_manager.has_signal("time_expired"):
		if not _special_stage_manager.time_expired.is_connected(_on_ring_time_expired):
			_special_stage_manager.time_expired.connect(_on_ring_time_expired)


## Exit special stage HUD mode: restore normal ring display.
func exit_special_stage_mode() -> void:
	_special_stage_mode = false
	_ring_time_warning = false

	# Restore label
	if _ring_icon_label:
		_ring_icon_label.text = "RINGS"
		_ring_icon_label.add_theme_color_override("font_color", ring_color.darkened(0.2))

	# Hide ring-time counter
	if _ring_time_label:
		_ring_time_label.visible = false
		_ring_time_label.add_theme_color_override("font_color", ring_color)

	# Show score and time again
	if _score_label:
		_score_label.visible = true
	if _time_label:
		_time_label.visible = true

	# Disconnect stage manager signals
	if _special_stage_manager:
		if _special_stage_manager.has_signal("time_changed") and _special_stage_manager.time_changed.is_connected(_on_ring_time_changed):
			_special_stage_manager.time_changed.disconnect(_on_ring_time_changed)
		if _special_stage_manager.has_signal("time_expired") and _special_stage_manager.time_expired.is_connected(_on_ring_time_expired):
			_special_stage_manager.time_expired.disconnect(_on_ring_time_expired)
	_special_stage_manager = null


func _on_ring_time_changed(current: int) -> void:
	if not _ring_time_label:
		return
	_ring_time_label.text = str(current)
	_ring_label.text = str(current)

	# Flash warning when time < 10
	if current <= 10 and not _ring_time_warning:
		_ring_time_warning = true
		_ring_time_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		_ring_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	elif current > 10 and _ring_time_warning:
		_ring_time_warning = false
		_ring_time_label.add_theme_color_override("font_color", ring_color)
		_ring_label.add_theme_color_override("font_color", ring_color)


func _on_ring_time_expired() -> void:
	if _ring_time_label:
		_ring_time_label.text = "0"
		_ring_time_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0))
	if _ring_label:
		_ring_label.text = "0"
#endregion
