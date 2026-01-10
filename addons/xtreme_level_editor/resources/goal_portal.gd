@tool
class_name XtremeGoalPortal
extends Resource
## Goal Portal - End-of-level portal that returns to world map or unlocks content

## Goal types
enum GoalType {
	STANDARD,       ## Normal level completion
	SECRET,         ## Secret exit (alternate ending)
	BONUS,          ## Bonus area completion
	BOSS            ## Boss defeat / boss arena completion
}

## Unique identifier
@export var goal_id: StringName = &""

## Type of goal
@export var goal_type: GoalType = GoalType.STANDARD

## Position (grid cell)
@export var grid_position: Vector3i = Vector3i.ZERO

## World position
@export var world_position: Vector3 = Vector3.ZERO

## Display name
@export var display_name: String = "Goal"

## What happens when player reaches this goal
@export_group("Completion Effects")

## Return destination (usually "world_map")
@export var returns_to: String = "world_map"

## Level to unlock upon completion (leave empty for none)
@export var unlocks_level: String = ""

## Does this goal unlock a secret level instead of the next level?
@export var unlocks_secret_level: bool = false

## Secret level to unlock (if unlocks_secret_level is true)
@export var secret_level_id: String = ""

## Does completing this goal mark the level as "fully completed"?
@export var marks_level_complete: bool = true

## Custom completion data (for game-specific logic)
@export var custom_data: Dictionary = {}

@export_group("Visuals")

## Editor color
@export var editor_color: Color = Color.GOLD

## Scene to use for the goal visual (optional)
@export var goal_scene: PackedScene = null

## Get goal type name for UI
func get_goal_type_name() -> String:
	match goal_type:
		GoalType.STANDARD: return "Standard"
		GoalType.SECRET: return "Secret Exit"
		GoalType.BONUS: return "Bonus"
		GoalType.BOSS: return "Boss"
	return "Unknown"

## Is this a secret exit?
func is_secret_exit() -> bool:
	return goal_type == GoalType.SECRET or unlocks_secret_level

## Create a standard goal
static func create_standard(pos: Vector3i) -> XtremeGoalPortal:
	var goal := XtremeGoalPortal.new()
	goal.goal_id = StringName("goal_%d_%d_%d" % [pos.x, pos.y, pos.z])
	goal.grid_position = pos
	goal.goal_type = GoalType.STANDARD
	goal.display_name = "Goal"
	return goal

## Create a secret exit
static func create_secret(pos: Vector3i, secret_level: String = "") -> XtremeGoalPortal:
	var goal := XtremeGoalPortal.new()
	goal.goal_id = StringName("secret_%d_%d_%d" % [pos.x, pos.y, pos.z])
	goal.grid_position = pos
	goal.goal_type = GoalType.SECRET
	goal.display_name = "Secret Exit"
	goal.unlocks_secret_level = true
	goal.secret_level_id = secret_level
	goal.editor_color = Color.PURPLE
	return goal
