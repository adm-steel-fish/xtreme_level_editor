extends Camera3D
class_name XtremeTestCamera

## Simple follow camera for testing player controller
## Maintains fixed angle and distance from player (Sonic X-treme style)

@export_group("Follow Settings")
## Target to follow
@export var target: Node3D
## Offset from target position
@export var offset: Vector3 = Vector3(0, 12, 18)
## How fast camera follows (0 = instant, higher = smoother)
@export var follow_smoothing: float = 8.0

@export_group("Look Settings")
## Look at offset (where on target to look)
@export var look_offset: Vector3 = Vector3(0, 1, 0)

var _target_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	if target:
		# Initialize position immediately
		global_position = target.global_position + offset
		look_at(target.global_position + look_offset, Vector3.UP)


func _physics_process(delta: float) -> void:
	if not target:
		return
	
	# Calculate target camera position
	_target_position = target.global_position + offset
	
	# Smoothly move camera
	if follow_smoothing > 0:
		global_position = global_position.lerp(_target_position, follow_smoothing * delta)
	else:
		global_position = _target_position
	
	# Always look at target
	look_at(target.global_position + look_offset, Vector3.UP)
