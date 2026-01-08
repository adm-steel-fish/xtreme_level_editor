@tool
class_name XtremeLevelExporter
extends RefCounted

## Optimized Level Exporter
## Features:
## - Mesh batching (tiles of same type combined)
## - Hidden face removal (no faces between adjacent solid blocks)
## - Expanded AABB (prevents frustum culling issues with curved shader)
## - Support for new shader parameters (wireframe, dissolve)

var grid_settings: XtremeGridSettings
var tile_palette: XtremeTilePalette
var level_data: XtremeLevelData

# Curved world settings
var apply_curved_world: bool = true
var curve_intensity: float = 0.01

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
	
	# Build tile position and rotation lookup for hidden face detection
	_tile_positions.clear()
	_tile_rotations.clear()
	var all_positions := level_data.get_all_tile_positions()
	for tile_pos in all_positions:
		var tile_id := level_data.get_tile(tile_pos)
		# Skip multi-cell part markers
		if tile_id == &"_multicell_part":
			continue
		_tile_positions[tile_pos] = tile_id
		_tile_rotations[tile_pos] = level_data.get_tile_rotation(tile_pos)
	
	# Group tiles by type AND rotation for batching
	# Key format: "tile_id|rot_x|rot_y|rot_z"
	var tiles_by_type_rotation: Dictionary = {}
	
	for tile_pos in _tile_positions.keys():
		var tile_id: StringName = _tile_positions[tile_pos]
		var rotation: Vector3i = _tile_rotations.get(tile_pos, Vector3i.ZERO)
		var batch_key := "%s|%d|%d|%d" % [tile_id, rotation.x, rotation.y, rotation.z]
		
		if batch_key not in tiles_by_type_rotation:
			tiles_by_type_rotation[batch_key] = {
				"tile_id": tile_id,
				"rotation": rotation,
				"positions": []
			}
		tiles_by_type_rotation[batch_key]["positions"].append(tile_pos)
	
	# Create one batched mesh per tile type + rotation combination
	for batch_key in tiles_by_type_rotation.keys():
		var batch_data: Dictionary = tiles_by_type_rotation[batch_key]
		var tile_id: StringName = batch_data["tile_id"]
		var rotation: Vector3i = batch_data["rotation"]
		var positions: Array = batch_data["positions"]
		
		if positions.size() == 0:
			continue
		
		var tile_def := _get_tile_definition(tile_id)
		if not tile_def:
			continue
		
		var batched_mesh := _create_batched_mesh_with_rotation(positions, tile_def, rotation)
		if batched_mesh:
			root.add_child(batched_mesh)
			batched_mesh.owner = root
	
	# Add collision
	var collision_body := _create_collision_body()
	if collision_body:
		root.add_child(collision_body)
		collision_body.owner = root
		for child in collision_body.get_children():
			child.owner = root
	
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("XtremeLevelExporter: Failed to pack scene")
		root.queue_free()
		return err
	
	err = ResourceSaver.save(packed, path)
	root.queue_free()
	
	# Clear caches
	_material_cache.clear()
	_tile_positions.clear()
	_tile_rotations.clear()
	
	return err

func _create_batched_mesh(positions: Array, tile_def: XtremeTileDefinition) -> MeshInstance3D:
	return _create_batched_mesh_with_rotation(positions, tile_def, Vector3i.ZERO)

func _create_batched_mesh_with_rotation(positions: Array, tile_def: XtremeTileDefinition, rotation: Vector3i) -> MeshInstance3D:
	if positions.size() == 0:
		return null
	
	var cell_size := grid_settings.get_cell_size()
	
	# Get tile's cell count and apply rotation
	var tile_cell_count := tile_def.cell_size
	var rotated_cell_count := tile_def.get_rotated_size(rotation)
	
	# Calculate actual visual size based on cell count
	var visual_size := Vector3(
		cell_size.x * rotated_cell_count.x,
		cell_size.y * rotated_cell_count.y,
		cell_size.z * rotated_cell_count.z
	)
	
	# Use ArrayMesh to combine all cubes into one mesh
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Track bounds for custom AABB
	var min_bounds := Vector3(INF, INF, INF)
	var max_bounds := Vector3(-INF, -INF, -INF)
	
	# Create rotation basis for rotating vertices
	var rot_basis := Basis.IDENTITY
	if rotation != Vector3i.ZERO:
		rot_basis = Basis.from_euler(Vector3(
			rotation.x * PI / 2.0,
			rotation.y * PI / 2.0,
			rotation.z * PI / 2.0
		))
	
	for pos in positions:
		# Center position for the object (account for multi-cell offset)
		var offset := Vector3(
			(rotated_cell_count.x - 1) * cell_size.x * 0.5,
			(rotated_cell_count.y - 1) * cell_size.y * 0.5,
			(rotated_cell_count.z - 1) * cell_size.z * 0.5
		)
		
		var world_pos := Vector3(
			pos.x * cell_size.x + cell_size.x * 0.5,
			pos.y * cell_size.y + cell_size.y * 0.5,
			pos.z * cell_size.z + cell_size.z * 0.5
		) + offset
		
		# Update bounds
		min_bounds = min_bounds.min(world_pos - visual_size * 0.5)
		max_bounds = max_bounds.max(world_pos + visual_size * 0.5)
		
		# Add cube with hidden face removal and rotation (using visual size)
		_add_cube_with_occlusion_rotated(surface_tool, pos, world_pos, visual_size, tile_def, rot_basis)
	
	surface_tool.generate_normals()
	var array_mesh := surface_tool.commit()
	
	if array_mesh.get_surface_count() == 0:
		return null
	
	var mesh_instance := MeshInstance3D.new()
	var rot_suffix := ""
	if rotation != Vector3i.ZERO:
		rot_suffix = "_r%d%d%d" % [rotation.x, rotation.y, rotation.z]
	mesh_instance.name = str(tile_def.tile_id) + rot_suffix + "_batch"
	mesh_instance.mesh = array_mesh
	
	# Set expanded custom AABB to prevent frustum culling issues
	# The curved shader can push vertices significantly, so we expand the bounds
	var aabb_expansion := curve_intensity * effect_max_distance * effect_max_distance * 2.0
	var expanded_min := min_bounds - Vector3(aabb_expansion, aabb_expansion, aabb_expansion)
	var expanded_max := max_bounds + Vector3(aabb_expansion, aabb_expansion, aabb_expansion)
	var custom_aabb := AABB(expanded_min, expanded_max - expanded_min)
	mesh_instance.custom_aabb = custom_aabb
	
	# Get or create shared material for this tile type
	var material := _get_or_create_material(tile_def)
	mesh_instance.material_override = material
	
	return mesh_instance

func _add_cube_with_occlusion_rotated(st: SurfaceTool, grid_pos: Vector3i, center: Vector3, size: Vector3, tile_def: XtremeTileDefinition, rot_basis: Basis) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	
	# Define 8 vertices of the cube (local space, will be rotated)
	var local_verts := [
		Vector3(-hx, -hy, -hz),  # 0: back-bottom-left
		Vector3( hx, -hy, -hz),  # 1: back-bottom-right
		Vector3( hx,  hy, -hz),  # 2: back-top-right
		Vector3(-hx,  hy, -hz),  # 3: back-top-left
		Vector3(-hx, -hy,  hz),  # 4: front-bottom-left
		Vector3( hx, -hy,  hz),  # 5: front-bottom-right
		Vector3( hx,  hy,  hz),  # 6: front-top-right
		Vector3(-hx,  hy,  hz),  # 7: front-top-left
	]
	
	# Rotate vertices around center and translate to world position
	var v: Array[Vector3] = []
	for local_v in local_verts:
		v.append(center + rot_basis * local_v)
	
	# Check each face for adjacent solid tiles
	# Only add face if no solid tile is adjacent on that side
	# Winding order is counter-clockwise when viewed from outside (front face)
	
	# Front face (z+) - visible from +Z direction
	if not _has_solid_neighbor(grid_pos, Vector3i(0, 0, 1)):
		_add_quad(st, v[4], v[7], v[6], v[5])  # CCW from front
	
	# Back face (z-) - visible from -Z direction
	if not _has_solid_neighbor(grid_pos, Vector3i(0, 0, -1)):
		_add_quad(st, v[1], v[2], v[3], v[0])  # CCW from back
	
	# Top face (y+) - visible from +Y direction
	if not _has_solid_neighbor(grid_pos, Vector3i(0, 1, 0)):
		_add_quad(st, v[3], v[2], v[6], v[7])  # CCW from top
	
	# Bottom face (y-) - visible from -Y direction
	if not _has_solid_neighbor(grid_pos, Vector3i(0, -1, 0)):
		_add_quad(st, v[0], v[4], v[5], v[1])  # CCW from bottom
	
	# Right face (x+) - visible from +X direction
	if not _has_solid_neighbor(grid_pos, Vector3i(1, 0, 0)):
		_add_quad(st, v[1], v[5], v[6], v[2])  # CCW from right
	
	# Left face (x-) - visible from -X direction
	if not _has_solid_neighbor(grid_pos, Vector3i(-1, 0, 0)):
		_add_quad(st, v[0], v[3], v[7], v[4])  # CCW from left

func _has_solid_neighbor(pos: Vector3i, offset: Vector3i) -> bool:
	var neighbor_pos := pos + offset
	
	# Check if there's a tile at the neighbor position
	if neighbor_pos not in _tile_positions:
		return false
	
	# Get the tile definition to check if it's solid
	var neighbor_tile_id: StringName = _tile_positions[neighbor_pos]
	var neighbor_def := _get_tile_definition(neighbor_tile_id)
	
	# If tile exists and is solid, the face is hidden
	if neighbor_def and neighbor_def.is_solid:
		return true
	
	return false

func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	# Add UV coordinates for texture mapping
	var uv0 := Vector2(0.0, 0.0)
	var uv1 := Vector2(1.0, 0.0)
	var uv2 := Vector2(1.0, 1.0)
	var uv3 := Vector2(0.0, 1.0)
	
	# Triangle 1
	st.set_uv(uv0)
	st.add_vertex(v0)
	st.set_uv(uv1)
	st.add_vertex(v1)
	st.set_uv(uv2)
	st.add_vertex(v2)
	
	# Triangle 2
	st.set_uv(uv0)
	st.add_vertex(v0)
	st.set_uv(uv2)
	st.add_vertex(v2)
	st.set_uv(uv3)
	st.add_vertex(v3)

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
			
			# Appearance
			shader_mat.set_shader_parameter("albedo", tile_def.editor_color)
			
			# Curvature settings
			shader_mat.set_shader_parameter("curve_intensity", curve_intensity)
			shader_mat.set_shader_parameter("curve_enabled", true)
			
			# Distance effect settings
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

func _create_collision_body() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "LevelCollision"
	
	var cell_size := grid_settings.get_cell_size()
	
	var all_positions := level_data.get_all_tile_positions()
	for tile_pos in all_positions:
		var tile_id: StringName = level_data.get_tile(tile_pos)
		var tile_def := _get_tile_definition(tile_id)
		
		# Skip non-solid tiles
		if tile_def and not tile_def.is_solid:
			continue
		
		var collision := CollisionShape3D.new()
		collision.name = "Col_%d_%d_%d" % [tile_pos.x, tile_pos.y, tile_pos.z]
		
		var box := BoxShape3D.new()
		box.size = cell_size
		collision.shape = box
		
		collision.position = Vector3(
			tile_pos.x * cell_size.x + cell_size.x * 0.5,
			tile_pos.y * cell_size.y + cell_size.y * 0.5,
			tile_pos.z * cell_size.z + cell_size.z * 0.5
		)
		
		body.add_child(collision)
	
	return body

func _get_tile_definition(tile_id: StringName) -> XtremeTileDefinition:
	if not tile_palette:
		return null
	for tile in tile_palette.tiles:
		if tile.tile_id == tile_id:
			return tile
	return null
