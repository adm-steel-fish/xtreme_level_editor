extends Node
class_name XtremeSpawnManager
## Manages player spawning at designated spawn points

## Reference to the player node
@export var player: Node3D

## Reference to the current chunk set data (contains spawn points)
@export var chunk_set_data: XtremeChunkSetData

## Grid settings for position conversion
@export var grid_settings: XtremeGridSettings

## Emitted when player spawns
signal player_spawned(spawn_point: XtremeSpawnPoint)

## Spawn player at the default spawn point
func spawn_at_default() -> void:
	if not chunk_set_data:
		push_warning("XtremeSpawnManager: No chunk set data assigned")
		return
	
	var spawn := chunk_set_data.get_default_spawn()
	if spawn:
		_spawn_player_at(spawn)
	else:
		push_warning("XtremeSpawnManager: No default spawn point found")

## Spawn player at a specific spawn point by ID
func spawn_at_id(spawn_id: StringName) -> void:
	if not chunk_set_data:
		push_warning("XtremeSpawnManager: No chunk set data assigned")
		return
	
	var spawn := chunk_set_data.get_spawn_point(spawn_id)
	if spawn:
		_spawn_player_at(spawn)
	else:
		push_warning("XtremeSpawnManager: Spawn point '%s' not found" % spawn_id)

## Spawn player at a random spawn point
func spawn_at_random() -> void:
	if not chunk_set_data:
		push_warning("XtremeSpawnManager: No chunk set data assigned")
		return
	
	if chunk_set_data.spawn_points.is_empty():
		push_warning("XtremeSpawnManager: No spawn points available")
		return
	
	var random_index := randi() % chunk_set_data.spawn_points.size()
	var spawn: XtremeSpawnPoint = chunk_set_data.spawn_points[random_index]
	_spawn_player_at(spawn)

## Spawn player at a specific world position (bypasses spawn points)
func spawn_at_position(world_pos: Vector3, rotation_y: float = 0.0) -> void:
	if not player:
		push_warning("XtremeSpawnManager: No player assigned")
		return
	
	player.global_position = world_pos
	player.rotation.y = deg_to_rad(rotation_y)
	player_spawned.emit(null)

## Internal: Actually spawn the player at a spawn point
func _spawn_player_at(spawn: XtremeSpawnPoint) -> void:
	if not player:
		push_warning("XtremeSpawnManager: No player assigned")
		return
	
	# Calculate world position from grid position if needed
	var world_pos := spawn.position
	if world_pos == Vector3.ZERO and spawn.grid_position != Vector3i.ZERO and grid_settings:
		var cell_size := grid_settings.get_cell_size()
		world_pos = Vector3(spawn.grid_position) * cell_size + cell_size / 2.0
		# Offset Y to place player on top of the cell, not inside it
		world_pos.y = spawn.grid_position.y * cell_size.y + cell_size.y
	
	player.global_position = world_pos
	player.rotation.y = deg_to_rad(spawn.rotation_y)
	
	print("XtremeSpawnManager: Player spawned at %s (spawn: %s)" % [world_pos, spawn.spawn_id])
	player_spawned.emit(spawn)

## Get the world position of a spawn point
func get_spawn_world_position(spawn: XtremeSpawnPoint) -> Vector3:
	if spawn.position != Vector3.ZERO:
		return spawn.position
	
	if spawn.grid_position != Vector3i.ZERO and grid_settings:
		var cell_size := grid_settings.get_cell_size()
		var world_pos := Vector3(spawn.grid_position) * cell_size + cell_size / 2.0
		world_pos.y = spawn.grid_position.y * cell_size.y + cell_size.y
		return world_pos
	
	return Vector3.ZERO

## Get all spawn points in the current chunk set
func get_all_spawn_points() -> Array[XtremeSpawnPoint]:
	if chunk_set_data:
		return chunk_set_data.spawn_points
	return []

## Check if a spawn point exists
func has_spawn_point(spawn_id: StringName) -> bool:
	if chunk_set_data:
		return chunk_set_data.get_spawn_point(spawn_id) != null
	return false
