extends Area3D
class_name XtremeSectionTransition
## Trigger zone that transitions the player between 3D and 2D sections.
## Uses XtremeTransitionManager for visual effects and XtremeCameraSystem
## for camera mode switching.

enum TransitionStyle { DOOR, PIPE, WARP_RING }
enum TargetMode { TO_2D, TO_3D }

@export_group("Transition")
@export var transition_style: TransitionStyle = TransitionStyle.DOOR
@export var target_mode: TargetMode = TargetMode.TO_2D

@export_group("2D Settings")
## Which axis to lock: 0 = X, 2 = Z.
@export var lock_axis: int = 2
## Position on the locked axis (player snaps here).
@export var lock_position: float = 0.0

@export_group("Destination")
## Where the player appears after the transition.
@export var destination_marker: NodePath
## Fallback offset if no marker is set.
@export var destination_offset: Vector3 = Vector3(0, 0, 3)

@export_group("Timing")
@export var transition_duration: float = 0.4

var _triggered: bool = false
var _cooldown: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


func _on_body_entered(body: Node3D) -> void:
	if _triggered or _cooldown > 0.0:
		return
	if not (body is PlayerController):
		return

	_triggered = true
	_execute_transition(body as PlayerController)


func _execute_transition(player: PlayerController) -> void:
	var transition_mgr := _find_transition_manager()
	var camera_sys := _find_camera_system()

	var destination := _get_destination()

	if transition_mgr:
		# Use visual transition — the actual mode switch happens at midpoint
		var transition_type := _get_transition_type()
		transition_mgr.transition_to(
			func() -> void: _apply_mode_change(player, camera_sys, destination),
			transition_type,
			transition_duration
		)
		# Wait for transition to fully finish before allowing re-trigger
		if transition_mgr.has_signal("transition_finished"):
			await transition_mgr.transition_finished
		_triggered = false
		_cooldown = 1.0
	else:
		# No transition manager — apply immediately
		_apply_mode_change(player, camera_sys, destination)
		_triggered = false
		_cooldown = 1.0


func _apply_mode_change(player: PlayerController, camera_sys: Node3D, destination: Vector3) -> void:
	# Reposition player
	player.global_position = destination

	match target_mode:
		TargetMode.TO_2D:
			player.enter_2d_mode(lock_axis, lock_position)
			if camera_sys and camera_sys.has_method("switch_mode"):
				camera_sys.switch_mode(2)  # SIDE_SCROLLER
		TargetMode.TO_3D:
			player.exit_2d_mode()
			if camera_sys and camera_sys.has_method("switch_mode"):
				camera_sys.switch_mode(0)  # CURVED_WORLD_FOLLOW


func _get_destination() -> Vector3:
	if destination_marker:
		var marker := get_node_or_null(destination_marker)
		if marker and marker is Node3D:
			return (marker as Node3D).global_position
	return global_position + destination_offset


func _get_transition_type() -> int:
	match transition_style:
		TransitionStyle.DOOR:
			return 1  # FADE_BLACK
		TransitionStyle.PIPE:
			return 0  # IRIS_CLOSE
		TransitionStyle.WARP_RING:
			return 0  # IRIS_CLOSE
		_:
			return 1


func _find_transition_manager() -> Node:
	var tree := get_tree()
	if not tree:
		return null
	var root := tree.current_scene
	if not root:
		return null
	for child in root.get_children():
		if child is XtremeTransitionManager:
			return child
	return null


func _find_camera_system() -> Node3D:
	var tree := get_tree()
	if not tree:
		return null
	for node in tree.get_nodes_in_group("camera_system"):
		return node as Node3D
	var root := tree.current_scene
	if not root:
		return null
	for child in root.get_children():
		if child.get_class() == "XtremeCameraSystem":
			return child as Node3D
	return null
