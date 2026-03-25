class_name XtremeCameraSystem
extends Camera3D

## Multi-mode camera system for Gina the Gecko.
##
## Supports three camera modes:
## - CURVED_WORLD_FOLLOW: Standard gameplay camera (Sonic Xtreme style)
## - DYNAMIC_BOSS: Boss encounter camera (no curved world, orbits arena)
## - SIDE_SCROLLER: 2D section camera (vertical curve only, locked plane)
##
## The system smoothly blends between modes and manages the curved world
## shader parameters per mode.

enum CameraMode {
	CURVED_WORLD_FOLLOW,  ## Standard gameplay: fixed orientation, follows player
	DYNAMIC_BOSS,         ## Boss fights: orbits midpoint of player + boss, no curve
	SIDE_SCROLLER,        ## 2D sections: locked plane, vertical-only curve
}

## The node to follow (usually the player character)
@export var target: Node3D

## Current camera mode
@export var current_mode: CameraMode = CameraMode.CURVED_WORLD_FOLLOW:
	set(value):
		if value != current_mode:
			_previous_mode = current_mode
			current_mode = value
			_transition_timer = 0.0
			_transition_start_pos = global_position
			_transition_start_rot = global_basis
			_on_mode_changed()

# ===== CURVED_WORLD_FOLLOW Settings =====
@export_group("Follow Mode")
## Vertical offset from the target position
@export var height_offset: float = 2.0

## Distance behind the target
@export var follow_distance: float = 8.0

## Fixed pitch angle in degrees
@export_range(-90, 90) var pitch_angle: float = -15.0

## Enable position smoothing
@export var smooth_position: bool = false

## Position smoothing speed
@export var smooth_speed: float = 10.0

# ===== DYNAMIC_BOSS Settings =====
@export_group("Boss Mode")
## The boss target node to track
@export var boss_target: Node3D

## Orbit height above the arena midpoint
@export var boss_cam_height: float = 8.0

## Orbit distance from the midpoint
@export var boss_cam_distance: float = 18.0

## Tracking blend: 0.0 = player only, 1.0 = boss only
@export_range(0.0, 1.0) var boss_player_blend: float = 0.3

## Camera pull-back multiplier for big attacks (triggered via signal)
@export var boss_pullback_multiplier: float = 1.5

# ===== SIDE_SCROLLER Settings =====
@export_group("Side-Scroller Mode")
## Which world axis to lock the camera on (0=X locked, 2=Z locked)
@export_range(0, 2, 2) var side_lock_axis: int = 2

## Offset along the locked axis (camera distance from the 2D plane)
@export var side_camera_distance: float = 15.0

## Horizontal lead distance ahead of the player's movement direction
@export var side_lead_distance: float = 3.0

## Vertical center: player positioned at this fraction from bottom (0.4 = 40%)
@export_range(0.0, 1.0) var side_vertical_center: float = 0.4

# ===== WALL FADE =====
@export_group("Wall Fade")
## Enable wall transparency when camera is obstructed
@export var wall_fade_enabled: bool = true

## How close to a wall before it starts fading
@export var fade_distance: float = 2.0

## Minimum opacity for faded walls
@export_range(0.0, 1.0) var min_opacity: float = 0.15

## Layers to check for wall collision
@export_flags_3d_physics var wall_collision_mask: int = 1

## How quickly walls fade in/out
@export var fade_speed: float = 8.0

# ===== CURVED WORLD SHADER =====
@export_group("Curved World Shader")
## Automatically find and update all curved world materials
@export var auto_update_materials: bool = true

## Manual list of materials to update
@export var curved_materials: Array[ShaderMaterial] = []

## Horizontal curve value for follow mode
@export_range(0.0, 0.3, 0.001) var curve_horizontal: float = 0.15

## Vertical curve value for follow mode
@export_range(0.0, 0.3, 0.001) var curve_vertical: float = 0.08

## Update shader center from camera (true) or target (false)
@export var shader_follows_camera: bool = false

# ===== TRANSITION =====
@export_group("Transition")
## Duration of camera mode transitions in seconds
@export var transition_duration: float = 0.5

@export_group("Debug")
@export var debug_draw: bool = false

# ===== Internal state =====
var _cached_materials: Array[ShaderMaterial] = []
var _materials_cached: bool = false

# Wall fade state (ported from XtremeCamera)
var _faded_objects: Dictionary = {}
var _fade_targets: Dictionary = {}

# Mode transition
var _transition_timer: float = 1.0  # Start at 1.0 = no transition active
var _transition_start_pos: Vector3
var _transition_start_rot: Basis
var _previous_mode: CameraMode = CameraMode.CURVED_WORLD_FOLLOW

# Boss mode
var _boss_pullback_active: bool = false
var _boss_pullback_timer: float = 0.0

# Side-scroller mode
var _side_lead_direction: float = 1.0  # 1.0 = right, -1.0 = left
var _last_target_x: float = 0.0

# Signals
signal mode_changed(new_mode: CameraMode)
signal boss_camera_ready()

func _ready() -> void:
	rotation.x = deg_to_rad(pitch_angle)
	rotation.y = 0
	rotation.z = 0

	if auto_update_materials:
		call_deferred("_cache_curved_materials")

func _process(delta: float) -> void:
	if not target:
		return

	# Update mode transition
	if _transition_timer < 1.0:
		_transition_timer = minf(_transition_timer + delta / transition_duration, 1.0)

	# Calculate desired position/rotation for current mode
	var desired_pos: Vector3
	var desired_rot: Basis

	match current_mode:
		CameraMode.CURVED_WORLD_FOLLOW:
			desired_pos = _calc_follow_position()
			desired_rot = Basis(Vector3.RIGHT, deg_to_rad(pitch_angle))
		CameraMode.DYNAMIC_BOSS:
			var result := _calc_boss_position(delta)
			desired_pos = result[0]
			desired_rot = result[1]
		CameraMode.SIDE_SCROLLER:
			var result := _calc_side_scroller_position(delta)
			desired_pos = result[0]
			desired_rot = result[1]

	# Apply transition blending
	if _transition_timer < 1.0:
		var t := smoothstep(0.0, 1.0, _transition_timer)
		global_position = _transition_start_pos.lerp(desired_pos, t)
		global_basis = _transition_start_rot.slerp(desired_rot, t)
	else:
		if smooth_position and current_mode == CameraMode.CURVED_WORLD_FOLLOW:
			global_position = global_position.lerp(desired_pos, smooth_speed * delta)
		else:
			global_position = desired_pos
		global_basis = desired_rot

	# Update shader and wall fade
	_update_shader_centers()
	_update_shader_curve_values()

	if wall_fade_enabled and current_mode != CameraMode.DYNAMIC_BOSS:
		_update_wall_fade(delta)

# ===== Mode position calculators =====

func _calc_follow_position() -> Vector3:
	var target_pos := target.global_position
	return Vector3(
		target_pos.x,
		target_pos.y + height_offset,
		target_pos.z + follow_distance
	)

func _calc_boss_position(delta: float) -> Array:
	var player_pos := target.global_position
	var boss_pos := boss_target.global_position if boss_target else player_pos

	# Track midpoint weighted by blend
	var track_point := player_pos.lerp(boss_pos, boss_player_blend)

	# Camera distance adapts to player-boss separation
	var separation := player_pos.distance_to(boss_pos)
	var adaptive_distance := boss_cam_distance + separation * 0.3

	# Pullback for big attacks
	if _boss_pullback_active:
		_boss_pullback_timer -= delta
		if _boss_pullback_timer <= 0.0:
			_boss_pullback_active = false
		else:
			adaptive_distance *= boss_pullback_multiplier

	# Position behind and above the tracking point
	var cam_pos := Vector3(
		track_point.x,
		track_point.y + boss_cam_height,
		track_point.z + adaptive_distance
	)

	# Look at the tracking point
	var dir := (track_point - cam_pos).normalized()
	var cam_basis := Basis.looking_at(dir, Vector3.UP)

	return [cam_pos, cam_basis]

func _calc_side_scroller_position(delta: float) -> Array:
	var player_pos := target.global_position

	# Track movement direction for lead
	var move_axis := 0 if side_lock_axis == 2 else 2  # If Z locked, move on X; if X locked, move on Z
	var current_pos_on_axis: float
	if move_axis == 0:
		current_pos_on_axis = player_pos.x
	else:
		current_pos_on_axis = player_pos.z

	if current_pos_on_axis > _last_target_x + 0.1:
		_side_lead_direction = 1.0
	elif current_pos_on_axis < _last_target_x - 0.1:
		_side_lead_direction = -1.0
	_last_target_x = current_pos_on_axis

	# Calculate camera position
	var cam_pos := player_pos
	# Apply lead in movement direction
	if move_axis == 0:
		cam_pos.x += side_lead_distance * _side_lead_direction
	else:
		cam_pos.z += side_lead_distance * _side_lead_direction

	# Offset on the locked axis
	if side_lock_axis == 2:
		cam_pos.z = player_pos.z + side_camera_distance
	else:
		cam_pos.x = player_pos.x + side_camera_distance

	# Vertical offset: player at side_vertical_center from bottom
	# This means camera is slightly above the player
	cam_pos.y += height_offset * (1.0 - side_vertical_center)

	# Look direction: perpendicular to the 2D plane
	var look_dir: Vector3
	if side_lock_axis == 2:
		look_dir = Vector3(0, 0, -1)
	else:
		look_dir = Vector3(-1, 0, 0)

	var cam_basis := Basis.looking_at(look_dir, Vector3.UP)

	return [cam_pos, cam_basis]

# ===== Shader management =====

func _update_shader_centers() -> void:
	var center_position: Vector3
	if shader_follows_camera:
		center_position = global_position
	else:
		center_position = target.global_position if target else global_position

	for mat in curved_materials:
		if mat and is_instance_valid(mat):
			mat.set_shader_parameter("curve_center", center_position)

	if auto_update_materials:
		for mat in _cached_materials:
			if mat and is_instance_valid(mat):
				mat.set_shader_parameter("curve_center", center_position)

func _update_shader_curve_values() -> void:
	## Set curve parameters based on current mode
	var h_curve: float
	var v_curve: float

	match current_mode:
		CameraMode.CURVED_WORLD_FOLLOW:
			h_curve = curve_horizontal
			v_curve = curve_vertical
		CameraMode.DYNAMIC_BOSS:
			# Boss mode: no curved world
			h_curve = 0.0
			v_curve = 0.0
		CameraMode.SIDE_SCROLLER:
			# Side-scroller: vertical curve only
			h_curve = 0.0
			v_curve = curve_vertical

	# Blend during transitions
	if _transition_timer < 1.0:
		var prev_h: float
		var prev_v: float
		match _previous_mode:
			CameraMode.CURVED_WORLD_FOLLOW:
				prev_h = curve_horizontal
				prev_v = curve_vertical
			CameraMode.DYNAMIC_BOSS:
				prev_h = 0.0
				prev_v = 0.0
			CameraMode.SIDE_SCROLLER:
				prev_h = 0.0
				prev_v = curve_vertical

		var t := smoothstep(0.0, 1.0, _transition_timer)
		h_curve = lerpf(prev_h, h_curve, t)
		v_curve = lerpf(prev_v, v_curve, t)

	var all_mats := curved_materials.duplicate()
	if auto_update_materials:
		all_mats.append_array(_cached_materials)

	for mat in all_mats:
		if mat and is_instance_valid(mat):
			mat.set_shader_parameter("curve_horizontal", h_curve)
			mat.set_shader_parameter("curve_vertical", v_curve)
			mat.set_shader_parameter("curve_intensity", 0.0)  # Deprecated

func _on_mode_changed() -> void:
	mode_changed.emit(current_mode)
	if current_mode == CameraMode.DYNAMIC_BOSS:
		boss_camera_ready.emit()

# ===== Wall fade (ported from XtremeCamera) =====

func _update_wall_fade(delta: float) -> void:
	if not target:
		return

	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return

	var from := global_position
	var to := target.global_position

	# Find all objects between camera and player
	var hit_colliders: Array[Node] = []
	var exclude_rids: Array[RID] = []
	var current_from := from

	for i in range(10):
		var query := PhysicsRayQueryParameters3D.create(current_from, to, wall_collision_mask)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = exclude_rids

		var result := space_state.intersect_ray(query)
		if result.is_empty():
			break

		if result.collider and result.collider not in hit_colliders:
			hit_colliders.append(result.collider)
		exclude_rids.append(result.rid)
		current_from = result.position + (to - from).normalized() * 0.1

	# Check for objects very close to camera
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

	# Find meshes to fade
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

	_apply_fade_transitions(delta)

func _find_nearby_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []

	if node is MeshInstance3D:
		result.append(node)

	var parent := node.get_parent()
	if parent:
		if parent is MeshInstance3D:
			result.append(parent)
		for sibling in parent.get_children():
			if sibling is MeshInstance3D and sibling not in result:
				result.append(sibling)
		var grandparent := parent.get_parent()
		if grandparent:
			for child in grandparent.get_children():
				if child is MeshInstance3D and child not in result:
					result.append(child)

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
		var new_opacity := lerpf(current_opacity, target_opacity, fade_speed * delta)
		fade_data.current_opacity = new_opacity

		_apply_opacity_to_object(obj, new_opacity, fade_data.original)

		if target_opacity >= 1.0 and new_opacity > 0.99:
			_restore_object_materials(obj, fade_data.original)
			objects_to_remove.append(obj)

	for obj in objects_to_remove:
		_faded_objects.erase(obj)
		_fade_targets.erase(obj)

func _capture_object_materials(obj: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if obj is MeshInstance3D:
		var mesh_inst := obj as MeshInstance3D
		if mesh_inst.material_override:
			result.append({"node": mesh_inst, "type": "override", "material": mesh_inst.material_override, "index": -1})
		elif mesh_inst.mesh:
			for i in range(mesh_inst.mesh.get_surface_count()):
				var mat := mesh_inst.get_active_material(i)
				if mat:
					result.append({"node": mesh_inst, "type": "surface", "material": mat, "index": i})
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

		var transparent_mat: Material
		if original_mat is StandardMaterial3D:
			transparent_mat = original_mat.duplicate()
			(transparent_mat as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			(transparent_mat as StandardMaterial3D).albedo_color.a = opacity
		elif original_mat is ShaderMaterial:
			transparent_mat = original_mat.duplicate()
			(transparent_mat as ShaderMaterial).set_shader_parameter("alpha", opacity)
			(transparent_mat as ShaderMaterial).set_shader_parameter("opacity", opacity)
		else:
			continue

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

# ===== Material caching =====

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
		print("[XtremeCameraSystem] Cached %d curved world materials" % _cached_materials.size())

func _find_curved_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mat := mesh_instance.material_override
		if _is_curved_world_material(mat) and mat not in _cached_materials:
			_cached_materials.append(mat)
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				mat = mesh_instance.mesh.surface_get_material(i)
				if _is_curved_world_material(mat) and mat not in _cached_materials:
					_cached_materials.append(mat)
				mat = mesh_instance.get_surface_override_material(i)
				if _is_curved_world_material(mat) and mat not in _cached_materials:
					_cached_materials.append(mat)
	for child in node.get_children():
		_find_curved_materials_recursive(child)

func _is_curved_world_material(mat: Material) -> bool:
	if mat is ShaderMaterial:
		var shader_mat := mat as ShaderMaterial
		if shader_mat.shader:
			return shader_mat.get_shader_parameter("curve_center") != null
	return false

# ===== Public API =====

## Switch to a new camera mode with smooth transition
func switch_mode(new_mode: CameraMode) -> void:
	current_mode = new_mode

## Trigger boss camera pullback (for big attack moments)
func trigger_boss_pullback(duration: float = 1.0) -> void:
	_boss_pullback_active = true
	_boss_pullback_timer = duration

## Refresh material cache (call after scene changes)
func refresh_material_cache() -> void:
	if auto_update_materials:
		_cache_curved_materials()

## Force restore all faded objects
func restore_all_faded() -> void:
	for obj in _faded_objects.keys():
		if is_instance_valid(obj):
			_restore_object_materials(obj, _faded_objects[obj].original)
	_faded_objects.clear()
	_fade_targets.clear()

## Set the player target
func set_target(new_target: Node3D) -> void:
	target = new_target

## Set the boss target (for DYNAMIC_BOSS mode)
func set_boss_target(new_boss: Node3D) -> void:
	boss_target = new_boss
