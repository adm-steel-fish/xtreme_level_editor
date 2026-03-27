extends Area3D
class_name XtremeBossArena
## Triggers a boss encounter when the player enters.  Manages arena barriers,
## boss lifecycle, and cleanup on victory.

@export_group("Boss")
## The boss scene to spawn (must have XtremeBossBase script on root).
@export var boss_scene: PackedScene
## If set, use this existing boss node instead of spawning from scene.
@export var boss_node_path: NodePath

@export_group("Arena")
## Radius of the arena boundary.
@export var arena_radius: float = 15.0
## Node that contains invisible wall colliders (activated on fight start).
@export var barrier_node_path: NodePath

@export_group("Rewards")
## Rings dropped on boss defeat.
@export var reward_rings: int = 20

var _boss: XtremeBossBase
var _barriers: Node3D
var _activated: bool = false
var _cleared: bool = false

signal arena_activated()
signal arena_cleared()


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

	# Pre-resolve barrier node
	if barrier_node_path:
		_barriers = get_node_or_null(barrier_node_path) as Node3D
	if _barriers:
		_barriers.visible = false
		_set_barriers_enabled(false)


func _on_body_entered(body: Node3D) -> void:
	if _activated or _cleared:
		return
	if not (body is PlayerController):
		return
	_activate()


func _activate() -> void:
	_activated = true
	arena_activated.emit()

	# Enable barriers
	if _barriers:
		_barriers.visible = true
		_set_barriers_enabled(true)

	# Spawn or find boss
	if boss_node_path:
		_boss = get_node_or_null(boss_node_path) as XtremeBossBase
	if not _boss and boss_scene:
		_boss = boss_scene.instantiate() as XtremeBossBase
		if _boss:
			_boss.global_position = global_position
			var tree := get_tree()
			if tree and tree.current_scene:
				tree.current_scene.add_child(_boss)

	if _boss:
		_boss.arena_center = global_position
		_boss.arena_radius = arena_radius
		_boss.boss_defeated.connect(_on_boss_defeated)


func _on_boss_defeated(_boss_ref: XtremeBossBase) -> void:
	_cleared = true

	# Disable barriers
	if _barriers:
		_barriers.visible = false
		_set_barriers_enabled(false)

	arena_cleared.emit()


func _set_barriers_enabled(enabled: bool) -> void:
	if not _barriers:
		return
	for child in _barriers.get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled
		elif child is StaticBody3D:
			child.set_collision_layer_value(1, enabled)
