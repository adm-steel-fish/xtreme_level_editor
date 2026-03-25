@tool
class_name XtremeTriggerData
extends Resource

## Data for a single trigger in the level logic system.
## Triggers fire when their condition is met, activating connected actions.

enum TriggerType {
	AREA,       ## Player enters a 3D area
	TOUCH,      ## Player touches a specific tile/object
	TIMER,      ## Fires after a delay
	CONDITION,  ## Fires when a GDScript expression evaluates to true
}

@export var trigger_id: String = ""
@export var trigger_type: TriggerType = TriggerType.AREA
@export var display_name: String = ""

## World position of the trigger (in grid coordinates)
@export var position: Vector3i = Vector3i.ZERO

## Radius for AREA triggers (in cells)
@export var radius: float = 3.0

## Duration for TIMER triggers (seconds)
@export var timer_duration: float = 0.0

## Expression for CONDITION triggers
@export var condition_expression: String = ""

## IDs of connected actions
@export var connected_actions: Array[String] = []

## Whether this trigger can fire multiple times
@export var repeatable: bool = false

## Color for editor visualization
@export var editor_color: Color = Color(1.0, 0.5, 0.0, 0.5)


static func create_area_trigger(id: String, pos: Vector3i, r: float = 3.0) -> XtremeTriggerData:
	var t := XtremeTriggerData.new()
	t.trigger_id = id
	t.trigger_type = TriggerType.AREA
	t.position = pos
	t.radius = r
	t.display_name = "Area Trigger"
	t.editor_color = Color(1.0, 0.5, 0.0, 0.5)
	return t


static func create_timer_trigger(id: String, pos: Vector3i, duration: float = 5.0) -> XtremeTriggerData:
	var t := XtremeTriggerData.new()
	t.trigger_id = id
	t.trigger_type = TriggerType.TIMER
	t.position = pos
	t.timer_duration = duration
	t.display_name = "Timer Trigger"
	t.editor_color = Color(0.0, 0.5, 1.0, 0.5)
	return t
