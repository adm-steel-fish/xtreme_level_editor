@tool
class_name XtremeLevelManifest
extends Resource
## Level Manifest - Contains all chunk sets, spawn points, and connections for a level

## Level identification
@export var level_id: StringName = &""
@export var level_name: String = "Untitled Level"
@export var level_description: String = ""

## Chunk Sets in this level
@export var chunk_sets: Array[XtremeChunkSetData] = []

## Starting chunk set (where player spawns when entering level)
@export var starting_chunk_set: StringName = &""
@export var starting_spawn_point: StringName = &"default"

## Level metadata
@export var author: String = ""
@export var version: String = "1.0"
@export var thumbnail_path: String = ""

## Get a chunk set by ID
func get_chunk_set(chunk_set_id: StringName) -> XtremeChunkSetData:
	for cs in chunk_sets:
		if cs.chunk_set_id == chunk_set_id:
			return cs
	return null

## Get all chunk set IDs
func get_chunk_set_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for cs in chunk_sets:
		ids.append(cs.chunk_set_id)
	return ids

## Add a new chunk set
func add_chunk_set(chunk_set: XtremeChunkSetData) -> void:
	if not get_chunk_set(chunk_set.chunk_set_id):
		chunk_sets.append(chunk_set)
		if chunk_sets.size() == 1:
			starting_chunk_set = chunk_set.chunk_set_id

## Remove a chunk set
func remove_chunk_set(chunk_set_id: StringName) -> void:
	for i in range(chunk_sets.size() - 1, -1, -1):
		if chunk_sets[i].chunk_set_id == chunk_set_id:
			chunk_sets.remove_at(i)
			break
	if starting_chunk_set == chunk_set_id and chunk_sets.size() > 0:
		starting_chunk_set = chunk_sets[0].chunk_set_id

## Get all connections from a chunk set
func get_connections_from(chunk_set_id: StringName) -> Array[XtremePipeConnection]:
	var cs := get_chunk_set(chunk_set_id)
	if cs:
		return cs.outgoing_connections
	return []

## Get all connections to a chunk set
func get_connections_to(chunk_set_id: StringName) -> Array[XtremePipeConnection]:
	var connections: Array[XtremePipeConnection] = []
	for cs in chunk_sets:
		for conn in cs.outgoing_connections:
			if conn.destination_chunk_set == chunk_set_id:
				connections.append(conn)
	return connections

## Validate manifest (check for broken connections, missing files, etc.)
func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if level_id == &"":
		errors.append("Level ID is empty")
	
	if chunk_sets.is_empty():
		errors.append("No chunk sets defined")
	
	if starting_chunk_set == &"" and not chunk_sets.is_empty():
		errors.append("No starting chunk set defined")
	elif starting_chunk_set != &"" and not get_chunk_set(starting_chunk_set):
		errors.append("Starting chunk set '%s' not found" % starting_chunk_set)
	
	# Check all connections point to valid chunk sets
	for cs in chunk_sets:
		for conn in cs.outgoing_connections:
			if not get_chunk_set(conn.destination_chunk_set):
				errors.append("Connection from '%s' points to missing chunk set '%s'" % [cs.chunk_set_id, conn.destination_chunk_set])
	
	return errors

## Create default manifest for a new level
static func create_default(level_id: StringName, level_name: String) -> XtremeLevelManifest:
	var manifest := XtremeLevelManifest.new()
	manifest.level_id = level_id
	manifest.level_name = level_name
	
	# Create default "main" chunk set
	var main_chunk := XtremeChunkSetData.new()
	main_chunk.chunk_set_id = &"main"
	main_chunk.display_name = "Main Path"
	manifest.add_chunk_set(main_chunk)
	
	return manifest
