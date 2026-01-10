@tool
class_name XtremeWorldMapConnection
extends Resource
## World Map Connection - A path between two nodes on the world map

## Connection types
enum ConnectionType {
	PATH,           ## Normal walking path
	BRIDGE,         ## Bridge (may require unlock)
	PIPE,           ## Pipe/warp (instant travel)
	SECRET,         ## Hidden path (requires discovery)
	LOCKED          ## Locked path (requires key/payment)
}

## Starting node
@export var from_node: StringName = &""

## Ending node
@export var to_node: StringName = &""

## Connection type
@export var connection_type: ConnectionType = ConnectionType.PATH

## Is this a one-way connection?
@export var one_way: bool = false

## Path control points (for curved paths on map)
@export var path_points: Array[Vector2] = []

@export_group("Unlock Requirements")

## Is this connection visible when locked?
@export var visible_when_locked: bool = true

## Is this connection unlocked from start?
@export var unlocked_from_start: bool = true

## Levels required to unlock this path
@export var required_levels: Array[StringName] = []

## Secrets required to unlock this path
@export var required_secrets: Array[StringName] = []

## Custom unlock key (for game-specific logic)
@export var unlock_key: StringName = &""

@export_group("Visuals")

## Path color
@export var path_color: Color = Color.WHITE

## Path width
@export var path_width: float = 4.0

## Animated path?
@export var animated: bool = false

## Custom data
@export var custom_data: Dictionary = {}

## Check if connection is unlocked
func is_unlocked(world_progress: XtremeWorldProgress) -> bool:
	if unlocked_from_start:
		return true
	
	# Check required levels
	for req_level in required_levels:
		if not world_progress.is_level_completed(req_level):
			return false
	
	# Check required secrets
	for req_level in required_secrets:
		var progress := world_progress.get_level_progress(req_level)
		if not progress.secret_exit_found:
			return false
	
	# Check custom unlock key
	if unlock_key != &"":
		if unlock_key not in world_progress.custom_data:
			return false
		if not world_progress.custom_data[unlock_key]:
			return false
	
	return true

## Check if connection should be visible
func is_visible(world_progress: XtremeWorldProgress) -> bool:
	if visible_when_locked:
		return true
	return is_unlocked(world_progress)

## Get path for drawing (including control points)
func get_path_points(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(from_pos)
	
	for control_point in path_points:
		points.append(control_point)
	
	points.append(to_pos)
	return points
