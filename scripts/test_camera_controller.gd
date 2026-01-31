extends Node3D

## Simple camera controller for testing parallax backgrounds
## WASD to move, mouse to look (hold right click)

@export var move_speed: float = 20.0
@export var mouse_sensitivity: float = 0.003

var _mouse_captured: bool = false


func _ready() -> void:
	# Get parent camera
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_captured = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseMotion and _mouse_captured:
		var parent := get_parent() as Node3D
		if parent:
			parent.rotate_y(-event.relative.x * mouse_sensitivity)
			parent.rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
			# Clamp pitch
			parent.rotation.x = clamp(parent.rotation.x, -PI/2, PI/2)


func _process(delta: float) -> void:
	var parent := get_parent() as Node3D
	if not parent:
		return
	
	var input_dir := Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_Q):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_E):
		input_dir.y += 1
	
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		# Transform to camera's local space
		var movement := parent.global_transform.basis * input_dir * move_speed * delta
		parent.global_position += movement
