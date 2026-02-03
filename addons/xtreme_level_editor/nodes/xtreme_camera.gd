class_name XtremeCamera
extends Camera3D

## Xtreme Camera System
## A camera designed to work with the Sonic Xtreme-style curved world shader.
## 
## This camera:
## - Follows the player position exactly (no offset on position)
## - Maintains a fixed orientation (does not rotate)
## - Updates the curved world shader's center point each frame
## - Fades walls that obstruct the view between camera and player
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

@export_group("Wall Fade")
## Enable wall transparency when camera is obstructed
@export var wall_fade_enabled: bool = true

## How close to a wall before it starts fading (in world units)
@export var fade_distance: float = 2.0

## Minimum opacity for faded walls (0 = fully transparent)
@export_range(0.0, 1.0) var min_opacity: float = 0.15

## Layers to check for wall collision (set to your level geometry layer)
@export_flags_3d_physics var wall_collision_mask: int = 1

## How quickly walls fade in/out
@export var fade_speed: float = 8.0

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

# Wall fade state
var _faded_objects: Dictionary = {}  # Node -> original material data
var _fade_targets: Dictionary = {}   # Node -> target opacity (for smooth transitions)

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
	
	if wall_fade_enabled:
		_update_wall_fade(delta)

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

func _update_wall_fade(delta: float) -> void:
	if not target:
		return
	
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return
	
	# Cast ray from camera to player
	var from := global_position
	var to := target.global_position
	
	var query := PhysicsRayQueryParameters3D.create(from, to, wall_collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	# Find all collision hits between camera and player
	var hit_colliders: Array[Node] = []
	var exclude_rids: Array[RID] = []
	var current_from := from
	
	# Cast multiple rays to find all obstructing objects
	for i in range(10):  # Max 10 objects
		query = PhysicsRayQueryParameters3D.create(current_from, to, wall_collision_mask)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = exclude_rids
		
		var result := space_state.intersect_ray(query)
		if result.is_empty():
			break
		
		if result.collider and result.collider not in hit_colliders:
			hit_colliders.append(result.collider)
		exclude_rids.append(result.rid)
		
		# Move ray start past this hit
		current_from = result.position + (to - from).normalized() * 0.1
	
	# Also check for objects very close to camera
	var close_query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = fade_distance
	close_query.shape = sphere
	close_query.transform = Transform3D(Basis.IDENTITY, global_position)
	close_query.collision_mask = wall_collision_mask
	
	var close_results := space_state.intersect_shape(close_query, 32)
	for result in close_results:
		var collider := result.collider as Node
		if collider and collider not in hit_colliders:
			hit_colliders.append(collider)
	
	# Find meshes to fade - look for MeshInstance3D nodes near hits or as siblings of colliders
	var meshes_to_fade: Array[MeshInstance3D] = []
	
	for collider in hit_colliders:
		var found_meshes := _find_nearby_meshes(collider)
		for mesh in found_meshes:
			if mesh not in meshes_to_fade:
				meshes_to_fade.append(mesh)
	
	# Update fade targets
	for mesh in meshes_to_fade:
		_fade_targets[mesh] = min_opacity
	
	# Objects that should restore
	var objects_to_restore: Array[Node] = []
	for obj in _faded_objects.keys():
		if obj not in meshes_to_fade:
			objects_to_restore.append(obj)
	
	for obj in objects_to_restore:
		_fade_targets[obj] = 1.0
	
	# Apply fading
	_apply_fade_transitions(delta)

func _find_nearby_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	
	# Check the node itself
	if node is MeshInstance3D:
		result.append(node)
	
	# Check parent
	var parent := node.get_parent()
	if parent:
		if parent is MeshInstance3D:
			result.append(parent)
		
		# Check siblings (same parent) - this finds the batched meshes next to LevelCollision
		for sibling in parent.get_children():
			if sibling is MeshInstance3D and sibling not in result:
				result.append(sibling)
		
		# Check parent's parent and its children (for nested scene structures)
		var grandparent := parent.get_parent()
		if grandparent:
			for child in grandparent.get_children():
				if child is MeshInstance3D and child not in result:
					result.append(child)
	
	# Check children
	for child in node.get_children():
		if child is MeshInstance3D and child not in result:
			result.append(child)
	
	return result

func _apply_fade_transitions(delta: float) -> void:
	var objects_to_remove: Array[Node] = []
	
	for obj in _fade_targets.keys():
		if not is_instance_valid(obj):
			objects_to_remove.append(obj)
			continue
		
		var target_opacity: float = _fade_targets[obj]
		
		# Get or create fade state for this object
		if obj not in _faded_objects:
			var original_data := _capture_object_materials(obj)
			if original_data.is_empty():
				objects_to_remove.append(obj)
				continue
			_faded_objects[obj] = {
				"original": original_data,
				"current_opacity": 1.0
			}
		
		var fade_data: Dictionary = _faded_objects[obj]
		var current_opacity: float = fade_data.current_opacity
		
		# Lerp toward target
		var new_opacity := lerpf(current_opacity, target_opacity, fade_speed * delta)
		fade_data.current_opacity = new_opacity
		
		# Apply opacity
		_apply_opacity_to_object(obj, new_opacity, fade_data.original)
		
		# If fully restored, remove from tracking
		if target_opacity >= 1.0 and new_opacity > 0.99:
			_restore_object_materials(obj, fade_data.original)
			objects_to_remove.append(obj)
	
	# Cleanup
	for obj in objects_to_remove:
		_faded_objects.erase(obj)
		_fade_targets.erase(obj)

func _capture_object_materials(obj: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	if obj is MeshInstance3D:
		var mesh_inst := obj as MeshInstance3D
		if mesh_inst.material_override:
			result.append({
				"node": mesh_inst,
				"type": "override",
				"material": mesh_inst.material_override,
				"index": -1
			})
		elif mesh_inst.mesh:
			for i in range(mesh_inst.mesh.get_surface_count()):
				var mat := mesh_inst.get_active_material(i)
				if mat:
					result.append({
						"node": mesh_inst,
						"type": "surface",
						"material": mat,
						"index": i
					})
	
	# Check children recursively
	for child in obj.get_children():
		result.append_array(_capture_object_materials(child))
	
	return result

func _apply_opacity_to_object(obj: Node, opacity: float, original_data: Array[Dictionary]) -> void:
	for data in original_data:
		var node: MeshInstance3D = data.node
		if not is_instance_valid(node):
			continue
		
		var original_mat: Material = data.material
		if not original_mat:
			continue
		
		# Create or update transparent version
		var transparent_mat: Material
		if original_mat is StandardMaterial3D:
			var std_mat := original_mat as StandardMaterial3D
			transparent_mat = std_mat.duplicate()
			(transparent_mat as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			(transparent_mat as StandardMaterial3D).albedo_color.a = opacity
		elif original_mat is ShaderMaterial:
			var shader_mat := original_mat as ShaderMaterial
			transparent_mat = shader_mat.duplicate()
			# Try to set common opacity parameters
			(transparent_mat as ShaderMaterial).set_shader_parameter("alpha", opacity)
			(transparent_mat as ShaderMaterial).set_shader_parameter("opacity", opacity)
			(transparent_mat as ShaderMaterial).set_shader_parameter("albedo", 
				Color((transparent_mat as ShaderMaterial).get_shader_parameter("albedo")).lerp(Color.TRANSPARENT, 1.0 - opacity))
		else:
			continue
		
		# Apply the transparent material
		if data.type == "override":
			node.material_override = transparent_mat
		else:
			node.set_surface_override_material(data.index, transparent_mat)

func _restore_object_materials(obj: Node, original_data: Array[Dictionary]) -> void:
	for data in original_data:
		var node: MeshInstance3D = data.node
		if not is_instance_valid(node):
			continue
		
		if data.type == "override":
			node.material_override = data.material
		else:
			node.set_surface_override_material(data.index, null)

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
	if not is_inside_tree():
		return
	_cached_materials.clear()
	var tree := get_tree()
	if not tree or not tree.root:
		return
	_find_curved_materials_recursive(tree.root)
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

## Force restore all faded objects (call when changing scenes)
func restore_all_faded() -> void:
	for obj in _faded_objects.keys():
		if is_instance_valid(obj):
			_restore_object_materials(obj, _faded_objects[obj].original)
	_faded_objects.clear()
	_fade_targets.clear()
