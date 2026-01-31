@tool
class_name ParallaxBackground3D
extends Node3D

## =============================================================================
## PARALLAX BACKGROUND 3D
## =============================================================================
## Manages multiple ParallaxLayer3D children to create depth in 3D scenes.
## Inspired by Sonic Mania's special stage backgrounds and Sonic World.
##
## Structure:
##   ParallaxBackground3D
##   ├── SkyLayer (parallax_factor = 0.05)
##   ├── FarLayer (parallax_factor = 0.2)
##   ├── MidLayer (parallax_factor = 0.5)
##   └── NearLayer (parallax_factor = 0.8)
##
## Each layer should contain visual elements (Sprite3D, MeshInstance3D, etc.)
## =============================================================================

## The camera to track for parallax calculations
@export var camera: Camera3D:
	set(value):
		camera = value
		_last_camera_position = camera.global_position if camera else Vector3.ZERO

## Alternative: track a target node instead of camera directly
@export var track_target: Node3D

## Use camera or target for parallax origin
@export_enum("Camera", "Target") var tracking_mode: int = 0

## Scale factor for parallax movement (adjust for different world scales)
@export var parallax_scale: float = 1.0

## Offset the entire background system
@export var background_offset: Vector3 = Vector3.ZERO

## Lock vertical parallax (useful for side-scrolling sections)
@export var lock_vertical: bool = false

## Auto-find camera in scene
@export var auto_find_camera: bool = true

## Update layers in editor for preview
@export var update_in_editor: bool = true

# Internal state
var _last_camera_position: Vector3 = Vector3.ZERO
var _layers: Array[ParallaxLayer3D] = []
var _initialized: bool = false


func _ready() -> void:
	_cache_layers()
	
	if auto_find_camera and not camera:
		_find_camera()
	
	if camera:
		_last_camera_position = camera.global_position
	elif track_target:
		_last_camera_position = track_target.global_position
	
	_initialized = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not update_in_editor:
		return
	
	_update_parallax()


func _cache_layers() -> void:
	_layers.clear()
	for child in get_children():
		if child is ParallaxLayer3D:
			_layers.append(child)


func _find_camera() -> void:
	# Try to find XtremeCamera first
	var xtreme_cam = _find_node_by_class(get_tree().root, "XtremeCamera")
	if xtreme_cam:
		camera = xtreme_cam
		return
	
	# Fall back to any Camera3D
	var cam = _find_node_by_class(get_tree().root, "Camera3D")
	if cam:
		camera = cam


func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	if node.get_class() == class_name_str or node.is_class(class_name_str):
		return node
	
	for child in node.get_children():
		var found = _find_node_by_class(child, class_name_str)
		if found:
			return found
	
	return null


func _update_parallax() -> void:
	# Get current tracking position
	var current_position: Vector3
	
	if tracking_mode == 0 and camera:
		current_position = camera.global_position
	elif tracking_mode == 1 and track_target:
		current_position = track_target.global_position
	elif camera:
		current_position = camera.global_position
	else:
		return
	
	# Calculate offset from initial position
	var camera_offset := (current_position - _last_camera_position) * parallax_scale
	
	if lock_vertical:
		camera_offset.y = 0.0
	
	# Update accumulated offset (for layers that need total offset, not delta)
	# We track from scene start, not last frame
	
	# Update all layers
	for layer in _layers:
		if is_instance_valid(layer):
			layer.update_parallax(current_position, _get_total_offset(current_position))
	
	# Don't update _last_camera_position - we want total offset from start


func _get_total_offset(current_position: Vector3) -> Vector3:
	# Calculate total offset from the initial position when scene started
	# This gives consistent parallax regardless of frame timing
	var offset := current_position * parallax_scale
	
	if lock_vertical:
		offset.y = 0.0
	
	return offset + background_offset


## ===== PUBLIC API =====

## Manually refresh the layer cache (call after adding/removing layers at runtime)
func refresh_layers() -> void:
	_cache_layers()


## Add a new parallax layer at runtime
func add_layer(layer: ParallaxLayer3D) -> void:
	add_child(layer)
	_layers.append(layer)


## Remove a layer
func remove_layer(layer: ParallaxLayer3D) -> void:
	_layers.erase(layer)
	layer.queue_free()


## Get all layers sorted by parallax factor (furthest first)
func get_layers_by_depth() -> Array[ParallaxLayer3D]:
	var sorted := _layers.duplicate()
	sorted.sort_custom(func(a, b): return a.parallax_factor < b.parallax_factor)
	return sorted


## Reset all layers to initial positions
func reset_all_layers() -> void:
	for layer in _layers:
		if is_instance_valid(layer):
			layer.reset_position()


## Create a simple sprite layer programmatically
func create_sprite_layer(
	texture: Texture2D,
	parallax: float = 0.5,
	distance: float = 50.0,
	scale_factor: float = 1.0
) -> ParallaxLayer3D:
	var layer := ParallaxLayer3D.new()
	layer.parallax_factor = parallax
	layer.base_distance = distance
	
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = 0.1 * scale_factor
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	
	layer.add_child(sprite)
	add_layer(layer)
	
	# Position at base distance
	layer.position.z = -distance
	
	return layer


## Create a colored plane layer (for simple backgrounds)
func create_color_layer(
	color: Color,
	parallax: float = 0.0,
	distance: float = 200.0,
	size: Vector2 = Vector2(500, 200)
) -> ParallaxLayer3D:
	var layer := ParallaxLayer3D.new()
	layer.parallax_factor = parallax
	layer.base_distance = distance
	
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mesh_instance.mesh = quad
	
	# Create unlit material with color
	var material: Material
	var unlit_shader = load("res://addons/xtreme_level_editor/shaders/retro/retro_unlit.gdshader")
	if unlit_shader:
		material = ShaderMaterial.new()
		material.shader = unlit_shader
		material.set_shader_parameter("albedo", color)
		material.set_shader_parameter("brightness", 1.0)
		material.set_shader_parameter("retro_enabled", false)  # Clean background
	else:
		var std_mat := StandardMaterial3D.new()
		std_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		std_mat.albedo_color = color
		material = std_mat
	
	mesh_instance.material_override = material
	layer.add_child(mesh_instance)
	add_layer(layer)
	
	# Position at base distance
	layer.position.z = -distance
	
	return layer
