extends Control
class_name HomingReticle

## Homing Reticle UI Component
## Attach to a Control node that contains your reticle graphic
## Assign this node to the PlayerController's homing_reticle export
##
## v1.1 FIXES:
## - Added proper show/hide methods
## - Fixed scale animation reset
## - Added rotation overflow protection

@export_group("Animation")
## Enable pulsing animation when target is locked
@export var animate_pulse: bool = true
## Pulse speed (cycles per second)
@export var pulse_speed: float = 3.0
## Minimum scale during pulse
@export var pulse_min_scale: float = 0.9
## Maximum scale during pulse
@export var pulse_max_scale: float = 1.1

@export_group("Appearance")
## Enable rotation animation
@export var animate_rotation: bool = true
## Rotation speed (degrees per second)
@export var rotation_speed: float = 90.0
## Reticle color (tints the texture)
@export var reticle_color: Color = Color.WHITE

var base_scale: Vector2
var time: float = 0.0
var _is_showing: bool = false
var _main_group: Control
var _counter_group: Control


func _ready() -> void:
	base_scale = scale
	visible = false
	_main_group = get_node_or_null("MainGroup") as Control
	_counter_group = get_node_or_null("CounterGroup") as Control
	_apply_color()


func _process(delta: float) -> void:
	if not visible or not _is_showing:
		return
	
	time += delta
	
	# Pulse animation
	if animate_pulse:
		var pulse = sin(time * pulse_speed * TAU) * 0.5 + 0.5
		var current_scale = lerpf(pulse_min_scale, pulse_max_scale, pulse)
		scale = base_scale * current_scale
	
	# Rotation animation
	if animate_rotation:
		if _main_group:
			_main_group.rotation_degrees += rotation_speed * delta
			if _main_group.rotation_degrees > 360.0:
				_main_group.rotation_degrees -= 360.0
		if _counter_group:
			_counter_group.rotation_degrees += rotation_speed * delta
			if _counter_group.rotation_degrees > 360.0:
				_counter_group.rotation_degrees -= 360.0
		if not _main_group and not _counter_group:
			rotation_degrees += rotation_speed * delta
			# Keep rotation in bounds to avoid float overflow after long play sessions
			if rotation_degrees > 360.0:
				rotation_degrees -= 360.0


## Call this to show the reticle with a pop-in effect
func show_reticle() -> void:
	if _is_showing:
		return
	
	_is_showing = true
	visible = true
	time = 0.0
	rotation_degrees = 0.0
	if _main_group:
		_main_group.rotation_degrees = 0.0
	if _counter_group:
		_counter_group.rotation_degrees = 180.0
	
	scale = base_scale * 0.5
	var tween = create_tween()
	tween.tween_property(self, "scale", base_scale, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Call this to hide the reticle
func hide_reticle() -> void:
	if not _is_showing:
		return
	
	_is_showing = false
	
	var tween = create_tween()
	tween.tween_property(self, "scale", base_scale * 0.3, 0.05).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): 
		visible = false
		scale = base_scale
		if _main_group:
			_main_group.rotation_degrees = 0.0
		if _counter_group:
			_counter_group.rotation_degrees = 180.0
	)


## Apply tint color to texture rect children
func _apply_color() -> void:
	_apply_color_recursive(self)


func _apply_color_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is TextureRect:
			child.modulate = reticle_color
		elif child is Sprite2D:
			child.modulate = reticle_color
		elif child is ColorRect:
			child.modulate = reticle_color
		_apply_color_recursive(child)


## Set reticle color at runtime
func set_reticle_color(color: Color) -> void:
	reticle_color = color
	_apply_color()
