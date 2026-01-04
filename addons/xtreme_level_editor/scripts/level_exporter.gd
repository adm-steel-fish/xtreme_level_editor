@tool
class_name XtremeLevelExporter
extends RefCounted

## Optimized Level Exporter with Mesh Batching
## Combines tiles of the same type into single meshes for much better performance

var grid_settings: XtremeGridSettings
var tile_palette: XtremeTilePalette
var level_data: XtremeLevelData

var apply_curved_world: bool = true
var curve_intensity: float = 0.01

# Cached materials - shared across all tiles of same type
var _material_cache: Dictionary = {}

func export_level(path: String) -> Error:
	if not level_data or not grid_settings or not tile_palette:
		push_error("XtremeLevelExporter: Missing required data")
		return ERR_INVALID_DATA
	
	var root := Node3D.new()
	root.name = level_data.level_name.replace(" ", "_")
	
	# Group tiles by type for batching
	var tiles_by_type: Dictionary = {}
	
	for tile_pos in level_data.tiles.keys():
		var tile_id: StringName = level_data.tiles[tile_pos]
		if tile_id not in tiles_by_type:
			tiles_by_type[tile_id] = []
		tiles_by_type[tile_id].append(tile_pos)
	
	# Create one batched mesh per tile type
	for tile_id in tiles_by_type.keys():
		var positions: Array = tiles_by_type[tile_id]
		if positions.size() == 0:
			continue
		
		var tile_def := _get_tile_definition(tile_id)
		if not tile_def:
			continue
		
		var batched_mesh := _create_batched_mesh(positions, tile_def)
		if batched_mesh:
			root.add_child(batched_mesh)
			batched_mesh.owner = root
	
	# Add collision - single merged collision shape
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
	
	# Clear material cache after export
	_material_cache.clear()
	
	return err

func _create_batched_mesh(positions: Array, tile_def: XtremeTileDefinition) -> MeshInstance3D:
	if positions.size() == 0:
		return null
	
	var cell_size := grid_settings.get_cell_size()
	
	# Use ArrayMesh to combine all cubes into one mesh
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for pos in positions:
		var world_pos := Vector3(
			pos.x * cell_size.x + cell_size.x * 0.5,
			pos.y * cell_size.y + cell_size.y * 0.5,
			pos.z * cell_size.z + cell_size.z * 0.5
		)
		_add_cube_to_surface(surface_tool, world_pos, cell_size)
	
	surface_tool.generate_normals()
	var array_mesh := surface_tool.commit()
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = str(tile_def.tile_id) + "_batch"
	mesh_instance.mesh = array_mesh
	
	# Get or create shared material for this tile type
	var material := _get_or_create_material(tile_def)
	mesh_instance.material_override = material
	
	return mesh_instance

func _add_cube_to_surface(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	
	# Define 8 vertices of the cube
	var v := [
		center + Vector3(-hx, -hy, -hz),  # 0: back-bottom-left
		center + Vector3( hx, -hy, -hz),  # 1: back-bottom-right
		center + Vector3( hx,  hy, -hz),  # 2: back-top-right
		center + Vector3(-hx,  hy, -hz),  # 3: back-top-left
		center + Vector3(-hx, -hy,  hz),  # 4: front-bottom-left
		center + Vector3( hx, -hy,  hz),  # 5: front-bottom-right
		center + Vector3( hx,  hy,  hz),  # 6: front-top-right
		center + Vector3(-hx,  hy,  hz),  # 7: front-top-left
	]
	
	# Front face (z+)
	_add_quad(st, v[4], v[5], v[6], v[7])
	# Back face (z-)
	_add_quad(st, v[1], v[0], v[3], v[2])
	# Top face (y+)
	_add_quad(st, v[7], v[6], v[2], v[3])
	# Bottom face (y-)
	_add_quad(st, v[0], v[1], v[5], v[4])
	# Right face (x+)
	_add_quad(st, v[5], v[1], v[2], v[6])
	# Left face (x-)
	_add_quad(st, v[0], v[4], v[7], v[3])

func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	# Triangle 1
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)
	# Triangle 2
	st.add_vertex(v0)
	st.add_vertex(v2)
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
			shader_mat.set_shader_parameter("albedo", tile_def.editor_color)
			shader_mat.set_shader_parameter("curve_intensity", curve_intensity)
			shader_mat.set_shader_parameter("curve_enabled", true)
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
	
	# Create collision shapes for each tile
	# For better performance, we could merge adjacent tiles, but individual shapes work fine
	for tile_pos in level_data.tiles.keys():
		var tile_id: StringName = level_data.tiles[tile_pos]
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
