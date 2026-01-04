@tool
class_name XtremeLevelChunk
extends Resource

## A reusable chunk of level content that can be stamped into levels.
## Chunks are self-contained sections with their own connection points.

## Chunk metadata
@export var chunk_name: String = "Untitled Chunk"
@export var chunk_description: String = ""
@export var chunk_author: String = ""

## Size of this chunk in cells
@export var size: Vector3i = Vector3i(8, 8, 8)

## Theme tags this chunk belongs to
@export var theme_tags: PackedStringArray = []

## Difficulty rating (for generation balancing)
@export_range(0.0, 10.0) var difficulty: float = 1.0

## Tags for categorization (e.g., "start", "junction", "vertical", "hazard_run")
@export var structure_tags: PackedStringArray = []

## The tile data (relative coordinates)
## Key: "x,y,z", Value: tile_id
var _tile_data: Dictionary = {}

## Connection points (where this chunk can connect to others)
## Each has: position (Vector3i), direction (Vector3i), tags (PackedStringArray)
@export var connection_points: Array[Dictionary] = []

## Set a tile in the chunk (relative coordinates)
func set_tile(pos: Vector3i, tile_id: StringName) -> void:
	if not _is_valid_position(pos):
		push_warning("Position %s is outside chunk bounds" % pos)
		return
	
	var key := _pos_to_key(pos)
	if tile_id == &"" or tile_id == &"empty":
		_tile_data.erase(key)
	else:
		_tile_data[key] = tile_id
	emit_changed()

## Get a tile from the chunk
func get_tile(pos: Vector3i) -> StringName:
	if not _is_valid_position(pos):
		return &""
	return _tile_data.get(_pos_to_key(pos), &"")

## Check if position has a tile
func has_tile(pos: Vector3i) -> bool:
	return get_tile(pos) != &""

## Get all tile positions
func get_all_tile_positions() -> Array[Vector3i]:
	var positions: Array[Vector3i] = []
	for key in _tile_data.keys():
		positions.append(_key_to_pos(key))
	return positions

## Get total tile count
func get_tile_count() -> int:
	return _tile_data.size()

## Add a connection point
func add_connection_point(position: Vector3i, direction: Vector3i, tags: PackedStringArray = []) -> void:
	# Validate position is on chunk boundary
	var on_boundary := false
	if direction == Vector3i.RIGHT and position.x == size.x - 1:
		on_boundary = true
	elif direction == Vector3i.LEFT and position.x == 0:
		on_boundary = true
	elif direction == Vector3i.UP and position.y == size.y - 1:
		on_boundary = true
	elif direction == Vector3i.DOWN and position.y == 0:
		on_boundary = true
	elif direction == Vector3i.BACK and position.z == size.z - 1:
		on_boundary = true
	elif direction == Vector3i.FORWARD and position.z == 0:
		on_boundary = true
	
	if not on_boundary:
		push_warning("Connection point should be on chunk boundary facing outward")
	
	connection_points.append({
		"position": position,
		"direction": direction,
		"tags": tags,
		"id": _generate_id()
	})
	emit_changed()

## Remove a connection point by ID
func remove_connection_point(id: String) -> void:
	for i in range(connection_points.size()):
		if connection_points[i].get("id", "") == id:
			connection_points.remove_at(i)
			emit_changed()
			return

## Get connection points that can match with another chunk's connection
func get_compatible_connections(other_chunk: XtremeLevelChunk) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	
	for my_cp in connection_points:
		var my_dir: Vector3i = my_cp.get("direction", Vector3i.ZERO)
		var my_tags: PackedStringArray = my_cp.get("tags", PackedStringArray())
		
		for other_cp in other_chunk.connection_points:
			var other_dir: Vector3i = other_cp.get("direction", Vector3i.ZERO)
			var other_tags: PackedStringArray = other_cp.get("tags", PackedStringArray())
			
			# Directions must be opposite
			if my_dir + other_dir != Vector3i.ZERO:
				continue
			
			# Check tag compatibility
			if _tags_compatible(my_tags, other_tags):
				matches.append({
					"my_connection": my_cp,
					"other_connection": other_cp
				})
	
	return matches

## Rotate chunk 90 degrees around Y axis
func rotate_y_90() -> void:
	var new_data: Dictionary = {}
	var new_size := Vector3i(size.z, size.y, size.x)
	
	for key in _tile_data.keys():
		var pos := _key_to_pos(key)
		# Rotate: (x, y, z) -> (z, y, size.x - 1 - x)
		var new_pos := Vector3i(pos.z, pos.y, size.x - 1 - pos.x)
		new_data[_pos_to_key(new_pos)] = _tile_data[key]
	
	_tile_data = new_data
	size = new_size
	
	# Rotate connection points
	for cp in connection_points:
		var pos: Vector3i = cp.get("position", Vector3i.ZERO)
		var dir: Vector3i = cp.get("direction", Vector3i.ZERO)
		cp["position"] = Vector3i(pos.z, pos.y, size.z - 1 - pos.x)
		cp["direction"] = Vector3i(dir.z, dir.y, -dir.x)
	
	emit_changed()

## Mirror chunk on X axis
func mirror_x() -> void:
	var new_data: Dictionary = {}
	
	for key in _tile_data.keys():
		var pos := _key_to_pos(key)
		var new_pos := Vector3i(size.x - 1 - pos.x, pos.y, pos.z)
		new_data[_pos_to_key(new_pos)] = _tile_data[key]
	
	_tile_data = new_data
	
	# Mirror connection points
	for cp in connection_points:
		var pos: Vector3i = cp.get("position", Vector3i.ZERO)
		var dir: Vector3i = cp.get("direction", Vector3i.ZERO)
		cp["position"] = Vector3i(size.x - 1 - pos.x, pos.y, pos.z)
		cp["direction"] = Vector3i(-dir.x, dir.y, dir.z)
	
	emit_changed()

## Create from level data region
static func create_from_region(level_data: XtremeLevelData, start: Vector3i, end: Vector3i) -> XtremeLevelChunk:
	var chunk := XtremeLevelChunk.new()
	
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
	
	chunk.size = max_pos - min_pos + Vector3i.ONE
	
	for x in range(min_pos.x, max_pos.x + 1):
		for y in range(min_pos.y, max_pos.y + 1):
			for z in range(min_pos.z, max_pos.z + 1):
				var world_pos := Vector3i(x, y, z)
				var local_pos := world_pos - min_pos
				var tile_id := level_data.get_tile(world_pos)
				if tile_id != &"":
					chunk.set_tile(local_pos, tile_id)
	
	return chunk

## Stamp this chunk into level data at position
func stamp_into(level_data: XtremeLevelData, position: Vector3i, overwrite: bool = true) -> void:
	for key in _tile_data.keys():
		var local_pos := _key_to_pos(key)
		var world_pos := local_pos + position
		
		if overwrite or not level_data.has_tile(world_pos):
			level_data.set_tile(world_pos, _tile_data[key])

# ============ Private Methods ============

func _is_valid_position(pos: Vector3i) -> bool:
	return pos.x >= 0 and pos.x < size.x \
		and pos.y >= 0 and pos.y < size.y \
		and pos.z >= 0 and pos.z < size.z

func _pos_to_key(pos: Vector3i) -> String:
	return "%d,%d,%d" % [pos.x, pos.y, pos.z]

func _key_to_pos(key: String) -> Vector3i:
	var parts := key.split(",")
	if parts.size() != 3:
		return Vector3i.ZERO
	return Vector3i(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())

func _generate_id() -> String:
	return "%d_%d" % [Time.get_ticks_msec(), randi()]

func _tags_compatible(tags_a: PackedStringArray, tags_b: PackedStringArray) -> bool:
	# Empty tags match anything
	if tags_a.is_empty() or tags_b.is_empty():
		return true
	
	# Check for any common tag
	for tag in tags_a:
		if tag in tags_b:
			return true
	
	# Check for wildcard
	if "any" in tags_a or "any" in tags_b:
		return true
	
	return false

# ============ Serialization ============

func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "_tile_data",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_STORAGE
	}]
