@tool
class_name ParallaxLayer3D
extends Node3D

## =============================================================================
## PARALLAX LAYER 3D
## =============================================================================
## A single parallax layer that moves relative to camera position.
## Used as a child of ParallaxBackground3D.
##
## The layer moves at a fraction of the camera's movement, creating depth.
## A parallax_factor of 0.0 means no movement (infinitely far).
## A parallax_factor of 1.0 means moves with camera (no parallax).
## =============================================================================

## How much this layer moves relative to camera (0.0 = fixed, 1.0 = moves with camera)
@export_range(0.0, 1.0, 0.01) var parallax_factor: float = 0.5:
	set(value):
		parallax_factor = clampf(value, 0.0, 1.0)

## Vertical parallax factor (usually less than horizontal for natural feel)
@export_range(0.0, 1.0, 0.01) var vertical_parallax_factor: float = 0.0:
	set(value):
		vertical_parallax_factor = clampf(value, 0.0, 1.0)

## Base distance from camera (affects rendering order)
@export var base_distance: float = 100.0

## Repeat the layer horizontally
@export var repeat_x: bool = true

## Repeat the layer vertically
@export var repeat_y: bool = false

## Width of the layer texture/mesh for repeat calculations
@export var layer_width: float = 100.0

## Height of the layer texture/mesh for repeat calculations  
@export var layer_height: float = 50.0

## Constant scroll speed (for animated backgrounds)
@export var auto_scroll_speed: Vector2 = Vector2.ZERO

## Internal tracking
var _initial_position: Vector3
var _accumulated_scroll: Vector2 = Vector2.ZERO


func _ready() -> void:
	_initial_position = position


func _process(delta: float) -> void:
	# Apply auto-scroll
	if auto_scroll_speed != Vector2.ZERO:
		_accumulated_scroll += auto_scroll_speed * delta


## Update layer position based on camera position
## Called by ParallaxBackground3D parent
func update_parallax(camera_position: Vector3, camera_offset: Vector3) -> void:
	# Calculate parallax offset
	var parallax_offset := Vector3(
		camera_offset.x * parallax_factor,
		camera_offset.y * vertical_parallax_factor,
		0.0
	)
	
	# Add auto-scroll
	parallax_offset.x += _accumulated_scroll.x
	parallax_offset.y += _accumulated_scroll.y
	
	# Apply position
	var new_pos := _initial_position + parallax_offset
	
	# Handle repeating (wrap position)
	if repeat_x and layer_width > 0:
		new_pos.x = fmod(new_pos.x, layer_width)
		if new_pos.x > layer_width * 0.5:
			new_pos.x -= layer_width
		elif new_pos.x < -layer_width * 0.5:
			new_pos.x += layer_width
	
	if repeat_y and layer_height > 0:
		new_pos.y = fmod(new_pos.y, layer_height)
		if new_pos.y > layer_height * 0.5:
			new_pos.y -= layer_height
		elif new_pos.y < -layer_height * 0.5:
			new_pos.y += layer_height
	
	position = new_pos


## Reset layer to initial position
func reset_position() -> void:
	position = _initial_position
	_accumulated_scroll = Vector2.ZERO
