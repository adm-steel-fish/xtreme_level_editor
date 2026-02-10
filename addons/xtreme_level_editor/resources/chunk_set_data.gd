@tool
class_name XtremeChunkSetData
extends Resource
## Chunk Set Data - Represents a distinct area within a level (connected by pipes)

## Unique identifier for this chunk set
@export var chunk_set_id: StringName = &""

## Display name shown in editor
@export var display_name: String = "Unnamed Area"

## Path to the scene file for this chunk set
@export var scene_path: String = ""

## Size of this chunk set in cells
@export var size: Vector3i = Vector3i(64, 32, 64)

## Grid-authored tile data for this chunk set
@export var level_data: XtremeLevelData

## Spawn points within this chunk set
@export var spawn_points: Array[XtremeSpawnPoint] = []

## Outgoing connections (pipes/portals to other chunk sets)
@export var outgoing_connections: Array[XtremePipeConnection] = []

## Goal portals in this chunk set
@export var goal_portals: Array[XtremeGoalPortal] = []

## Water zones in this chunk set
@export var water_zones: Array[XtremeWaterZone] = []

## Grind rails authored for this chunk set
@export var grind_rails: Array[XtremeGrindRail] = []

## Grid-authored rail cells used by the Rail Tools tab.
## Each entry: {"pos": Vector3i, "rotation": Vector3i, "rail_type": int}
@export var rail_grid_cells: Array[Dictionary] = []

## Grid-authored auto-trail/coaster cells.
## Each entry: {"pos": Vector3i, "rotation": Vector3i, "rail_type": int}
@export var coaster_grid_cells: Array[Dictionary] = []

## Grid-authored light-dash cells.
## Each entry: {"pos": Vector3i, "rotation": Vector3i, "rail_type": int}
@export var dash_grid_cells: Array[Dictionary] = []

## Scripted roller coaster paths authored for this chunk set
@export var roller_coasters: Array[XtremeRollerCoaster] = []

## Light dash ring trails authored for this chunk set
@export var light_dash_trails: Array[XtremeLightDashTrail] = []

## Editor metadata
@export var editor_position: Vector2 = Vector2.ZERO  # Position in Level Overview graph
@export var editor_color: Color = Color.WHITE

## Get a spawn point by ID
func get_spawn_point(spawn_id: StringName) -> XtremeSpawnPoint:
	for sp in spawn_points:
		if sp.spawn_id == spawn_id:
			return sp
	return null

## Get default spawn point
func get_default_spawn() -> XtremeSpawnPoint:
	for sp in spawn_points:
		if sp.is_default:
			return sp
	# Return first spawn point if no default
	if spawn_points.size() > 0:
		return spawn_points[0]
	return null

## Add a spawn point
func add_spawn_point(spawn: XtremeSpawnPoint) -> void:
	spawn_points.append(spawn)
	# If this is the first spawn point, make it default
	if spawn_points.size() == 1:
		spawn.is_default = true

## Add a pipe connection
func add_connection(connection: XtremePipeConnection) -> void:
	outgoing_connections.append(connection)

## Add a goal portal
func add_goal_portal(goal: XtremeGoalPortal) -> void:
	goal_portals.append(goal)

## Add a water zone
func add_water_zone(water: XtremeWaterZone) -> void:
	water_zones.append(water)

## Get all chunk set IDs this set connects to
func get_connected_chunk_sets() -> Array[StringName]:
	var connected: Array[StringName] = []
	for conn in outgoing_connections:
		if conn.destination_chunk_set not in connected:
			connected.append(conn.destination_chunk_set)
	return connected

## Create with default spawn point
static func create_with_defaults(id: StringName, name: String) -> XtremeChunkSetData:
	var data := XtremeChunkSetData.new()
	data.chunk_set_id = id
	data.display_name = name
	
	# Add default spawn point
	var default_spawn := XtremeSpawnPoint.new()
	default_spawn.spawn_id = &"default"
	default_spawn.position = Vector3(4, 1, 4)
	default_spawn.is_default = true
	data.add_spawn_point(default_spawn)
	
	return data
