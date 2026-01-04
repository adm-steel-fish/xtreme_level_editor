extends Control
class_name HomingReticle

## Homing Reticle UI Component
## Attach to a Control node that contains your reticle graphic
## Assign this node to the PlayerController's homing_reticle export

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

var base_scale: Vector2
var time: float = 0.0


func _ready() -> void:
	base_scale = scale
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	
	time += delta
	
	# Pulse animation
	if animate_pulse:
		var pulse = sin(time * pulse_speed * TAU) * 0.5 + 0.5
		var current_scale = lerpf(pulse_min_scale, pulse_max_scale, pulse)
		scale = base_scale * current_scale
	
	# Rotation animation
	if animate_rotation:
		rotation_degrees += rotation_speed * delta


## Call this to show the reticle with a pop-in effect
func show_reticle() -> void:
	visible = true
	scale = base_scale * 0.5
	var tween = create_tween()
	tween.tween_property(self, "scale", base_scale, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Call this to hide the reticle
func hide_reticle() -> void:
	visible = false
	scale = base_scale
