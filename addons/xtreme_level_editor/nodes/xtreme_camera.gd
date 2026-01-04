class_name XtremeCamera
extends Camera3D

## Xtreme Camera System
## A camera designed to work with the Sonic Xtreme-style curved world shader.
## 
## This camera:
## - Follows the player position exactly (no offset on position)
## - Maintains a fixed orientation (does not rotate)
## - Updates the curved world shader's center point each frame
##
## Attach this to your scene and assign the player node.

## The node to follow (usually your player character)
@export var target: Node3D

## Vertical offset from the target position (camera height above player)
@export var height_offset: float = 2.0

## Distance behind the target (how far back the camera sits)
@export var follow_distance: float = 8.0

## The fixed angle the camera looks at (in degrees, typically looking slightly down)
@export_range(-90, 90) var pitch_angle: float = -15.0

@export_group("Curved World Shader")
## Automatically find and update all curved world materials in the scene
@export var auto_update_materials: bool = true

## Manual list of materials to update (if auto_update is off)
@export var curved_materials: Array[ShaderMaterial] = []

## Update shader center based on camera position (true) or target position (false)
@export var shader_follows_camera: bool = false

@export_group("Smoothing")
## Enable position smoothing (set to false for exact Sonic Xtreme style)
@export var smooth_position: bool = false

## Position smoothing speed (higher = faster/snappier)
@export var smooth_speed: float = 10.0

@export_group("Debug")
## Draw debug information
@export var debug_draw: bool = false

# Internal state
var _cached_materials: Array[ShaderMaterial] = []
var _materials_cached: bool = false

func _ready() -> void:
	# Set initial rotation based on pitch angle
	rotation.x = deg_to_rad(pitch_angle)
	rotation.y = 0
	rotation.z = 0
	
	# Cache materials on start if auto-update is enabled
	if auto_update_materials:
		call_deferred("_cache_curved_materials")

func _process(delta: float) -> void:
	if not target:
		return
	
	_update_position(delta)
	_update_shader_centers()

func _update_position(delta: float) -> void:
	# Calculate desired position
	# Camera is positioned behind and above the target
	# "Behind" is determined by the camera's fixed forward direction (negative Z in local space)
	
	var target_pos := target.global_position
	
	# Calculate camera position: directly behind the target along world -Z axis
	# (Since the camera has fixed orientation, "behind" is always world -Z relative to target)
	var desired_position := Vector3(
		target_pos.x,
		target_pos.y + height_offset,
		target_pos.z + follow_distance
	)
	
	if smooth_position:
		global_position = global_position.lerp(desired_position, smooth_speed * delta)
	else:
		global_position = desired_position

func _update_shader_centers() -> void:
	var center_position: Vector3
	if shader_follows_camera:
		center_position = global_position
	else:
		center_position = target.global_position if target else global_position
	
	# Update manually assigned materials
	for mat in curved_materials:
		if mat and is_instance_valid(mat):
			mat.set_shader_parameter("curve_center", center_position)
	
	# Update auto-cached materials
	if auto_update_materials:
		for mat in _cached_materials:
			if mat and is_instance_valid(mat):
				mat.set_shader_parameter("curve_center", center_position)

func _cache_curved_materials() -> void:
	_cached_materials.clear()
	_find_curved_materials_recursive(get_tree().root)
	_materials_cached = true
	
	if debug_draw:
		print("[XtremeCamera] Cached %d curved world materials" % _cached_materials.size())

func _find_curved_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		
		# Check material override
		var mat := mesh_instance.material_override
		if _is_curved_world_material(mat):
			if mat not in _cached_materials:
				_cached_materials.append(mat)
		
		# Check surface materials
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				mat = mesh_instance.mesh.surface_get_material(i)
				if _is_curved_world_material(mat):
					if mat not in _cached_materials:
						_cached_materials.append(mat)
				
				# Also check material override per surface
				mat = mesh_instance.get_surface_override_material(i)
				if _is_curved_world_material(mat):
					if mat not in _cached_materials:
						_cached_materials.append(mat)
	
	# Recurse into children
	for child in node.get_children():
		_find_curved_materials_recursive(child)

func _is_curved_world_material(mat: Material) -> bool:
	if mat is ShaderMaterial:
		var shader_mat := mat as ShaderMaterial
		# Check if this material has the curve_center parameter
		# This is a heuristic - the material has our curved world shader if it has this parameter
		var shader := shader_mat.shader
		if shader:
			# Try to get the parameter - if it exists, this is likely our shader
			var current_value = shader_mat.get_shader_parameter("curve_center")
			return current_value != null
	return false

## Call this when the scene changes to re-cache materials
func refresh_material_cache() -> void:
	if auto_update_materials:
		_cache_curved_materials()

## Manually add a material to be updated
func add_curved_material(mat: ShaderMaterial) -> void:
	if mat and mat not in curved_materials:
		curved_materials.append(mat)

## Remove a material from updates
func remove_curved_material(mat: ShaderMaterial) -> void:
	curved_materials.erase(mat)

## Set the target to follow
func set_target(new_target: Node3D) -> void:
	target = new_target

## Get the current shader center position
func get_shader_center() -> Vector3:
	if shader_follows_camera:
		return global_position
	elif target:
		return target.global_position
	return global_position
