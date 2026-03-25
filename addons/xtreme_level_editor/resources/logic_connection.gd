@tool
class_name XtremeLogicConnection
extends Resource

## Defines a connection between a trigger source and an action target.
## When the trigger fires, the target performs the specified action.

@export var source_id: String = ""   ## Trigger ID
@export var target_id: String = ""   ## Target tile key or object ID

enum ActionType {
	ACTIVATE,    ## Enable/show the target
	DEACTIVATE,  ## Disable/hide the target
	TOGGLE,      ## Toggle active state
	SPAWN,       ## Spawn an object at the target position
	DESTROY,     ## Remove the target
	MOVE,        ## Move the target (requires parameters)
	PLAY_SOUND,  ## Play a sound effect
	PLAY_ANIM,   ## Play an animation
}

@export var action_type: ActionType = ActionType.ACTIVATE

## Delay before executing the action (seconds)
@export var delay: float = 0.0

## Optional parameters for the action (JSON-encoded)
@export var parameters: String = ""

## Display name for the editor graph
@export var display_name: String = ""
