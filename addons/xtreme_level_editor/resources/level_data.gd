@tool
class_name XtremeLevelData
extends Resource

## Core level data structure storing the 3D grid of tiles.
## This is the save format for levels.

## Level metadata
@export var level_name: String = "Untitled Level"
@export var level_author: String = ""
@export var level_description: String = ""
@export var creation_date: String = ""
@export var last_modified: String = ""

## Level dimensions (in cells)
@export var size_x: int = 64
@export var size_y: int = 32
@export var size_z: int = 64

## Theme tag for this level (affects procedural generation)
@export var theme: String = "default"

## The grid data - stored as a flat dictionary for sparse storage
## Key: "x,y,z" string, Value: tile_id (StringName)
## Only non-empty cells are stored
var _grid_data: Dictionary = {}

## Rotation data - stored separately for tiles that have non-zero rotation
## Key: "x,y,z" string, Value: Vector3i (rotation in 90-degree increments: 0,1,2,3 for each axis)
var _rotation_data: Dictionary = {}

## Multi-cell object anchors - tracks which cells belong to multi-cell objects
## Key: "x,y,z" string (anchor position), Value: Dictionary with size and occupied cells
var _multicell_data: Dictionary = {}

## Connection point markers for chunk system
## Array of ConnectionPoint data
@export var connection_points: Array[Dictionary] = []

## Reference to the grid settings (loaded at runtime)
var _grid_settings: XtremeGridSettings

## Initialize with grid settings
func initialize(settings: XtremeGridSettings) -> void:
	_grid_settings = settings
	if creation_date.is_empty():
		creation_date = Time.get_datetime_string_from_system()
	_update_modified_time()

## Set a tile at grid coordinates with optional rotation
func set_tile(pos: Vector3i, tile_id: StringName, rotation: Vector3i = Vector3i.ZERO) -> void:
	if not _is_valid_position(pos):
		push_warning("Position %s is outside level bounds" % pos)
		return
	
	var key := _pos_to_key(pos)
	
	if tile_id == &"" or tile_id == &"empty":
		# Remove tile (empty space)
		_grid_data.erase(key)
		_rotation_data.erase(key)
	else:
		_grid_data[key] = tile_id
		# Only store rotation if non-zero
		if rotation != Vector3i.ZERO:
			_rotation_data[key] = rotation
		else:
			_rotation_data.erase(key)
	
	_update_modified_time()
	emit_changed()

## Get the tile ID at grid coordinates
func get_tile(pos: Vector3i) -> StringName:
	if not _is_valid_position(pos):
		return &""
	
	var key := _pos_to_key(pos)
	return _grid_data.get(key, &"")

## Get the rotation at grid coordinates (in 90-degree increments)
func get_tile_rotation(pos: Vector3i) -> Vector3i:
	if not _is_valid_position(pos):
		return Vector3i.ZERO
	
	var key := _pos_to_key(pos)
	return _rotation_data.get(key, Vector3i.ZERO)

## Check if a position has a tile
func has_tile(pos: Vector3i) -> bool:
	return get_tile(pos) != &""

## Clear a tile at position
func clear_tile(pos: Vector3i) -> void:
	set_tile(pos, &"")

## Clear all tiles
func clear_all() -> void:
	_grid_data.clear()
	_rotation_data.clear()
	_multicell_data.clear()
	_update_modified_time()
	emit_changed()

## Get all non-empty cell positions
func get_all_tile_positions() -> Array[Vector3i]:
	var positions: Array[Vector3i] = []
	for key in _grid_data.keys():
		positions.append(_key_to_pos(key))
	return positions

## Get all tiles of a specific type
func get_tiles_of_type(tile_id: StringName) -> Array[Vector3i]:
	var positions: Array[Vector3i] = []
	for key in _grid_data.keys():
		if _grid_data[key] == tile_id:
			positions.append(_key_to_pos(key))
	return positions

## Set a multi-cell object at anchor position
func set_multicell_object(anchor_pos: Vector3i, tile_id: StringName, size: Vector3i, rotation: Vector3i = Vector3i.ZERO) -> bool:
	# Calculate rotated size
	var rotated_size := _get_rotated_size(size, rotation)
	
	# Check if all cells are available
	for x in range(rotated_size.x):
		for y in range(rotated_size.y):
			for z in range(rotated_size.z):
				var check_pos := anchor_pos + Vector3i(x, y, z)
				if not _is_valid_position(check_pos):
					return false
				if has_tile(check_pos):
					return false
	
	# Place the anchor
	var anchor_key := _pos_to_key(anchor_pos)
	_grid_data[anchor_key] = tile_id
	if rotation != Vector3i.ZERO:
		_rotation_data[anchor_key] = rotation
	
	# Store multi-cell data
	var occupied_cells: Array[Vector3i] = []
	for x in range(rotated_size.x):
		for y in range(rotated_size.y):
			for z in range(rotated_size.z):
				var cell_pos := anchor_pos + Vector3i(x, y, z)
				occupied_cells.append(cell_pos)
				if cell_pos != anchor_pos:
					# Mark non-anchor cells as occupied by this object
					var cell_key := _pos_to_key(cell_pos)
					_grid_data[cell_key] = &"_multicell_part"  # Special marker
	
	_multicell_data[anchor_key] = {
		"size": size,
		"rotated_size": rotated_size,
		"rotation": rotation,
		"cells": occupied_cells
	}
	
	_update_modified_time()
	emit_changed()
	return true

## Get multi-cell object data at a position (returns anchor data if pos is part of multi-cell)
func get_multicell_at(pos: Vector3i) -> Dictionary:
	var key := _pos_to_key(pos)
	
	# Check if this is an anchor
	if key in _multicell_data:
		return _multicell_data[key]
	
	# Check if this is part of a multi-cell object
	for anchor_key in _multicell_data.keys():
		var data: Dictionary = _multicell_data[anchor_key]
		var cells: Array = data.get("cells", [])
		for cell in cells:
			if cell == pos:
				var result := data.duplicate()
				result["anchor"] = _key_to_pos(anchor_key)
				return result
	
	return {}

## Remove a multi-cell object (given any cell position that's part of it)
func remove_multicell_at(pos: Vector3i) -> void:
	var data := get_multicell_at(pos)
	if data.is_empty():
		return
	
	var anchor: Vector3i
	if data.has("anchor"):
		anchor = data["anchor"]
	else:
		anchor = pos
	
	var anchor_key := _pos_to_key(anchor)
	if anchor_key in _multicell_data:
		var cells: Array = _multicell_data[anchor_key].get("cells", [])
		for cell in cells:
			var cell_key := _pos_to_key(cell)
			_grid_data.erase(cell_key)
			_rotation_data.erase(cell_key)
		_multicell_data.erase(anchor_key)
	
	_update_modified_time()
	emit_changed()

## Check if a position is part of a multi-cell object
func is_multicell_part(pos: Vector3i) -> bool:
	return not get_multicell_at(pos).is_empty()

func _get_rotated_size(size: Vector3i, rotation: Vector3i) -> Vector3i:
	var result := size
	# Apply Y rotation (most common)
	if rotation.y % 2 == 1:  # 90 or 270 degrees
		result = Vector3i(result.z, result.y, result.x)
	# Apply X rotation
	if rotation.x % 2 == 1:
		result = Vector3i(result.x, result.z, result.y)
	# Apply Z rotation
	if rotation.z % 2 == 1:
		result = Vector3i(result.y, result.x, result.z)
	return result

## Get the bounds of actual content (not level size)
func get_content_bounds() -> AABB:
	if _grid_data.is_empty():
		return AABB()
	
	var min_pos := Vector3i(999999, 999999, 999999)
	var max_pos := Vector3i(-999999, -999999, -999999)
	
	for key in _grid_data.keys():
		var pos := _key_to_pos(key)
		min_pos.x = mini(min_pos.x, pos.x)
		min_pos.y = mini(min_pos.y, pos.y)
		min_pos.z = mini(min_pos.z, pos.z)
		max_pos.x = maxi(max_pos.x, pos.x)
		max_pos.y = maxi(max_pos.y, pos.y)
		max_pos.z = maxi(max_pos.z, pos.z)
	
	if _grid_settings:
		var cell_size := _grid_settings.get_cell_size()
		return AABB(
			Vector3(min_pos) * cell_size,
			Vector3(max_pos - min_pos + Vector3i.ONE) * cell_size
		)
	else:
		return AABB(Vector3(min_pos), Vector3(max_pos - min_pos + Vector3i.ONE))

## Copy a region of the grid (for chunk operations)
func copy_region(start: Vector3i, end: Vector3i) -> Dictionary:
	var region_data := {}
	var region_rotations := {}
	
	var min_pos := Vector3i(
		mini(start.x, end.x),
		mini(start.y, end.y),
		mini(start.z, end.z)
	)
	var max_pos := Vector3i(
		maxi(start.x, end.x),
		maxi(start.y, end.y),
		maxi(start.z, end.z)
	)
	
	for x in range(min_pos.x, max_pos.x + 1):
		for y in range(min_pos.y, max_pos.y + 1):
			for z in range(min_pos.z, max_pos.z + 1):
				var pos := Vector3i(x, y, z)
				var tile_id := get_tile(pos)
				if tile_id != &"":
					var rel_pos := pos - min_pos
					var rel_key := _pos_to_key(rel_pos)
					region_data[rel_key] = tile_id
					var rot := get_tile_rotation(pos)
					if rot != Vector3i.ZERO:
						region_rotations[rel_key] = rot
	
	return {
		"size": max_pos - min_pos + Vector3i.ONE,
		"tiles": region_data,
		"rotations": region_rotations
	}

## Paste a region into the grid
func paste_region(region: Dictionary, position: Vector3i, overwrite: bool = true) -> void:
	var tiles: Dictionary = region.get("tiles", {})
	var rotations: Dictionary = region.get("rotations", {})
	
	for key in tiles.keys():
		var rel_pos := _key_to_pos(key)
		var abs_pos := rel_pos + position
		
		if overwrite or not has_tile(abs_pos):
			var rot: Vector3i = rotations.get(key, Vector3i.ZERO)
			set_tile(abs_pos, tiles[key], rot)

## Resize the level bounds
func resize(new_x: int, new_y: int, new_z: int) -> void:
	size_x = maxi(1, new_x)
	size_y = maxi(1, new_y)
	size_z = maxi(1, new_z)
	
	# Remove tiles outside new bounds
	var keys_to_remove: Array[String] = []
	for key in _grid_data.keys():
		var pos := _key_to_pos(key)
		if not _is_valid_position(pos):
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		_grid_data.erase(key)
		_rotation_data.erase(key)
	
	_update_modified_time()
	emit_changed()

## Add a connection point marker
func add_connection_point(position: Vector3i, direction: Vector3i, tags: PackedStringArray = []) -> void:
	connection_points.append({
		"position": position,
		"direction": direction,
		"tags": tags,
		"id": _generate_connection_id()
	})
	emit_changed()

## Remove a connection point
func remove_connection_point(id: String) -> void:
	for i in range(connection_points.size()):
		if connection_points[i].get("id", "") == id:
			connection_points.remove_at(i)
			emit_changed()
			return

## Get connection points on a specific face
func get_connection_points_on_face(direction: Vector3i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cp in connection_points:
		if cp.get("direction", Vector3i.ZERO) == direction:
			result.append(cp)
	return result

# ============ Private Methods ============

func _is_valid_position(pos: Vector3i) -> bool:
	return pos.x >= 0 and pos.x < size_x \
		and pos.y >= 0 and pos.y < size_y \
		and pos.z >= 0 and pos.z < size_z

func _pos_to_key(pos: Vector3i) -> String:
	return "%d,%d,%d" % [pos.x, pos.y, pos.z]

func _key_to_pos(key: String) -> Vector3i:
	var parts := key.split(",")
	if parts.size() != 3:
		return Vector3i.ZERO
	return Vector3i(
		parts[0].to_int(),
		parts[1].to_int(),
		parts[2].to_int()
	)

func _update_modified_time() -> void:
	last_modified = Time.get_datetime_string_from_system()

func _generate_connection_id() -> String:
	return "%d_%d" % [Time.get_ticks_msec(), randi()]

# ============ Serialization ============

func _get_property_list() -> Array[Dictionary]:
	# Expose internal data for saving
	return [
		{
			"name": "_grid_data",
			"type": TYPE_DICTIONARY,
			"usage": PROPERTY_USAGE_STORAGE
		},
		{
			"name": "_rotation_data",
			"type": TYPE_DICTIONARY,
			"usage": PROPERTY_USAGE_STORAGE
		},
		{
			"name": "_multicell_data",
			"type": TYPE_DICTIONARY,
			"usage": PROPERTY_USAGE_STORAGE
		}
	]
