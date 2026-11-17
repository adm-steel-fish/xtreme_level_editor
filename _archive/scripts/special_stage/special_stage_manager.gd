extends Node
class_name XtremeSpecialStageManager
## Manages the ring-time mechanic for special stages.
## Time is displayed as a ring counter: starts at 30, drains 1/sec,
## each ring collected adds +1, super rings add +10, enemy hit costs -5.
## When time reaches 0 the player is ejected without the crystal.

@export_group("Time")
## Starting ring-seconds.
@export var starting_time: int = 30
## Drain rate in ring-seconds per real second.
@export var drain_rate: float = 1.0
## Time lost when hit by an enemy.
@export var enemy_time_loss: int = 5

@export_group("Crystal")
## Which crystal (1-8) this stage awards.
@export var crystal_id: int = 1

var ring_time: float = 30.0
var crystal_collected: bool = false
var _active: bool = false
var _player: PlayerController

signal time_changed(current: int)
signal time_expired()
signal crystal_obtained(crystal_id: int)
signal stage_exited(success: bool)


func _ready() -> void:
	add_to_group("special_stage_manager")


func _process(delta: float) -> void:
	if not _active or crystal_collected:
		return

	ring_time -= drain_rate * delta
	var display := maxi(ceili(ring_time), 0)
	time_changed.emit(display)

	if ring_time <= 0.0:
		ring_time = 0.0
		_on_time_expired()


## Start the special stage.
func begin_stage(player: PlayerController) -> void:
	_player = player
	ring_time = float(starting_time)
	crystal_collected = false
	_active = true

	# Override ring collection to add time instead of rings
	if _player and _player.rings_changed.is_connected(_on_player_rings_changed):
		return
	if _player:
		_player.rings_changed.connect(_on_player_rings_changed)
		_player.hurt.connect(_on_player_hurt)

	time_changed.emit(starting_time)


## Called when the player collects a ring (adds time).
func add_time(seconds: int) -> void:
	ring_time += float(seconds)
	time_changed.emit(maxi(ceili(ring_time), 0))


## Called when the player touches the cosmic crystal.
func collect_crystal() -> void:
	if crystal_collected:
		return
	crystal_collected = true
	_active = false
	crystal_obtained.emit(crystal_id)

	# Record in world progress
	_record_crystal()

	stage_exited.emit(true)


func _on_time_expired() -> void:
	_active = false
	time_expired.emit()
	stage_exited.emit(false)


func _on_player_rings_changed(current: int) -> void:
	# Each ring collected in special stage adds 1 second
	# The player controller already incremented current_rings;
	# we piggyback on that to add time.
	# This is called per-ring, so +1 time per call.
	if _active:
		add_time(1)


func _on_player_hurt(_source: Node3D) -> void:
	if _active:
		ring_time -= float(enemy_time_loss)
		ring_time = maxf(ring_time, 0.0)
		time_changed.emit(maxi(ceili(ring_time), 0))


func _record_crystal() -> void:
	var tree := get_tree()
	if not tree:
		return
	var gm := tree.get_first_node_in_group("xtreme_game_manager")
	if not gm or not (gm is XtremeGameManager):
		return
	var progress: XtremeWorldProgress = (gm as XtremeGameManager).get_progress()
	if progress and progress.has_method("collect_crystal"):
		progress.collect_crystal(crystal_id)
