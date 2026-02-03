@tool
class_name BlobShadow
extends Node3D

## =============================================================================
## BLOB SHADOW
## =============================================================================
## Simple circular shadow that projects onto surfaces below the parent.
## Classic PS1/Saturn-style shadow replacement for real-time shadows.
##
## Add as child of player/enemy/object. The shadow will automatically
## position itself on the ground below.
## =============================================================================

## Maximum distance to cast shadow
@export var max_distance: float = 10.0

## Shadow appearance
@export_group("Appearance")
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.5):
	set(value):
		shadow_color = value
		_update_material()

@export var shadow_size: float = 1.0:
	set(value):
		shadow_size = value
		_update_mesh_size()

@export_range(0.0, 1.0, 0.05) var shadow_softness: float = 0.3:
	set(value):
		shadow_softness = value
		_update_material()

@export_range(0.0, 1.0, 0.05) var shadow_strength: float = 0.6:
	set(value):
		shadow_strength = value
		_update_material()

## Scale shadow based on distance (further = smaller, like real shadow)
@export var distance_scaling: bool = true

## Minimum scale when far from ground
@export_range(0.1, 1.0) var min_scale: float = 0.5

## ===== RAYCASTING =====
@export_group("Raycasting")
@export_flags_3d_physics var collision_mask: int = 1

## Offset above ground to prevent z-fighting
@export var ground_offset: float = 0.02

## Update frequency (0 = every frame)
@export var update_interval: float = 0.0

# Internal
var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial
var _update_timer: float = 0.0
var _current_ground_pos: Vector3
var _is_grounded: bool = false


func _ready() -> void:
	_setup_mesh()
	_update_material()


func _setup_mesh() -> void:
	# Create mesh instance if not exists
	_mesh_instance = get_node_or_null("ShadowMesh") as MeshInstance3D
	if not _mesh_instance:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "ShadowMesh"
		add_child(_mesh_instance)
		
		if Engine.is_editor_hint():
			var tree := get_tree()
			if tree:
				_mesh_instance.owner = tree.edited_scene_root
	
	# Create quad mesh
	var quad := QuadMesh.new()
	quad.size = Vector2(shadow_size, shadow_size)
	_mesh_instance.mesh = quad
	
	# Rotate to face down
	_mesh_instance.rotation.x = -PI / 2.0
	
	# Create material
	var shader := load("res://addons/xtreme_level_editor/shaders/retro/blob_shadow.gdshader")
	if shader:
		_material = ShaderMaterial.new()
		_material.shader = shader
		_mesh_instance.material_override = _material
	else:
		# Fallback to standard material
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = shadow_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mesh_instance.material_override = mat


func _update_material() -> void:
	if not _material:
		return
	
	_material.set_shader_parameter("shadow_color", shadow_color)
	_material.set_shader_parameter("shadow_softness", shadow_softness)
	_material.set_shader_parameter("shadow_strength", shadow_strength)


func _update_mesh_size() -> void:
	if _mesh_instance and _mesh_instance.mesh is QuadMesh:
		(_mesh_instance.mesh as QuadMesh).size = Vector2(shadow_size, shadow_size)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# Throttle updates if interval set
	if update_interval > 0.0:
		_update_timer += delta
		if _update_timer < update_interval:
			return
		_update_timer = 0.0
	
	_update_shadow_position()


func _update_shadow_position() -> void:
	if not get_parent():
		return
	
	var parent_pos: Vector3
	if get_parent() is Node3D:
		parent_pos = (get_parent() as Node3D).global_position
	else:
		parent_pos = global_position
	
	# Raycast downward
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		_mesh_instance.visible = false
		return
	
	var from: Vector3 = parent_pos
	var to: Vector3 = parent_pos + Vector3.DOWN * max_distance
	
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result := space_state.intersect_ray(query)
	
	if result.is_empty():
		_mesh_instance.visible = false
		_is_grounded = false
		return
	
	_is_grounded = true
	_mesh_instance.visible = true
	_current_ground_pos = result.position
	
	# Position shadow at hit point
	_mesh_instance.global_position = result.position + result.normal * ground_offset
	
	# Align to surface normal
	var up: Vector3 = result.normal
	var forward: Vector3 = Vector3.FORWARD
	if abs(up.dot(Vector3.FORWARD)) > 0.99:
		forward = Vector3.RIGHT
	var right: Vector3 = up.cross(forward).normalized()
	forward = right.cross(up).normalized()
	_mesh_instance.global_transform.basis = Basis(right, up, forward)
	
	# Scale based on distance
	if distance_scaling:
		var dist: float = parent_pos.distance_to(result.position)
		var scale_factor: float = remap(dist, 0.0, max_distance, 1.0, min_scale)
		scale_factor = clampf(scale_factor, min_scale, 1.0)
		_mesh_instance.scale = Vector3.ONE * scale_factor
	else:
		_mesh_instance.scale = Vector3.ONE


## ===== PUBLIC API =====

## Check if shadow is currently visible (ground detected)
func is_grounded() -> bool:
	return _is_grounded


## Get the ground position
func get_ground_position() -> Vector3:
	return _current_ground_pos


## Temporarily hide the shadow
func hide_shadow() -> void:
	if _mesh_instance:
		_mesh_instance.visible = false


## Show the shadow again
func show_shadow() -> void:
	if _mesh_instance:
		_mesh_instance.visible = true
