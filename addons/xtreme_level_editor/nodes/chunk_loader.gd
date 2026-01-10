@tool
class_name XtremeChunkLoader
extends Node3D
## Runtime Chunk Loader - Manages loading/unloading of level chunks based on player position
## This node should be added to your level scene at runtime

## Emitted when a chunk starts loading
signal chunk_loading(chunk_coord: Vector3i)

## Emitted when a chunk finishes loading
signal chunk_loaded(chunk_coord: Vector3i)

## Emitted when a chunk is unloaded
signal chunk_unloaded(chunk_coord: Vector3i)

## Emitted when player enters a new chunk
signal player_chunk_changed(old_chunk: Vector3i, new_chunk: Vector3i)

## The level data to stream
@export var level_data: XtremeLevelData

## Grid settings for coordinate conversion
@export var grid_settings: XtremeGridSettings

## Chunk size in cells (e.g., 16x16x16)
@export var chunk_size: Vector3i = Vector3i(16, 16, 16)

## How many chunks to keep loaded around the player
@export var load_radius: int = 2

## How many chunks beyond load_radius before unloading
@export var unload_margin: int = 1

## Node that the chunk loader follows (usually player)
@export var follow_target: Node3D

## Show debug visualization
@export var debug_draw: bool = false

## Currently loaded chunks: key = chunk coord, value = chunk node
var _loaded_chunks: Dictionary = {}

## Chunks currently being loaded (async)
var _loading_chunks: Dictionary = {}

## Current chunk the follow_target is in
var _current_chunk: Vector3i = Vector3i(-999, -999, -999)

## Reference to the visualizer (if in editor)
var _grid_visualizer: Node3D

## Chunk mesh container
var _chunk_container: Node3D

func _ready() -> void:
	_chunk_container = Node3D.new()
	_chunk_container.name = "ChunkContainer"
	add_child(_chunk_container)

func _process(delta: float) -> void:
	if not follow_target or not level_data or not grid_settings:
		return
	
	var target_pos := follow_target.global_position
	var new_chunk := world_to_chunk(target_pos)
	
	if new_chunk != _current_chunk:
		var old_chunk := _current_chunk
		_current_chunk = new_chunk
		player_chunk_changed.emit(old_chunk, new_chunk)
		_update_loaded_chunks()

## Convert world position to chunk coordinate
func world_to_chunk(world_pos: Vector3) -> Vector3i:
	var cell_size := grid_settings.get_cell_size()
	var grid_pos := Vector3i(
		floori(world_pos.x / cell_size.x),
		floori(world_pos.y / cell_size.y),
		floori(world_pos.z / cell_size.z)
	)
	return Vector3i(
		floori(float(grid_pos.x) / chunk_size.x),
		floori(float(grid_pos.y) / chunk_size.y),
		floori(float(grid_pos.z) / chunk_size.z)
	)

## Convert chunk coordinate to world position (chunk origin)
func chunk_to_world(chunk_coord: Vector3i) -> Vector3:
	var cell_size := grid_settings.get_cell_size()
	return Vector3(
		chunk_coord.x * chunk_size.x * cell_size.x,
		chunk_coord.y * chunk_size.y * cell_size.y,
		chunk_coord.z * chunk_size.z * cell_size.z
	)

## Get the grid cell range for a chunk
func get_chunk_cell_range(chunk_coord: Vector3i) -> Array[Vector3i]:
	var min_cell := chunk_coord * chunk_size
	var max_cell := min_cell + chunk_size
	return [min_cell, max_cell]

## Update which chunks should be loaded/unloaded
func _update_loaded_chunks() -> void:
	var chunks_to_load: Array[Vector3i] = []
	var chunks_to_unload: Array[Vector3i] = []
	
	# Determine which chunks should be loaded
	var desired_chunks: Dictionary = {}
	for x in range(-load_radius, load_radius + 1):
		for y in range(-load_radius, load_radius + 1):
			for z in range(-load_radius, load_radius + 1):
				var chunk_coord := _current_chunk + Vector3i(x, y, z)
				if _is_chunk_valid(chunk_coord):
					desired_chunks[chunk_coord] = true
					if chunk_coord not in _loaded_chunks and chunk_coord not in _loading_chunks:
						chunks_to_load.append(chunk_coord)
	
	# Determine which chunks should be unloaded
	var unload_distance := load_radius + unload_margin
	for key in _loaded_chunks.keys():
		var chunk_coord: Vector3i = key as Vector3i
		var diff: Vector3i = chunk_coord - _current_chunk
		if abs(diff.x) > unload_distance or abs(diff.y) > unload_distance or abs(diff.z) > unload_distance:
			chunks_to_unload.append(chunk_coord)
	
	# Unload chunks
	for chunk_coord in chunks_to_unload:
		_unload_chunk(chunk_coord)
	
	# Load chunks
	for chunk_coord in chunks_to_load:
		_load_chunk(chunk_coord)

## Check if a chunk coordinate is valid (within level bounds)
func _is_chunk_valid(chunk_coord: Vector3i) -> bool:
	if not level_data:
		return false
	
	var min_cell := chunk_coord * chunk_size
	var max_cell := min_cell + chunk_size
	
	# Check if any part of the chunk is within level bounds
	return (min_cell.x < level_data.size_x and max_cell.x > 0 and
			min_cell.y < level_data.size_y and max_cell.y > 0 and
			min_cell.z < level_data.size_z and max_cell.z > 0)

## Load a chunk (create mesh for cells in that chunk)
func _load_chunk(chunk_coord: Vector3i) -> void:
	if chunk_coord in _loaded_chunks or chunk_coord in _loading_chunks:
		return
	
	_loading_chunks[chunk_coord] = true
	chunk_loading.emit(chunk_coord)
	
	# Create chunk node
	var chunk_node := Node3D.new()
	chunk_node.name = "Chunk_%d_%d_%d" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
	chunk_node.position = chunk_to_world(chunk_coord)
	
	# Get cell range for this chunk
	var cell_range := get_chunk_cell_range(chunk_coord)
	var min_cell := cell_range[0]
	var max_cell := cell_range[1]
	
	# Clamp to level bounds
	min_cell.x = maxi(min_cell.x, 0)
	min_cell.y = maxi(min_cell.y, 0)
	min_cell.z = maxi(min_cell.z, 0)
	max_cell.x = mini(max_cell.x, level_data.size_x)
	max_cell.y = mini(max_cell.y, level_data.size_y)
	max_cell.z = mini(max_cell.z, level_data.size_z)
	
	# Build mesh for this chunk (simplified - in production, use batching)
	var cell_size := grid_settings.get_cell_size()
	var mesh_instance := _create_chunk_mesh(min_cell, max_cell, cell_size, chunk_coord)
	if mesh_instance:
		chunk_node.add_child(mesh_instance)
	
	_chunk_container.add_child(chunk_node)
	_loaded_chunks[chunk_coord] = chunk_node
	_loading_chunks.erase(chunk_coord)
	
	chunk_loaded.emit(chunk_coord)

## Unload a chunk
func _unload_chunk(chunk_coord: Vector3i) -> void:
	if chunk_coord not in _loaded_chunks:
		return
	
	var chunk_node: Node3D = _loaded_chunks[chunk_coord]
	chunk_node.queue_free()
	_loaded_chunks.erase(chunk_coord)
	
	chunk_unloaded.emit(chunk_coord)

## Create mesh for a chunk (basic implementation - can be optimized)
func _create_chunk_mesh(min_cell: Vector3i, max_cell: Vector3i, cell_size: Vector3, chunk_coord: Vector3i) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var has_geometry := false
	var chunk_origin := chunk_to_world(chunk_coord)
	
	for x in range(min_cell.x, max_cell.x):
		for y in range(min_cell.y, max_cell.y):
			for z in range(min_cell.z, max_cell.z):
				var pos := Vector3i(x, y, z)
				var tile_id := level_data.get_tile(pos)
				
				if tile_id != &"" and tile_id != &"_multicell_part":
					has_geometry = true
					# Calculate local position within chunk
					var local_pos := Vector3(
						x * cell_size.x - chunk_origin.x,
						y * cell_size.y - chunk_origin.y,
						z * cell_size.z - chunk_origin.z
					)
					_add_cube_to_surface(surface_tool, local_pos, cell_size, Color.WHITE)
	
	if not has_geometry:
		return null
	
	surface_tool.generate_normals()
	var mesh := surface_tool.commit()
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.name = "ChunkMesh"
	
	# Apply basic material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.6, 0.6)
	mesh_instance.material_override = mat
	
	return mesh_instance

## Add a cube to the surface tool
func _add_cube_to_surface(st: SurfaceTool, pos: Vector3, size: Vector3, color: Color) -> void:
	st.set_color(color)
	
	var corners := [
		pos,
		pos + Vector3(size.x, 0, 0),
		pos + Vector3(size.x, 0, size.z),
		pos + Vector3(0, 0, size.z),
		pos + Vector3(0, size.y, 0),
		pos + Vector3(size.x, size.y, 0),
		pos + Vector3(size.x, size.y, size.z),
		pos + Vector3(0, size.y, size.z),
	]
	
	# Bottom face
	_add_quad(st, corners[0], corners[3], corners[2], corners[1])
	# Top face
	_add_quad(st, corners[4], corners[5], corners[6], corners[7])
	# Front face
	_add_quad(st, corners[0], corners[1], corners[5], corners[4])
	# Back face
	_add_quad(st, corners[2], corners[3], corners[7], corners[6])
	# Left face
	_add_quad(st, corners[3], corners[0], corners[4], corners[7])
	# Right face
	_add_quad(st, corners[1], corners[2], corners[6], corners[5])

func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)

## Force reload all chunks
func reload_all_chunks() -> void:
	# Unload all
	for key in _loaded_chunks.keys():
		var chunk_coord: Vector3i = key as Vector3i
		_unload_chunk(chunk_coord)
	
	# Re-evaluate
	_current_chunk = Vector3i(-999, -999, -999)
	if follow_target:
		_current_chunk = world_to_chunk(follow_target.global_position)
		_update_loaded_chunks()

## Get chunk containing a world position
func get_chunk_at_world_position(world_pos: Vector3) -> Vector3i:
	return world_to_chunk(world_pos)

## Check if a chunk is loaded
func is_chunk_loaded(chunk_coord: Vector3i) -> bool:
	return chunk_coord in _loaded_chunks

## Get count of loaded chunks
func get_loaded_chunk_count() -> int:
	return _loaded_chunks.size()
