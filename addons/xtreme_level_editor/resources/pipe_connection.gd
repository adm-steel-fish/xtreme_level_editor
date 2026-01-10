@tool
class_name XtremePipeConnection
extends Resource
## Pipe Connection - Defines a transport link between chunk sets (doors, pipes, warp zones, etc.)

## Connection types
enum PipeType {
	PIPE,       ## Classic pipe (Mario-style)
	DOOR,       ## Door that opens
	HOLE,       ## Hole in ground/ceiling
	WARP_ZONE,  ## Instant teleport zone
	PORTAL,     ## Magical portal effect
	TUNNEL,     ## Tunnel entrance
	CUSTOM      ## Custom type (uses custom_type_name)
}

## Transition animation types
enum TransitionType {
	IRIS_CLOSE,     ## Circle closes to center then opens
	FADE_BLACK,     ## Quick fade to black
	WIPE_LEFT,      ## Wipe from right to left
	WIPE_RIGHT,     ## Wipe from left to right
	WIPE_UP,        ## Wipe from bottom to top
	WIPE_DOWN,      ## Wipe from top to bottom
	INSTANT,        ## No transition
	CUSTOM          ## Custom transition (handled by game code)
}

## Unique identifier for this connection
@export var connection_id: StringName = &""

## Type of transport
@export var pipe_type: PipeType = PipeType.PIPE

## Custom type name (if pipe_type is CUSTOM)
@export var custom_type_name: String = ""

## Position of this pipe entrance (grid cell)
@export var grid_position: Vector3i = Vector3i.ZERO

## World position (calculated from grid position)
@export var world_position: Vector3 = Vector3.ZERO

## Destination chunk set ID
@export var destination_chunk_set: StringName = &""

## Destination spawn point ID within the target chunk set
@export var destination_spawn_point: StringName = &"default"

## Is this a one-way or two-way connection?
@export var is_one_way: bool = false

## Does player need to press input to enter? (e.g., press down near pipe)
@export var requires_input: bool = true

## Input direction required (if requires_input is true)
## 0=any, 1=up, 2=down, 3=left, 4=right
@export var input_direction: int = 0

## Transition animation when using this pipe
@export var transition_type: TransitionType = TransitionType.IRIS_CLOSE

## Transition duration in seconds
@export var transition_duration: float = 0.5

## Display name for editor
@export var display_name: String = "Pipe"

## Editor color for visualization
@export var editor_color: Color = Color.ORANGE

## Get the direction name for UI
func get_input_direction_name() -> String:
	match input_direction:
		0: return "Any"
		1: return "Up"
		2: return "Down"
		3: return "Left"
		4: return "Right"
	return "Unknown"

## Get pipe type name for UI
func get_pipe_type_name() -> String:
	match pipe_type:
		PipeType.PIPE: return "Pipe"
		PipeType.DOOR: return "Door"
		PipeType.HOLE: return "Hole"
		PipeType.WARP_ZONE: return "Warp Zone"
		PipeType.PORTAL: return "Portal"
		PipeType.TUNNEL: return "Tunnel"
		PipeType.CUSTOM: return custom_type_name if custom_type_name else "Custom"
	return "Unknown"

## Get transition type name for UI
func get_transition_name() -> String:
	match transition_type:
		TransitionType.IRIS_CLOSE: return "Iris Close"
		TransitionType.FADE_BLACK: return "Fade to Black"
		TransitionType.WIPE_LEFT: return "Wipe Left"
		TransitionType.WIPE_RIGHT: return "Wipe Right"
		TransitionType.WIPE_UP: return "Wipe Up"
		TransitionType.WIPE_DOWN: return "Wipe Down"
		TransitionType.INSTANT: return "Instant"
		TransitionType.CUSTOM: return "Custom"
	return "Unknown"

## Create a basic pipe connection
static func create_pipe(from_pos: Vector3i, dest_chunk: StringName, dest_spawn: StringName = &"default") -> XtremePipeConnection:
	var conn := XtremePipeConnection.new()
	conn.connection_id = StringName("pipe_%d_%d_%d" % [from_pos.x, from_pos.y, from_pos.z])
	conn.grid_position = from_pos
	conn.destination_chunk_set = dest_chunk
	conn.destination_spawn_point = dest_spawn
	return conn
