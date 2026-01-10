@tool
class_name XtremeWorldMapNode
extends Resource
## World Map Node - A point on the world map (level, junction, decoration, etc.)

## Node types
enum NodeType {
	LEVEL,          ## Playable level
	JUNCTION,       ## Path junction (no level, just navigation)
	WARP,           ## Warp to another world
	BOSS,           ## Boss level
	SECRET,         ## Secret level (hidden until discovered)
	SHOP,           ## Shop/upgrade station
	DECORATION      ## Visual-only decoration
}

## Unique identifier
@export var node_id: StringName = &""

## Node type
@export var node_type: NodeType = NodeType.LEVEL

## Display name
@export var display_name: String = ""

## Position on world map (screen coordinates)
@export var position: Vector2 = Vector2.ZERO

@export_group("Level Info")

## Level ID (for LEVEL nodes)
@export var level_id: StringName = &""

## Level manifest path
@export var level_manifest_path: String = ""

@export_group("Unlock Requirements")

## Is this node visible when locked?
@export var visible_when_locked: bool = true

## Is this node always unlocked from start?
@export var unlocked_from_start: bool = false

## Levels that must be completed to unlock this node
@export var required_levels: Array[StringName] = []

## Must find secret exit in these levels to unlock
@export var required_secrets: Array[StringName] = []

@export_group("Warp Info")

## Target world for WARP nodes
@export var warp_target_world: StringName = &""

## Target node in warp destination world
@export var warp_target_node: StringName = &""

@export_group("Visuals")

## Node icon (overrides default)
@export var icon: Texture2D

## Node color
@export var color: Color = Color.WHITE

## Animation to play when selected
@export var selected_animation: String = ""

## Custom data
@export var custom_data: Dictionary = {}

## Check if this node is unlocked based on progress
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
	
	return true

## Check if this node should be visible
func is_visible(world_progress: XtremeWorldProgress) -> bool:
	if visible_when_locked:
		return true
	return is_unlocked(world_progress)

## Get the level status for display
func get_status(world_progress: XtremeWorldProgress) -> XtremeLevelProgress.LevelStatus:
	if node_type != NodeType.LEVEL:
		return XtremeLevelProgress.LevelStatus.UNLOCKED
	
	var progress := world_progress.get_level_progress(level_id)
	return progress.status

## Get completion info for display
func get_completion_info(world_progress: XtremeWorldProgress) -> Dictionary:
	if node_type != NodeType.LEVEL:
		return {}
	
	var progress := world_progress.get_level_progress(level_id)
	return {
		"status": progress.status,
		"best_rank": progress.best_rank,
		"best_time": progress.best_time,
		"best_score": progress.best_score,
		"secret_found": progress.secret_exit_found,
		"completion_count": progress.completion_count
	}
