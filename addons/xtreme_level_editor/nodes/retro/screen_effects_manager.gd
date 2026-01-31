class_name ScreenEffectsManager
extends CanvasLayer

## =============================================================================
## SCREEN EFFECTS MANAGER
## =============================================================================
## Handles screen-space effects like transitions, flashes, and overlays.
## Add to your scene and call methods to trigger effects.
##
## Effects:
## - Screen flash (damage, collection)
## - Iris wipe (zone transitions)
## - Horizontal/Vertical wipes
## - Pixelate transition
## - Speed blur overlay
## =============================================================================

signal transition_started(effect_name: String)
signal transition_midpoint()
signal transition_finished(effect_name: String)
signal flash_finished()

enum EffectType {
	NONE = 0,
	FLASH = 1,
	IRIS_WIPE = 2,
	HORIZONTAL_WIPE = 3,
	VERTICAL_WIPE = 4,
	PIXELATE = 5
}

@export_group("Settings")
@export var default_transition_time: float = 0.5
@export var default_flash_time: float = 0.15

# Internal
var _effect_rect: ColorRect
var _material: ShaderMaterial
var _current_tween: Tween
var _is_transitioning: bool = false


func _ready() -> void:
	layer = 99  # Just below HUD
	_setup_effect_layer()


func _setup_effect_layer() -> void:
	_effect_rect = ColorRect.new()
	_effect_rect.name = "EffectRect"
	_effect_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader := load("res://addons/xtreme_level_editor/shaders/retro/screen_effects.gdshader")
	if shader:
		_material = ShaderMaterial.new()
		_material.shader = shader
		_effect_rect.material = _material
		_set_effect(EffectType.NONE, 0.0)
	else:
		# Fallback without shader
		_effect_rect.color = Color(0, 0, 0, 0)
	
	add_child(_effect_rect)


func _set_effect(effect: EffectType, progress: float, color: Color = Color.BLACK, invert: bool = false) -> void:
	if not _material:
		return
	
	_material.set_shader_parameter("effect_type", int(effect))
	_material.set_shader_parameter("progress", progress)
	_material.set_shader_parameter("effect_color", color)
	_material.set_shader_parameter("invert", invert)


## ===== SCREEN FLASH =====

## Flash the screen (for damage, ring collection, etc.)
func flash(color: Color = Color.WHITE, duration: float = -1.0) -> void:
	if duration < 0:
		duration = default_flash_time
	
	_cancel_current()
	
	_set_effect(EffectType.FLASH, 1.0, color)
	
	_current_tween = create_tween()
	_current_tween.tween_method(_set_flash_progress.bind(color), 1.0, 0.0, duration)
	_current_tween.tween_callback(_on_flash_finished)


func flash_damage() -> void:
	flash(Color(1.0, 0.2, 0.2, 0.6), 0.1)


func flash_ring_collect() -> void:
	flash(Color(1.0, 0.9, 0.3, 0.3), 0.08)


func flash_white() -> void:
	flash(Color.WHITE, 0.2)


func _set_flash_progress(progress: float, color: Color) -> void:
	_set_effect(EffectType.FLASH, progress, color)


func _on_flash_finished() -> void:
	_set_effect(EffectType.NONE, 0.0)
	flash_finished.emit()


## ===== TRANSITIONS =====

## Fade to black and back (calls midpoint_callback at the middle)
func fade_transition(duration: float = -1.0, color: Color = Color.BLACK) -> void:
	if duration < 0:
		duration = default_transition_time * 2.0
	
	_cancel_current()
	_is_transitioning = true
	transition_started.emit("fade")
	
	_current_tween = create_tween()
	
	# Fade out
	_current_tween.tween_method(_set_flash_progress.bind(color), 0.0, 1.0, duration * 0.5)
	_current_tween.tween_callback(func(): transition_midpoint.emit())
	
	# Fade in
	_current_tween.tween_method(_set_flash_progress.bind(color), 1.0, 0.0, duration * 0.5)
	_current_tween.tween_callback(_on_transition_finished.bind("fade"))


## Iris wipe transition (circle closes then opens)
func iris_transition(duration: float = -1.0, color: Color = Color.BLACK, center: Vector2 = Vector2(0.5, 0.5)) -> void:
	if duration < 0:
		duration = default_transition_time * 2.0
	
	_cancel_current()
	_is_transitioning = true
	transition_started.emit("iris")
	
	if _material:
		_material.set_shader_parameter("iris_center", center)
	
	_current_tween = create_tween()
	
	# Close iris
	_current_tween.tween_method(_set_iris_progress.bind(color, false), 0.0, 1.0, duration * 0.5)
	_current_tween.tween_callback(func(): transition_midpoint.emit())
	
	# Open iris
	_current_tween.tween_method(_set_iris_progress.bind(color, true), 0.0, 1.0, duration * 0.5)
	_current_tween.tween_callback(_on_transition_finished.bind("iris"))


func _set_iris_progress(progress: float, color: Color, opening: bool) -> void:
	_set_effect(EffectType.IRIS_WIPE, progress, color, opening)


## Horizontal wipe transition
func horizontal_wipe(duration: float = -1.0, color: Color = Color.BLACK, left_to_right: bool = true) -> void:
	if duration < 0:
		duration = default_transition_time * 2.0
	
	_cancel_current()
	_is_transitioning = true
	transition_started.emit("horizontal_wipe")
	
	_current_tween = create_tween()
	
	# Wipe in
	_current_tween.tween_method(_set_wipe_progress.bind(EffectType.HORIZONTAL_WIPE, color, not left_to_right), 0.0, 1.0, duration * 0.5)
	_current_tween.tween_callback(func(): transition_midpoint.emit())
	
	# Wipe out
	_current_tween.tween_method(_set_wipe_progress.bind(EffectType.HORIZONTAL_WIPE, color, left_to_right), 0.0, 1.0, duration * 0.5)
	_current_tween.tween_callback(_on_transition_finished.bind("horizontal_wipe"))


## Vertical wipe transition
func vertical_wipe(duration: float = -1.0, color: Color = Color.BLACK, top_to_bottom: bool = true) -> void:
	if duration < 0:
		duration = default_transition_time * 2.0
	
	_cancel_current()
	_is_transitioning = true
	transition_started.emit("vertical_wipe")
	
	_current_tween = create_tween()
	
	# Wipe in
	_current_tween.tween_method(_set_wipe_progress.bind(EffectType.VERTICAL_WIPE, color, not top_to_bottom), 0.0, 1.0, duration * 0.5)
	_current_tween.tween_callback(func(): transition_midpoint.emit())
	
	# Wipe out
	_current_tween.tween_method(_set_wipe_progress.bind(EffectType.VERTICAL_WIPE, color, top_to_bottom), 0.0, 1.0, duration * 0.5)
	_current_tween.tween_callback(_on_transition_finished.bind("vertical_wipe"))


func _set_wipe_progress(progress: float, effect: EffectType, color: Color, invert: bool) -> void:
	_set_effect(effect, progress, color, invert)


## Pixelate transition
func pixelate_transition(duration: float = -1.0, color: Color = Color.BLACK) -> void:
	if duration < 0:
		duration = default_transition_time * 2.0
	
	_cancel_current()
	_is_transitioning = true
	transition_started.emit("pixelate")
	
	_current_tween = create_tween()
	
	# Pixelate out
	_current_tween.tween_method(_set_pixelate_progress.bind(color), 0.0, 1.0, duration * 0.5)
	_current_tween.tween_callback(func(): transition_midpoint.emit())
	
	# Pixelate in
	_current_tween.tween_method(_set_pixelate_progress.bind(color), 1.0, 0.0, duration * 0.5)
	_current_tween.tween_callback(_on_transition_finished.bind("pixelate"))


func _set_pixelate_progress(progress: float, color: Color) -> void:
	_set_effect(EffectType.PIXELATE, progress, color)


func _on_transition_finished(effect_name: String) -> void:
	_set_effect(EffectType.NONE, 0.0)
	_is_transitioning = false
	transition_finished.emit(effect_name)


## ===== SPEED BLUR =====

## Enable speed blur effect
func set_speed_blur(intensity: float, angle_radians: float = 0.0) -> void:
	if not _material:
		return
	
	_material.set_shader_parameter("speed_blur_enabled", intensity > 0.0)
	_material.set_shader_parameter("speed_blur_intensity", clampf(intensity, 0.0, 1.0))
	_material.set_shader_parameter("speed_blur_angle", angle_radians)


## Disable speed blur
func clear_speed_blur() -> void:
	if _material:
		_material.set_shader_parameter("speed_blur_enabled", false)
		_material.set_shader_parameter("speed_blur_intensity", 0.0)


## ===== UTILITY =====

func is_transitioning() -> bool:
	return _is_transitioning


func _cancel_current() -> void:
	if _current_tween and _current_tween.is_running():
		_current_tween.kill()
	_current_tween = null


## Force clear all effects
func clear_all() -> void:
	_cancel_current()
	_set_effect(EffectType.NONE, 0.0)
	clear_speed_blur()
	_is_transitioning = false
