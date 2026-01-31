@tool
class_name RetroHUD
extends CanvasLayer

## =============================================================================
## RETRO HUD
## =============================================================================
## PS1/Saturn-style HUD that displays game information.
## Designed to be clean and readable, NOT affected by retro post-processing.
##
## Features:
## - Ring counter with animated ring icon
## - Score display
## - Timer
## - Life counter
## - Speed indicator (optional)
## =============================================================================

signal rings_changed(new_value: int)
signal score_changed(new_value: int)
signal lives_changed(new_value: int)

## ===== VALUES =====
@export_group("Game State")
@export var rings: int = 0:
	set(value):
		rings = max(0, value)
		_update_rings_display()
		rings_changed.emit(rings)

@export var score: int = 0:
	set(value):
		score = max(0, value)
		_update_score_display()
		score_changed.emit(score)

@export var lives: int = 3:
	set(value):
		lives = max(0, value)
		_update_lives_display()
		lives_changed.emit(lives)

@export var time_seconds: float = 0.0:
	set(value):
		time_seconds = max(0.0, value)
		_update_timer_display()

## ===== APPEARANCE =====
@export_group("Appearance")
@export var font_color: Color = Color.WHITE
@export var shadow_color: Color = Color(0, 0, 0, 0.8)
@export var ring_color: Color = Color(1.0, 0.85, 0.0)
@export var warning_color: Color = Color(1.0, 0.3, 0.3)

## Flash rings red when at zero
@export var flash_zero_rings: bool = true

## Animate ring icon rotation
@export var animate_ring_icon: bool = true
@export var ring_rotation_speed: float = 180.0

## ===== TIMER =====
@export_group("Timer")
@export var timer_enabled: bool = true
@export var timer_counting: bool = false
@export var count_up: bool = true  ## Count up (elapsed) or down (remaining)
@export var time_limit: float = 600.0  ## 10 minutes default limit

## ===== LAYOUT =====
@export_group("Layout")
@export var margin: Vector2 = Vector2(16, 16)
@export var element_spacing: float = 8.0

# Internal references
var _rings_label: Label
var _score_label: Label
var _time_label: Label
var _lives_label: Label
var _ring_icon: Control
var _speed_bar: Control

var _ring_flash_timer: float = 0.0
var _ring_rotation: float = 0.0


func _ready() -> void:
	layer = 100  # Ensure HUD is on top
	_setup_hud()
	_update_all_displays()


func _process(delta: float) -> void:
	# Update timer
	if timer_counting and timer_enabled:
		if count_up:
			time_seconds += delta
		else:
			time_seconds -= delta
			if time_seconds <= 0:
				time_seconds = 0
				timer_counting = false
	
	# Animate ring icon
	if animate_ring_icon and _ring_icon:
		_ring_rotation += ring_rotation_speed * delta
		if _ring_rotation >= 360.0:
			_ring_rotation -= 360.0
		_ring_icon.rotation = deg_to_rad(_ring_rotation)
	
	# Flash zero rings warning
	if flash_zero_rings and rings == 0:
		_ring_flash_timer += delta * 8.0
		var flash: float = (sin(_ring_flash_timer) + 1.0) * 0.5
		if _rings_label:
			_rings_label.modulate = font_color.lerp(warning_color, flash)
	elif _rings_label:
		_rings_label.modulate = font_color


func _setup_hud() -> void:
	# Create main container
	var container := Control.new()
	container.name = "HUDContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	
	# Top-left: Rings and Score
	var top_left := VBoxContainer.new()
	top_left.name = "TopLeft"
	top_left.position = margin
	top_left.add_theme_constant_override("separation", int(element_spacing))
	container.add_child(top_left)
	
	# Rings row
	var rings_row := HBoxContainer.new()
	rings_row.add_theme_constant_override("separation", 8)
	top_left.add_child(rings_row)
	
	# Ring icon (simple colored rectangle as placeholder)
	_ring_icon = _create_ring_icon()
	rings_row.add_child(_ring_icon)
	
	# Rings label
	_rings_label = _create_label("RINGS")
	rings_row.add_child(_rings_label)
	
	var rings_value := _create_label("000")
	rings_value.name = "RingsValue"
	rings_row.add_child(rings_value)
	_rings_label = rings_value  # Point to value label for updates
	
	# Score row
	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 8)
	top_left.add_child(score_row)
	
	var score_text := _create_label("SCORE")
	score_row.add_child(score_text)
	
	_score_label = _create_label("00000000")
	_score_label.name = "ScoreValue"
	score_row.add_child(_score_label)
	
	# Top-right: Timer
	var top_right := VBoxContainer.new()
	top_right.name = "TopRight"
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-margin.x - 150, margin.y)
	top_right.add_theme_constant_override("separation", int(element_spacing))
	container.add_child(top_right)
	
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 8)
	top_right.add_child(time_row)
	
	var time_text := _create_label("TIME")
	time_row.add_child(time_text)
	
	_time_label = _create_label("0:00:00")
	_time_label.name = "TimeValue"
	time_row.add_child(_time_label)
	
	# Bottom-left: Lives
	var bottom_left := HBoxContainer.new()
	bottom_left.name = "BottomLeft"
	bottom_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_left.position = Vector2(margin.x, -margin.y - 32)
	bottom_left.add_theme_constant_override("separation", 8)
	container.add_child(bottom_left)
	
	var lives_icon := _create_lives_icon()
	bottom_left.add_child(lives_icon)
	
	var lives_x := _create_label("x")
	bottom_left.add_child(lives_x)
	
	_lives_label = _create_label("3")
	_lives_label.name = "LivesValue"
	bottom_left.add_child(_lives_label)


func _create_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", shadow_color)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _create_ring_icon() -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.set_script(_get_ring_icon_script())
	return icon


func _create_lives_icon() -> Control:
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.color = Color(0.2, 0.6, 1.0)  # Player blue color
	return icon


func _get_ring_icon_script() -> GDScript:
	# Inline script for drawing ring icon
	var script := GDScript.new()
	script.source_code = """
extends Control

var ring_color: Color = Color(1.0, 0.85, 0.0)

func _draw() -> void:
	var center := size / 2.0
	var outer_radius := min(size.x, size.y) / 2.0 - 2.0
	var inner_radius := outer_radius * 0.5
	
	# Draw ring (torus cross-section as concentric circles)
	draw_circle(center, outer_radius, ring_color)
	draw_circle(center, inner_radius, Color(0, 0, 0, 0.3))
"""
	return script


func _update_rings_display() -> void:
	if _rings_label:
		_rings_label.text = "%03d" % rings


func _update_score_display() -> void:
	if _score_label:
		_score_label.text = "%08d" % score


func _update_timer_display() -> void:
	if _time_label:
		var minutes: int = int(time_seconds) / 60
		var seconds: int = int(time_seconds) % 60
		var centiseconds: int = int((time_seconds - int(time_seconds)) * 100)
		_time_label.text = "%d:%02d:%02d" % [minutes, seconds, centiseconds]


func _update_lives_display() -> void:
	if _lives_label:
		_lives_label.text = str(lives)


func _update_all_displays() -> void:
	_update_rings_display()
	_update_score_display()
	_update_timer_display()
	_update_lives_display()


## ===== PUBLIC API =====

## Add rings (with optional animation)
func add_rings(amount: int) -> void:
	rings += amount


## Add score
func add_score(amount: int) -> void:
	score += amount


## Lose a life
func lose_life() -> void:
	lives -= 1


## Start the timer
func start_timer() -> void:
	timer_counting = true


## Stop the timer
func stop_timer() -> void:
	timer_counting = false


## Reset the timer
func reset_timer(start_time: float = 0.0) -> void:
	time_seconds = start_time
	timer_counting = false


## Reset all HUD values
func reset_all() -> void:
	rings = 0
	score = 0
	lives = 3
	reset_timer()


## Show speed indicator
func show_speed(current_speed: float, max_speed: float) -> void:
	# TODO: Implement speed bar
	pass
