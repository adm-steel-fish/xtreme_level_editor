@tool
class_name XtremeLevelExporter
extends RefCounted

## Optimized Level Exporter
## Supports two modes:
## - LEGACY_SINGLE_MESH: previous behavior (large batched meshes)
## - HYBRID_CHUNKED: static chunked meshes + interactive nodes kept as instances

enum ExportMode {
	LEGACY_SINGLE_MESH,
	HYBRID_CHUNKED,
}

var grid_settings: XtremeGridSettings
var tile_palette: XtremeTilePalette
var level_data: XtremeLevelData

# Export mode settings
var export_mode: ExportMode = ExportMode.HYBRID_CHUNKED
var static_chunk_size: Vector3i = Vector3i(16, 8, 16)
var instantiate_interactive_tiles: bool = true
var interactive_fallback_enabled: bool = true
var interactive_script_path: String = "res://addons/xtreme_level_editor/runtime/interactive_tile.gd"

# Traversal resources exported as runtime nodes
var grind_rails: Array[XtremeGrindRail] = []
var roller_coasters: Array[XtremeRollerCoaster] = []
var light_dash_trails: Array[XtremeLightDashTrail] = []
var export_traversal_nodes: bool = true
var export_light_dash_ring_nodes: bool = true
var grind_rail_script_path: String = "res://scripts/test_grind_rail.gd"
var auto_sequence_script_path: String = "res://scripts/test_auto_sequence_path.gd"
var test_currency_script_path: String = "res://scripts/test_currency.gd"

# Collision export tuning
var merge_unit_collision_runs: bool = true

# Curved world settings
var apply_curved_world: bool = true
var curve_horizontal: float = 0.15
var curve_vertical: float = 0.08
var curve_falloff_exponent: float = 2.0

# Distance effect settings
var distance_effects_enabled: bool = true
var effect_max_distance: float = 150.0
var wireframe_start: float = 0.3
var wireframe_full: float = 0.7
var dissolve_start: float = 0.3
var dissolve_full: float = 0.9

# Cached materials - shared across all tiles of same type
var _material_cache: Dictionary = {}

# Tile position lookup for hidden face removal
var _tile_positions: Dictionary = {}

# Rotation lookup
var _tile_rotations: Dictionary = {}


func export_level(path: String) -> Error:
	if not level_data or not grid_settings or not tile_palette:
		push_error("XtremeLevelExporter: Missing required data")
		return ERR_INVALID_DATA

	var root := Node3D.new()
	root.name = level_data.level_name.replace(" ", "_").replace(" ", "_")
	root.set_meta("xtreme_export_mode", int(export_mode))
	root.set_meta("xtreme_chunk_size", static_chunk_size)

	_build_tile_lookups()
	_validate_loop_critical_data()

	match export_mode:
		ExportMode.LEGACY_SINGLE_MESH:
			_export_legacy_single_mesh(root)
		ExportMode.HYBRID_CHUNKED:
			_export_hybrid_chunked(root)
		_:
			_export_hybrid_chunked(root)

	if export_traversal_nodes:
		_export_traversal_world(root)

	_assign_owner_recursive(root, root)

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("XtremeLevelExporter: Failed to pack scene")
		root.queue_free()
		_clear_caches()
		return err

	err = ResourceSaver.save(packed, path)
	root.queue_free()
	_clear_caches()
	return err


func _build_merged_tile_properties(tile_pos: Vector3i, tile_def: XtremeTileDefinition) -> Dictionary:
	var merged_props := tile_def.custom_properties.duplicate(true)
	if level_data and level_data.has_method("get_tile_instance_properties"):
		var instance_props: Dictionary = level_data.get_tile_instance_properties(tile_pos)
		for key in instance_props.keys():
			merged_props[key] = instance_props[key]
	return merged_props


func _is_loop_critical_tile(tile_def: XtremeTileDefinition) -> bool:
	match tile_def.tile_type:
		XtremeTileDefinition.TileType.HAZARD, \
		XtremeTileDefinition.TileType.COLLECTIBLE, \
		XtremeTileDefinition.TileType.CHECKPOINT, \
		XtremeTileDefinition.TileType.GOAL:
			return true
		_:
			return false


func _validate_loop_critical_data() -> void:
	var has_spawn := false
	var has_goal := false
	var checkpoint_usage: Dictionary = {}

	for tile_pos_variant in _tile_positions.keys():
		var tile_pos := tile_pos_variant as Vector3i
		var tile_id: StringName = _tile_positions[tile_pos]
		var tile_def := _get_tile_definition(tile_id)
		if not tile_def:
			continue

		match tile_def.tile_type:
			XtremeTileDefinition.TileType.SPAWN:
				has_spawn = true
			XtremeTileDefinition.TileType.GOAL:
				has_goal = true
			XtremeTileDefinition.TileType.CHECKPOINT:
				var props := _build_merged_tile_properties(tile_pos, tile_def)
				var checkpoint_id := str(props.get("checkpoint_id", "checkpoint_%d_%d_%d" % [tile_pos.x, tile_pos.y, tile_pos.z]))
				if checkpoint_id in checkpoint_usage:
					var first_pos: Vector3i = checkpoint_usage[checkpoint_id]
					push_warning(
						"XtremeLevelExporter: Duplicate checkpoint_id '%s' at %s and %s" % [
							checkpoint_id,
							first_pos,
							tile_pos
						]
					)
				else:
					checkpoint_usage[checkpoint_id] = tile_pos

	if not has_spawn:
		push_warning("XtremeLevelExporter: No spawn tile found in level export")
	if not has_goal:
		push_warning("XtremeLevelExporter: No goal tile found in level export")


func _build_tile_lookups() -> void:
	_tile_positions.clear()
	_tile_rotations.clear()

	var all_positions := level_data.get_all_tile_positions()
	for tile_pos in all_positions:
		var tile_id := level_data.get_tile(tile_pos)
		# Skip multi-cell part markers; only export anchors.
		if tile_id == &"_multicell_part":
			continue
		_tile_positions[tile_pos] = tile_id
		_tile_rotations[tile_pos] = level_data.get_tile_rotation(tile_pos)


func _export_legacy_single_mesh(root: Node3D) -> void:
	# Group tiles by type and rotation.
	var tiles_by_type_rotation: Dictionary = {}

	for tile_pos in _tile_positions.keys():
		var tile_id: StringName = _tile_positions[tile_pos]
		var rotation: Vector3i = _tile_rotations.get(tile_pos, Vector3i.ZERO)
		var batch_key := _build_batch_key(tile_id, rotation)

		if batch_key not in tiles_by_type_rotation:
			tiles_by_type_rotation[batch_key] = {
				"tile_id": tile_id,
				"rotation": rotation,
				"positions": []
			}
		tiles_by_type_rotation[batch_key]["positions"].append(tile_pos)

	# Create one batched mesh per tile type + rotation combination.
	for batch_key in tiles_by_type_rotation.keys():
		var batch_data: Dictionary = tiles_by_type_rotation[batch_key]
		var tile_id: StringName = batch_data["tile_id"]
		var rotation: Vector3i = batch_data["rotation"]
		var positions: Array = batch_data["positions"]

		if positions.is_empty():
			continue

		var tile_def := _get_tile_definition(tile_id)
		if not tile_def:
			continue

		var batched_mesh := _create_batched_mesh_with_rotation(positions, tile_def, rotation)
		if batched_mesh:
			root.add_child(batched_mesh)

	# Add collision for all solid tiles.
	var collision_body := _create_collision_body_from_positions(_tile_positions.keys())
	if collision_body:
		root.add_child(collision_body)


func _export_hybrid_chunked(root: Node3D) -> void:
	var static_world := Node3D.new()
	static_world.name = "StaticWorld"
	static_world.add_to_group("xtreme_static_world", true)
	root.add_child(static_world)

	var interactive_world := Node3D.new()
	interactive_world.name = "InteractiveWorld"
	interactive_world.add_to_group("xtreme_interactive_world", true)
	root.add_child(interactive_world)

	# chunk_key -> {coord: Vector3i, batches: Dictionary, solid_positions: Array}
	var static_chunks: Dictionary = {}

	for tile_pos_variant in _tile_positions.keys():
		var tile_pos := tile_pos_variant as Vector3i
		var tile_id: StringName = _tile_positions[tile_pos]
		var tile_def := _get_tile_definition(tile_id)
		if not tile_def:
			continue

		var rotation: Vector3i = _tile_rotations.get(tile_pos, Vector3i.ZERO)
		var requires_runtime_interactive := _is_loop_critical_tile(tile_def)
		if (instantiate_interactive_tiles and _is_interactive_tile(tile_def)) or requires_runtime_interactive:
			_add_interactive_tile_instance(interactive_world, tile_pos, tile_def, rotation)
			continue

		var chunk_coord := _cell_to_chunk(tile_pos)
		var chunk_key := _build_chunk_key(chunk_coord)
		if chunk_key not in static_chunks:
			static_chunks[chunk_key] = {
				"coord": chunk_coord,
				"batches": {},
				"solid_positions": [],
				"mesh_collision": {}
			}

		var batches: Dictionary = static_chunks[chunk_key]["batches"]
		var batch_key := _build_batch_key(tile_id, rotation)
		if batch_key not in batches:
			batches[batch_key] = {
				"tile_def": tile_def,
				"rotation": rotation,
				"positions": []
			}
		batches[batch_key]["positions"].append(tile_pos)

		# Collision routing: grid-cell tiles feed the run-merged box body,
		# MESH_EXACT tiles get their own trimesh, NONE gets nothing.
		if tile_def.contributes_grid_collision():
			static_chunks[chunk_key]["solid_positions"].append(tile_pos)
		elif tile_def.is_solid and tile_def.has_custom_mesh() \
				and tile_def.mesh_collision == XtremeTileDefinition.MeshCollision.MESH_EXACT:
			var exact: Dictionary = static_chunks[chunk_key]["mesh_collision"]
			if batch_key not in exact:
				exact[batch_key] = {
					"tile_def": tile_def,
					"rotation": rotation,
					"positions": []
				}
			exact[batch_key]["positions"].append(tile_pos)

	for chunk_key in static_chunks.keys():
		var chunk_data: Dictionary = static_chunks[chunk_key]
		var chunk_coord: Vector3i = chunk_data["coord"]
		var chunk_node := Node3D.new()
		chunk_node.name = "StaticChunk_%d_%d_%d" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
		chunk_node.set_meta("xtreme_chunk_coord", chunk_coord)
		chunk_node.add_to_group("xtreme_static_chunk", true)
		static_world.add_child(chunk_node)

		var batches: Dictionary = chunk_data["batches"]
		for batch_key in batches.keys():
			var batch_data: Dictionary = batches[batch_key]
			var positions: Array = batch_data["positions"]
			var tile_def: XtremeTileDefinition = batch_data["tile_def"]
			var rotation: Vector3i = batch_data["rotation"]
			var batched_mesh := _create_batched_mesh_with_rotation(positions, tile_def, rotation)
			if batched_mesh:
				chunk_node.add_child(batched_mesh)

		var solid_positions: Array = chunk_data["solid_positions"]
		if not solid_positions.is_empty():
			var chunk_collision := _create_collision_body_from_positions(solid_positions)
			if chunk_collision:
				chunk_node.add_child(chunk_collision)

		# Exact-silhouette collision for custom-mesh tiles that asked for it.
		var mesh_collision: Dictionary = chunk_data["mesh_collision"]
		for exact_key in mesh_collision.keys():
			var exact_data: Dictionary = mesh_collision[exact_key]
			var exact_body := _create_mesh_collision_body(
				exact_data["positions"], exact_data["tile_def"], exact_data["rotation"])
			if exact_body:
				chunk_node.add_child(exact_body)


func _export_traversal_world(root: Node3D) -> void:
	var has_rails := not grind_rails.is_empty()
	var has_coasters := not roller_coasters.is_empty()
	var has_dash_trails := export_light_dash_ring_nodes and not light_dash_trails.is_empty()
	if not has_rails and not has_coasters and not has_dash_trails:
		return

	var cell_size := grid_settings.get_cell_size()
	var traversal_world := Node3D.new()
	traversal_world.name = "TraversalWorld"
	traversal_world.add_to_group("xtreme_traversal_world", true)
	root.add_child(traversal_world)

	if has_rails:
		var rails_root := Node3D.new()
		rails_root.name = "GrindRails"
		rails_root.add_to_group("rails", true)
		traversal_world.add_child(rails_root)
		for i in range(grind_rails.size()):
			var rail := grind_rails[i]
			if not rail or rail.control_points.size() < 2:
				continue
			var rail_node := _build_grind_rail_path(rail, i, cell_size)
			if rail_node:
				rails_root.add_child(rail_node)

	if has_coasters:
		var coaster_root := Node3D.new()
		coaster_root.name = "AutoSequences"
		coaster_root.add_to_group("auto_sequence", true)
		traversal_world.add_child(coaster_root)
		for i in range(roller_coasters.size()):
			var coaster := roller_coasters[i]
			if not coaster or coaster.control_points.size() < 2:
				continue
			var sequence_node := _build_auto_sequence_path(coaster, i)
			if sequence_node:
				coaster_root.add_child(sequence_node)

	if has_dash_trails:
		var trails_root := Node3D.new()
		trails_root.name = "LightDashTrails"
		traversal_world.add_child(trails_root)
		for i in range(light_dash_trails.size()):
			var trail := light_dash_trails[i]
			if not trail or trail.ring_positions.size() < 2:
				continue
			var trail_node := _build_light_dash_trail_node(trail, i, cell_size)
			if trail_node:
				trails_root.add_child(trail_node)


func _build_grind_rail_path(rail: XtremeGrindRail, index: int, cell_size: Vector3) -> Path3D:
	var path := Path3D.new()
	path.name = "Rail_%02d_%s" % [index, rail.display_name.replace(" ", "_")]

	var curve := Curve3D.new()
	curve.bake_interval = 0.2
	for point in rail.control_points:
		curve.add_point(_grid_point_to_world_center(point, cell_size))
	curve.closed = rail.is_loop
	path.curve = curve

	path.add_to_group("rails", true)
	path.add_to_group("targetable", true)
	path.set_meta("xtreme_rail_id", rail.rail_id)
	path.set_meta("xtreme_allow_jump_off", rail.allow_jump_off)
	path.set_meta("xtreme_allow_crouch_boost", rail.allow_crouch_boost)
	path.set_meta("xtreme_speed_multiplier", rail.speed_multiplier)
	path.set_meta("xtreme_crouch_speed_multiplier", rail.crouch_speed_multiplier)

	var script := load(grind_rail_script_path) as Script
	if script:
		path.set_script(script)
		if _node_has_property(path, "debug_color"):
			path.set("debug_color", rail.editor_color)
		if _node_has_property(path, "show_debug_mesh"):
			path.set("show_debug_mesh", true)

	return path


func _build_auto_sequence_path(coaster: XtremeRollerCoaster, index: int) -> Path3D:
	var path := Path3D.new()
	path.name = "AutoSequence_%02d_%s" % [index, coaster.display_name.replace(" ", "_")]

	var curve := Curve3D.new()
	curve.bake_interval = 0.2
	for point in coaster.control_points:
		curve.add_point(point)
	curve.closed = coaster.is_loop
	path.curve = curve

	path.set_meta("xtreme_coaster_id", coaster.coaster_id)
	path.set_meta("xtreme_locked_ride", coaster.locked_ride)
	path.set_meta("xtreme_base_speed", coaster.base_speed)
	path.set_meta("xtreme_ride_duration", coaster.ride_duration)

	var script := load(auto_sequence_script_path) as Script
	if script:
		path.set_script(script)
		# XtremeTestAutoSequencePath.SequenceType.ROLLER_COASTER == 1
		if _node_has_property(path, "sequence_type"):
			path.set("sequence_type", 1)
		if _node_has_property(path, "auto_speed"):
			path.set("auto_speed", coaster.base_speed)
		if _node_has_property(path, "entry_trigger_radius"):
			path.set("entry_trigger_radius", coaster.entry_radius)
		if _node_has_property(path, "start_from_beginning"):
			path.set("start_from_beginning", true)
		if _node_has_property(path, "mount_height_offset"):
			path.set("mount_height_offset", 0.9)
		if _node_has_property(path, "debug_color"):
			path.set("debug_color", coaster.editor_color)
		if _node_has_property(path, "coaster_color"):
			path.set("coaster_color", coaster.editor_color)
		if _node_has_property(path, "coaster_track_width"):
			path.set("coaster_track_width", maxf(coaster.track_width, 0.8))
	else:
		path.add_to_group("auto_sequence", true)

	return path


func _build_light_dash_trail_node(trail: XtremeLightDashTrail, trail_index: int, cell_size: Vector3) -> Node3D:
	var trail_root := Node3D.new()
	trail_root.name = "DashTrail_%02d_%s" % [trail_index, trail.display_name.replace(" ", "_")]
	trail_root.set_meta("xtreme_trail_id", trail.trail_id)
	trail_root.set_meta("xtreme_dash_speed", trail.dash_speed)
	trail_root.set_meta("xtreme_is_loop", trail.is_loop)

	var dedicated_alpha := clampf(trail.dedicated_ring_alpha, 0.0, 1.0)
	for ring_index in range(trail.ring_positions.size()):
		var ring_pos := trail.get_ring_world_position(ring_index, cell_size)
		var dedicated := ring_index < trail.is_dedicated_ring.size() and trail.is_dedicated_ring[ring_index]
		var ring_node := _create_light_dash_ring_node(trail, dedicated, dedicated_alpha)
		if not ring_node:
			continue
		ring_node.name = "Ring_%03d" % ring_index
		ring_node.position = ring_pos
		ring_node.set_meta("xtreme_trail_id", trail.trail_id)
		ring_node.set_meta("xtreme_trail_index", ring_index)
		ring_node.set_meta("xtreme_dedicated_ring", dedicated)
		trail_root.add_child(ring_node)

	return trail_root


func _create_light_dash_ring_node(trail: XtremeLightDashTrail, dedicated: bool, dedicated_alpha: float) -> Node3D:
	if trail.ring_scene:
		var instance := trail.ring_scene.instantiate()
		var ring_root := instance as Node3D
		if ring_root:
			_configure_light_dash_ring_node(ring_root, dedicated, dedicated_alpha)
			return ring_root

		var wrapper := Node3D.new()
		wrapper.add_child(instance)
		_configure_light_dash_ring_node(wrapper, dedicated, dedicated_alpha)
		return wrapper

	var area := Area3D.new()
	_configure_light_dash_ring_node(area, dedicated, dedicated_alpha)
	area.collision_layer = 4
	area.collision_mask = 1

	var script := load(test_currency_script_path) as Script
	if script:
		area.set_script(script)
	if _node_has_property(area, "value"):
		area.set("value", 1)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = 0.3
	shape.radius = 0.4
	collision.shape = shape
	collision.rotation_degrees.x = 90.0
	area.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	# Name it explicitly: XtremeTestCurrency looks up its mesh child, and an
	# unnamed node would be auto-named "@MeshInstance3D@N" instead.
	mesh_instance.name = "MeshInstance3D"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.15
	mesh.outer_radius = 0.4
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees.x = 90.0
	# Rings must use a curved-world-aware shader or they float off the bent
	# ground. RetroMaterial.create_ring() builds one on the retro unlit shader.
	var material: Material = RetroMaterial.create_ring()
	if material == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(1.0, 0.88, 0.12, 1.0)
		fallback.metallic = 0.7
		fallback.roughness = 0.25
		material = fallback
	mesh_instance.material_override = material
	area.add_child(mesh_instance)

	return area


func _configure_light_dash_ring_node(node: Node3D, dedicated: bool, dedicated_alpha: float) -> void:
	node.add_to_group("currency", true)
	if dedicated:
		node.add_to_group("light_dash_dedicated", true)

	if _node_has_property(node, "collectible"):
		node.set("collectible", true)
	if _node_has_property(node, "spawn_dash_residual_on_collect"):
		node.set("spawn_dash_residual_on_collect", true)
	if _node_has_property(node, "dash_residual_alpha"):
		var residual_alpha := clampf(maxf(dedicated_alpha, 0.18), 0.05, 1.0)
		node.set("dash_residual_alpha", residual_alpha)
	if _node_has_property(node, "dash_residual_scale"):
		node.set("dash_residual_scale", 0.92)


func _grid_point_to_world_center(point: Vector3, cell_size: Vector3) -> Vector3:
	return Vector3(
		point.x * cell_size.x + cell_size.x * 0.5,
		point.y * cell_size.y + cell_size.y * 0.5,
		point.z * cell_size.z + cell_size.z * 0.5
	)


func _create_batched_mesh_with_rotation(positions: Array, tile_def: XtremeTileDefinition, rotation: Vector3i) -> MeshInstance3D:
	if positions.is_empty():
		return null

	var visual_size := _get_tile_visual_size(tile_def, rotation)
	var use_custom_mesh := tile_def.has_custom_mesh()

	# Use ArrayMesh to combine all cubes into one mesh.
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Track bounds for custom AABB.
	var min_bounds := Vector3(INF, INF, INF)
	var max_bounds := Vector3(-INF, -INF, -INF)

	# Create rotation basis for rotating vertices.
	var rot_basis := Basis.IDENTITY
	if rotation != Vector3i.ZERO:
		rot_basis = Basis.from_euler(Vector3(
			rotation.x * PI / 2.0,
			rotation.y * PI / 2.0,
			rotation.z * PI / 2.0
		))

	# Custom meshes are baked once per placement, so read their layout up front:
	# SurfaceTool requires every vertex in a surface to carry the same attributes.
	var mesh_layout := {}
	var mesh_local := Transform3D.IDENTITY
	if use_custom_mesh:
		mesh_layout = _describe_mesh_attributes(tile_def.mesh)
		mesh_local = tile_def.get_mesh_local_transform()

	for pos_variant in positions:
		var pos := pos_variant as Vector3i
		var world_pos := _get_tile_world_center(pos, tile_def, rotation)

		# Update bounds.
		min_bounds = min_bounds.min(world_pos - visual_size * 0.5)
		max_bounds = max_bounds.max(world_pos + visual_size * 0.5)

		if use_custom_mesh:
			# Grid rotation is applied on top of the mesh's own base orientation.
			var instance_xform := Transform3D(rot_basis, world_pos) * mesh_local
			var mesh_aabb := _append_mesh_to_surface(
				surface_tool, tile_def.mesh, instance_xform, mesh_layout)
			# A custom mesh may overflow its cell, so grow the bounds to match.
			min_bounds = min_bounds.min(mesh_aabb.position)
			max_bounds = max_bounds.max(mesh_aabb.position + mesh_aabb.size)
		else:
			# Add cube with hidden face removal and rotation.
			_add_cube_with_occlusion_rotated(surface_tool, pos, world_pos, visual_size, rot_basis)

	# Only synthesise normals when the source geometry did not supply them;
	# regenerating over an imported mesh flattens its intended shading.
	if not use_custom_mesh or not bool(mesh_layout.get("has_normals", false)):
		surface_tool.generate_normals()
	var array_mesh := surface_tool.commit()
	if not array_mesh or array_mesh.get_surface_count() == 0:
		return null

	var mesh_instance := MeshInstance3D.new()
	var rot_suffix := ""
	if rotation != Vector3i.ZERO:
		rot_suffix = "_r%d%d%d" % [rotation.x, rotation.y, rotation.z]
	mesh_instance.name = str(tile_def.tile_id) + rot_suffix + "_batch"
	mesh_instance.mesh = array_mesh

	# Expand AABB for curved world shader displacement.
	var max_curve := maxf(curve_horizontal, curve_vertical)
	var aabb_expansion := max_curve * effect_max_distance * effect_max_distance * 2.0
	var expanded_min := min_bounds - Vector3(aabb_expansion, aabb_expansion, aabb_expansion)
	var expanded_max := max_bounds + Vector3(aabb_expansion, aabb_expansion, aabb_expansion)
	mesh_instance.custom_aabb = AABB(expanded_min, expanded_max - expanded_min)

	# Shared material per tile type. Custom meshes may opt out to keep their own
	# surface materials — at the cost of not bending with the curved world.
	if use_custom_mesh and tile_def.mesh_keep_own_materials:
		var baked := _get_first_mesh_material(tile_def.mesh)
		if baked:
			mesh_instance.material_override = baked
		else:
			push_warning("XtremeLevelExporter: tile '%s' has mesh_keep_own_materials set but its mesh has no material; falling back to the curved-world material" % tile_def.tile_id)
			mesh_instance.material_override = _get_or_create_material(tile_def)
	else:
		mesh_instance.material_override = _get_or_create_material(tile_def)
	return mesh_instance


## SurfaceTool needs every vertex in a surface to carry identical attributes, so
## decide once per mesh which channels exist rather than per vertex.
func _describe_mesh_attributes(mesh: Mesh) -> Dictionary:
	var layout := {"has_normals": false, "has_uvs": false, "has_colors": false}
	if mesh == null or mesh.get_surface_count() == 0:
		return layout
	# Judge from the first surface; mixed-layout surfaces fall back to whatever
	# the first one declares, which keeps the committed surface valid.
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays.size() > Mesh.ARRAY_MAX:
		return layout
	layout["has_normals"] = arrays[Mesh.ARRAY_NORMAL] != null
	layout["has_uvs"] = arrays[Mesh.ARRAY_TEX_UV] != null
	layout["has_colors"] = arrays[Mesh.ARRAY_COLOR] != null
	return layout


## Bake every surface of `mesh` into `st`, transformed into world space.
## Returns the world-space AABB of what was appended.
##
## Indexed geometry is expanded into a flat triangle list on purpose: the
## curved-world shader derives its wireframe barycentrics from VERTEX_ID % 3,
## which is only correct for non-indexed meshes. Imported meshes are almost
## always indexed, so skipping this would silently break the wireframe.
func _append_mesh_to_surface(
	st: SurfaceTool,
	mesh: Mesh,
	xform: Transform3D,
	layout: Dictionary
) -> AABB:
	var bounds := AABB(xform.origin, Vector3.ZERO)
	var first := true
	if mesh == null:
		return bounds

	var normal_basis := xform.basis.inverse().transposed()
	var has_normals := bool(layout.get("has_normals", false))
	var has_uvs := bool(layout.get("has_uvs", false))
	var has_colors := bool(layout.get("has_colors", false))

	for surface_index in range(mesh.get_surface_count()):
		# surface_get_primitive_type() only exists on ArrayMesh. PrimitiveMesh
		# subclasses (BoxMesh, SphereMesh, imported primitives...) are always
		# triangles, so only screen the ones we can ask.
		if mesh is ArrayMesh:
			if (mesh as ArrayMesh).surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
				continue
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

		# Walk indices when present so the output is de-indexed.
		var count := indices.size() if not indices.is_empty() else verts.size()
		for i in range(count):
			var vi := indices[i] if not indices.is_empty() else i
			if vi < 0 or vi >= verts.size():
				continue

			if has_normals:
				var n := normals[vi] if vi < normals.size() else Vector3.UP
				st.set_normal((normal_basis * n).normalized())
			if has_uvs:
				st.set_uv(uvs[vi] if vi < uvs.size() else Vector2.ZERO)
			if has_colors:
				st.set_color(colors[vi] if vi < colors.size() else Color.WHITE)

			var world_v: Vector3 = xform * verts[vi]
			st.add_vertex(world_v)

			if first:
				bounds = AABB(world_v, Vector3.ZERO)
				first = false
			else:
				bounds = bounds.expand(world_v)

	return bounds


## Build one trimesh StaticBody3D covering every placement of a MESH_EXACT tile
## within a chunk. Batched per tile type so a chunk gets a handful of bodies
## rather than one per cell.
func _create_mesh_collision_body(
	positions: Array,
	tile_def: XtremeTileDefinition,
	rotation: Vector3i
) -> StaticBody3D:
	if positions.is_empty() or not tile_def.has_custom_mesh():
		return null

	var rot_basis := Basis.IDENTITY
	if rotation != Vector3i.ZERO:
		rot_basis = Basis.from_euler(Vector3(
			rotation.x * PI / 2.0,
			rotation.y * PI / 2.0,
			rotation.z * PI / 2.0
		))
	var mesh_local := tile_def.get_mesh_local_transform()
	var layout := _describe_mesh_attributes(tile_def.mesh)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pos_variant in positions:
		var pos := pos_variant as Vector3i
		var world_pos := _get_tile_world_center(pos, tile_def, rotation)
		var instance_xform := Transform3D(rot_basis, world_pos) * mesh_local
		_append_mesh_to_surface(st, tile_def.mesh, instance_xform, layout)

	if not bool(layout.get("has_normals", false)):
		st.generate_normals()
	var collision_mesh := st.commit()
	if collision_mesh == null or collision_mesh.get_surface_count() == 0:
		return null

	var shape := collision_mesh.create_trimesh_shape()
	if shape == null:
		push_warning("XtremeLevelExporter: could not build trimesh collision for tile '%s'" % tile_def.tile_id)
		return null

	var body := StaticBody3D.new()
	body.name = "%s_MeshCollision" % str(tile_def.tile_id)
	var col := CollisionShape3D.new()
	col.name = "Shape"
	col.shape = shape
	body.add_child(col)
	return body


## First non-null surface material on a mesh, if any.
func _get_first_mesh_material(mesh: Mesh) -> Material:
	if mesh == null:
		return null
	for i in range(mesh.get_surface_count()):
		var m := mesh.surface_get_material(i)
		if m:
			return m
	return null


func _add_cube_with_occlusion_rotated(st: SurfaceTool, grid_pos: Vector3i, center: Vector3, size: Vector3, rot_basis: Basis) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var local_verts := [
		Vector3(-hx, -hy, -hz),  # 0: back-bottom-left
		Vector3(hx, -hy, -hz),   # 1: back-bottom-right
		Vector3(hx, hy, -hz),    # 2: back-top-right
		Vector3(-hx, hy, -hz),   # 3: back-top-left
		Vector3(-hx, -hy, hz),   # 4: front-bottom-left
		Vector3(hx, -hy, hz),    # 5: front-bottom-right
		Vector3(hx, hy, hz),     # 6: front-top-right
		Vector3(-hx, hy, hz),    # 7: front-top-left
	]

	var v: Array[Vector3] = []
	for local_v in local_verts:
		v.append(center + rot_basis * local_v)

	# Front (+Z)
	if not _has_solid_neighbor(grid_pos, Vector3i(0, 0, 1)):
		_add_quad(st, v[4], v[7], v[6], v[5])
	# Back (-Z)
	if not _has_solid_neighbor(grid_pos, Vector3i(0, 0, -1)):
		_add_quad(st, v[1], v[2], v[3], v[0])
	# Top (+Y)
	if not _has_solid_neighbor(grid_pos, Vector3i(0, 1, 0)):
		_add_quad(st, v[3], v[2], v[6], v[7])
	# Bottom (-Y)
	if not _has_solid_neighbor(grid_pos, Vector3i(0, -1, 0)):
		_add_quad(st, v[0], v[4], v[5], v[1])
	# Right (+X)
	if not _has_solid_neighbor(grid_pos, Vector3i(1, 0, 0)):
		_add_quad(st, v[1], v[5], v[6], v[2])
	# Left (-X)
	if not _has_solid_neighbor(grid_pos, Vector3i(-1, 0, 0)):
		_add_quad(st, v[0], v[3], v[7], v[4])


func _has_solid_neighbor(pos: Vector3i, offset: Vector3i) -> bool:
	var neighbor_pos := pos + offset
	if neighbor_pos not in _tile_positions:
		return false

	var neighbor_tile_id: StringName = _tile_positions[neighbor_pos]
	var neighbor_def := _get_tile_definition(neighbor_tile_id)
	return neighbor_def != null and neighbor_def.is_solid


func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	var uv0 := Vector2(0.0, 0.0)
	var uv1 := Vector2(1.0, 0.0)
	var uv2 := Vector2(1.0, 1.0)
	var uv3 := Vector2(0.0, 1.0)

	st.set_uv(uv0)
	st.add_vertex(v0)
	st.set_uv(uv1)
	st.add_vertex(v1)
	st.set_uv(uv2)
	st.add_vertex(v2)

	st.set_uv(uv0)
	st.add_vertex(v0)
	st.set_uv(uv2)
	st.add_vertex(v2)
	st.set_uv(uv3)
	st.add_vertex(v3)


func _create_collision_body_from_positions(positions: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "LevelCollision"
	var shape_count := 0

	var cell_size := grid_settings.get_cell_size()
	var unit_cells: Dictionary = {}
	var extra_boxes: Array[Dictionary] = []

	for pos_variant in positions:
		var tile_pos := pos_variant as Vector3i
		var tile_id: StringName = _tile_positions.get(tile_pos, &"")
		var tile_def := _get_tile_definition(tile_id)
		if not tile_def or not tile_def.is_solid:
			continue

		var rotation: Vector3i = _tile_rotations.get(tile_pos, Vector3i.ZERO)
		var size := _get_tile_visual_size(tile_def, rotation)
		var center := _get_tile_world_center(tile_pos, tile_def, rotation)
		var is_unit := is_equal_approx(size.x, cell_size.x) and is_equal_approx(size.y, cell_size.y) and is_equal_approx(size.z, cell_size.z)

		if merge_unit_collision_runs and is_unit:
			unit_cells[tile_pos] = true
			continue

		extra_boxes.append({
			"pos": tile_pos,
			"size": size,
			"center": center
		})

	# Merge contiguous 1x1x1 cells along X to reduce collider count in large flat areas.
	if merge_unit_collision_runs and not unit_cells.is_empty():
		var min_x := 2147483647
		var min_y := 2147483647
		var min_z := 2147483647
		var max_x := -2147483648
		var max_y := -2147483648
		var max_z := -2147483648

		for key in unit_cells.keys():
			var cell := key as Vector3i
			min_x = mini(min_x, cell.x)
			min_y = mini(min_y, cell.y)
			min_z = mini(min_z, cell.z)
			max_x = maxi(max_x, cell.x)
			max_y = maxi(max_y, cell.y)
			max_z = maxi(max_z, cell.z)

		for y in range(min_y, max_y + 1):
			for z in range(min_z, max_z + 1):
				var x := min_x
				while x <= max_x:
					var start_cell := Vector3i(x, y, z)
					if not unit_cells.has(start_cell):
						x += 1
						continue

					var run_start := x
					var run_end := x
					while run_end + 1 <= max_x and unit_cells.has(Vector3i(run_end + 1, y, z)):
						run_end += 1

					for erase_x in range(run_start, run_end + 1):
						unit_cells.erase(Vector3i(erase_x, y, z))

					var run_len := run_end - run_start + 1
					var collision := CollisionShape3D.new()
					collision.name = "ColRun_%d_%d_%d" % [run_start, y, z]
					var box := BoxShape3D.new()
					box.size = Vector3(cell_size.x * run_len, cell_size.y, cell_size.z)
					collision.shape = box
					collision.position = Vector3(
						(run_start * cell_size.x) + (cell_size.x * run_len * 0.5),
						(y * cell_size.y) + (cell_size.y * 0.5),
						(z * cell_size.z) + (cell_size.z * 0.5)
					)
					body.add_child(collision)
					shape_count += 1
					x = run_end + 1

	for box_data in extra_boxes:
		var tile_pos: Vector3i = box_data["pos"]
		var collision := CollisionShape3D.new()
		collision.name = "Col_%d_%d_%d" % [tile_pos.x, tile_pos.y, tile_pos.z]
		var box := BoxShape3D.new()
		box.size = box_data["size"]
		collision.shape = box
		collision.position = box_data["center"]
		body.add_child(collision)
		shape_count += 1

	return body if shape_count > 0 else null


func _add_interactive_tile_instance(parent: Node3D, tile_pos: Vector3i, tile_def: XtremeTileDefinition, rotation: Vector3i) -> void:
	var instance: Node = null
	if tile_def.tile_scene:
		instance = tile_def.tile_scene.instantiate()
	elif interactive_fallback_enabled:
		instance = _create_fallback_interactive(tile_def, rotation)
	elif _is_loop_critical_tile(tile_def):
		# Loop-critical tiles must still export as runtime interactives.
		instance = _create_generic_interactive_fallback(tile_def, rotation)

	if not instance:
		return

	var transform_root: Node3D = null
	if instance is Node3D:
		transform_root = instance as Node3D
	else:
		var wrapper := Node3D.new()
		wrapper.name = "%s_wrapper_%d_%d_%d" % [tile_def.tile_id, tile_pos.x, tile_pos.y, tile_pos.z]
		wrapper.add_child(instance)
		transform_root = wrapper

	transform_root.name = "%s_%d_%d_%d" % [tile_def.tile_id, tile_pos.x, tile_pos.y, tile_pos.z]
	_apply_tile_transform(transform_root, tile_pos, tile_def, rotation)
	parent.add_child(transform_root)

	_apply_export_properties(instance, tile_pos, tile_def, rotation)
	_apply_export_groups(transform_root, tile_def)


func _apply_export_groups(node: Node, tile_def: XtremeTileDefinition) -> void:
	match tile_def.tile_type:
		XtremeTileDefinition.TileType.ENEMY:
			node.add_to_group("enemies", true)
			node.add_to_group("targetable", true)
		XtremeTileDefinition.TileType.COLLECTIBLE:
			node.add_to_group("currency", true)
		XtremeTileDefinition.TileType.RAIL:
			node.add_to_group("rails", true)
			node.add_to_group("targetable", true)
		XtremeTileDefinition.TileType.WATER:
			node.add_to_group("water_zone", true)
		_:
			pass


func _apply_export_properties(instance: Node, tile_pos: Vector3i, tile_def: XtremeTileDefinition, rotation: Vector3i) -> void:
	if not instance:
		return

	var merged_props := _build_merged_tile_properties(tile_pos, tile_def)

	instance.set_meta("xtreme_tile_id", tile_def.tile_id)
	instance.set_meta("xtreme_tile_type", int(tile_def.tile_type))
	instance.set_meta("xtreme_tile_properties", merged_props)
	instance.set_meta("xtreme_grid_position", tile_pos)
	instance.set_meta("xtreme_rotation", rotation)

	match tile_def.tile_type:
		XtremeTileDefinition.TileType.GOAL:
			var goal_id := StringName(str(merged_props.get("goal_id", "goal_%d_%d_%d" % [tile_pos.x, tile_pos.y, tile_pos.z])))
			instance.set_meta("xtreme_goal_id", goal_id)
		XtremeTileDefinition.TileType.SPAWN:
			var spawn_id := StringName(str(merged_props.get("spawn_id", "spawn_%d_%d_%d" % [tile_pos.x, tile_pos.y, tile_pos.z])))
			instance.set_meta("xtreme_spawn_id", spawn_id)
		XtremeTileDefinition.TileType.CHECKPOINT:
			var checkpoint_id := StringName(str(merged_props.get("checkpoint_id", "checkpoint_%d_%d_%d" % [tile_pos.x, tile_pos.y, tile_pos.z])))
			instance.set_meta("xtreme_checkpoint_id", checkpoint_id)
		_:
			pass

	if instance.has_method("apply_xtreme_tile_properties"):
		instance.call("apply_xtreme_tile_properties", merged_props)
		return

	for key_variant in merged_props.keys():
		var prop_name := str(key_variant)
		if _node_has_property(instance, prop_name):
			instance.set(prop_name, merged_props[key_variant])


func _node_has_property(node: Object, property_name: String) -> bool:
	for prop in node.get_property_list():
		if prop.get("name", "") == property_name:
			return true
	return false


func _create_fallback_interactive(tile_def: XtremeTileDefinition, rotation: Vector3i) -> Node:
	match tile_def.tile_type:
		XtremeTileDefinition.TileType.COLLECTIBLE:
			return _create_collectible_fallback(tile_def)
		XtremeTileDefinition.TileType.ENEMY:
			return _create_enemy_fallback(tile_def)
		XtremeTileDefinition.TileType.WATER:
			return _create_water_fallback(tile_def, rotation)
		_:
			return _create_generic_interactive_fallback(tile_def, rotation)


func _create_collectible_fallback(tile_def: XtremeTileDefinition) -> Area3D:
	var area := Area3D.new()
	var script := load("res://scripts/test_currency.gd") as Script
	if script:
		area.set_script(script)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = 0.3
	shape.radius = 0.4
	collision.shape = shape
	area.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.15
	torus.outer_radius = 0.4
	mesh_instance.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.1, 1.0)
	mat.metallic = 0.8
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.1, 1.0)
	mat.emission_energy_multiplier = 0.2
	mesh_instance.material_override = mat
	area.add_child(mesh_instance)

	if _node_has_property(area, "value"):
		var value := int(tile_def.custom_properties.get("value", 1))
		area.set("value", value)
	return area


func _create_enemy_fallback(tile_def: XtremeTileDefinition) -> Area3D:
	var area := Area3D.new()
	var script := load("res://scripts/test_enemy.gd") as Script
	if script:
		area.set_script(script)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	collision.shape = shape
	area.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	mesh_instance.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tile_def.editor_color
	mat.emission_enabled = true
	mat.emission = tile_def.editor_color.darkened(0.4)
	mat.emission_energy_multiplier = 0.3
	mesh_instance.material_override = mat
	area.add_child(mesh_instance)
	return area


func _create_water_fallback(tile_def: XtremeTileDefinition, rotation: Vector3i) -> Area3D:
	var area := Area3D.new()
	var script := load("res://scripts/test_water_volume.gd") as Script
	if script:
		area.set_script(script)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = _get_tile_visual_size(tile_def, rotation)
	collision.shape = shape
	area.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.17, 0.43, 0.8, 0.35)
	mat.roughness = 0.08
	mesh_instance.material_override = mat
	area.add_child(mesh_instance)
	return area


func _create_generic_interactive_fallback(tile_def: XtremeTileDefinition, rotation: Vector3i) -> Area3D:
	var area := Area3D.new()
	var script := load(interactive_script_path) as Script
	if script:
		area.set_script(script)

	var size := _get_tile_visual_size(tile_def, rotation)

	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	area.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(tile_def.editor_color.r, tile_def.editor_color.g, tile_def.editor_color.b, 0.55)
	material.roughness = 0.85
	mesh_instance.material_override = material
	area.add_child(mesh_instance)

	if _node_has_property(area, "tile_id"):
		area.set("tile_id", tile_def.tile_id)
	if _node_has_property(area, "tile_type"):
		area.set("tile_type", int(tile_def.tile_type))
	if _node_has_property(area, "damage_amount"):
		area.set("damage_amount", tile_def.damage_amount)
	if _node_has_property(area, "collectible_value"):
		area.set("collectible_value", int(tile_def.custom_properties.get("value", 1)))
	if _node_has_property(area, "custom_properties"):
		area.set("custom_properties", tile_def.custom_properties.duplicate(true))

	return area


func _apply_tile_transform(node: Node3D, tile_pos: Vector3i, tile_def: XtremeTileDefinition, rotation: Vector3i) -> void:
	node.position = _get_tile_world_center(tile_pos, tile_def, rotation)
	node.rotation_degrees = Vector3(rotation.x * 90.0, rotation.y * 90.0, rotation.z * 90.0)


func _is_interactive_tile(tile_def: XtremeTileDefinition) -> bool:
	var export_hint := str(tile_def.custom_properties.get("export_mode", "")).to_lower()
	if export_hint == "interactive":
		return true
	if export_hint == "static":
		return false

	match tile_def.tile_type:
		XtremeTileDefinition.TileType.HAZARD, \
		XtremeTileDefinition.TileType.ENEMY, \
		XtremeTileDefinition.TileType.COLLECTIBLE, \
		XtremeTileDefinition.TileType.CHECKPOINT, \
		XtremeTileDefinition.TileType.GOAL, \
		XtremeTileDefinition.TileType.TRIGGER, \
		XtremeTileDefinition.TileType.RAIL, \
		XtremeTileDefinition.TileType.SPRING, \
		XtremeTileDefinition.TileType.BOOST, \
		XtremeTileDefinition.TileType.WATER, \
		XtremeTileDefinition.TileType.TRANSPORT, \
		XtremeTileDefinition.TileType.SPAWN:
			return true
		_:
			return false


func _get_tile_world_center(tile_pos: Vector3i, tile_def: XtremeTileDefinition, rotation: Vector3i) -> Vector3:
	var cell_size := grid_settings.get_cell_size()
	var rotated_cell_count := tile_def.get_rotated_size(rotation)
	var offset := Vector3(
		(rotated_cell_count.x - 1) * cell_size.x * 0.5,
		(rotated_cell_count.y - 1) * cell_size.y * 0.5,
		(rotated_cell_count.z - 1) * cell_size.z * 0.5
	)
	return Vector3(
		tile_pos.x * cell_size.x + cell_size.x * 0.5,
		tile_pos.y * cell_size.y + cell_size.y * 0.5,
		tile_pos.z * cell_size.z + cell_size.z * 0.5
	) + offset


func _get_tile_visual_size(tile_def: XtremeTileDefinition, rotation: Vector3i) -> Vector3:
	var cell_size := grid_settings.get_cell_size()
	var rotated_cell_count := tile_def.get_rotated_size(rotation)
	return Vector3(
		cell_size.x * rotated_cell_count.x,
		cell_size.y * rotated_cell_count.y,
		cell_size.z * rotated_cell_count.z
	)


func _cell_to_chunk(cell: Vector3i) -> Vector3i:
	var safe_chunk := Vector3i(
		maxi(static_chunk_size.x, 1),
		maxi(static_chunk_size.y, 1),
		maxi(static_chunk_size.z, 1)
	)
	return Vector3i(
		floori(float(cell.x) / float(safe_chunk.x)),
		floori(float(cell.y) / float(safe_chunk.y)),
		floori(float(cell.z) / float(safe_chunk.z))
	)


func _build_chunk_key(chunk_coord: Vector3i) -> String:
	return "%d,%d,%d" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]


func _build_batch_key(tile_id: StringName, rotation: Vector3i) -> String:
	return "%s|%d|%d|%d" % [tile_id, rotation.x, rotation.y, rotation.z]


func _get_or_create_material(tile_def: XtremeTileDefinition) -> Material:
	var cache_key := str(tile_def.tile_id)
	if cache_key in _material_cache:
		return _material_cache[cache_key]

	var material: Material
	if apply_curved_world:
		var shader := load("res://addons/xtreme_level_editor/shaders/curved_world.gdshader") as Shader
		if shader:
			var shader_mat := ShaderMaterial.new()
			shader_mat.shader = shader
			shader_mat.set_shader_parameter("albedo", tile_def.editor_color)
			shader_mat.set_shader_parameter("curve_horizontal", curve_horizontal)
			shader_mat.set_shader_parameter("curve_vertical", curve_vertical)
			shader_mat.set_shader_parameter("curve_falloff_exponent", curve_falloff_exponent)
			shader_mat.set_shader_parameter("curve_intensity", 0.0)  # Deprecated
			shader_mat.set_shader_parameter("curve_enabled", true)
			shader_mat.set_shader_parameter("distance_effects_enabled", distance_effects_enabled)
			shader_mat.set_shader_parameter("effect_max_distance", effect_max_distance)
			shader_mat.set_shader_parameter("wireframe_start", wireframe_start)
			shader_mat.set_shader_parameter("wireframe_full", wireframe_full)
			shader_mat.set_shader_parameter("dissolve_start", dissolve_start)
			shader_mat.set_shader_parameter("dissolve_full", dissolve_full)
			shader_mat.set_shader_parameter("wireframe_use_albedo_color", true)
			material = shader_mat
		else:
			material = _create_standard_material(tile_def)
	else:
		material = _create_standard_material(tile_def)

	_material_cache[cache_key] = material
	return material


func _create_standard_material(tile_def: XtremeTileDefinition) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tile_def.editor_color
	return mat


func _assign_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		var child_node := child as Node
		if not child_node:
			continue
		child_node.owner = owner
		_assign_owner_recursive(child_node, owner)


func _clear_caches() -> void:
	_material_cache.clear()
	_tile_positions.clear()
	_tile_rotations.clear()


func _get_tile_definition(tile_id: StringName) -> XtremeTileDefinition:
	if not tile_palette:
		return null
	for tile in tile_palette.tiles:
		if tile.tile_id == tile_id:
			return tile
	return null
