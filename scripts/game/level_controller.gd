extends Node3D
class_name XtremeLevelController
## Drives a single playable level.
##
## Levels exported from the Xtreme Level Editor contain geometry, traversal
## nodes, a player and a camera — but nothing that runs a *session*. This node
## supplies the missing glue so a level can be played start to finish:
##
##   - Kills the player when they fall out of the world. PlayerController.kill()
##     was already wired to the game manager, but nothing ever called it, so
##     falling off the level dropped you forever.
##   - Restarts the level when the results screen is dismissed. There is no
##     world map yet, so "return to world map" loops back to the level start.
##   - Starts the level's background music, if one is assigned.
##
## Keep this node as the scene root; the exported level is instanced beneath it
## so re-exporting the level never clobbers the session wiring.

## Y height below which the player is considered to have fallen out of bounds.
@export var kill_plane_y: float = -10.0

## Seconds to wait after the results screen is dismissed before reloading.
@export var restart_delay: float = 0.25

## Optional music track for this level.
@export var level_music: AudioStream

var _game_manager: XtremeGameManager
var _player: PlayerController
var _restarting: bool = false


func _ready() -> void:
	# Deferred so every child's _ready() (game manager group registration,
	# player group registration) has already run.
	call_deferred("_bind_session")


func _bind_session() -> void:
	var tree := get_tree()
	if tree == null:
		return

	var gm := tree.get_first_node_in_group("xtreme_game_manager")
	if gm is XtremeGameManager:
		_game_manager = gm
		if not _game_manager.returned_to_world_map.is_connected(_on_returned_to_world_map):
			_game_manager.returned_to_world_map.connect(_on_returned_to_world_map)

	_player = _find_player()

	_start_music()


func _find_player() -> PlayerController:
	var tree := get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group("player"):
		if node is PlayerController:
			return node as PlayerController
	return null


func _start_music() -> void:
	if level_music == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var audio := tree.get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_music"):
		audio.play_music(level_music)


func _physics_process(_delta: float) -> void:
	_check_kill_plane()


## Nothing in the level geometry bounds the play space, so a missed jump would
## otherwise fall forever. Hand that to the normal death path so the player
## respawns at their last checkpoint.
func _check_kill_plane() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.global_position.y > kill_plane_y:
		return
	if _player.has_method("kill"):
		_player.kill(&"fell")


func _on_returned_to_world_map() -> void:
	if _restarting:
		return
	_restarting = true
	_restart_level()


func _restart_level() -> void:
	var tree := get_tree()
	if tree == null:
		return

	if restart_delay > 0.0:
		await tree.create_timer(restart_delay).timeout
		tree = get_tree()
		if tree == null:
			return

	# The game manager may have paused the tree; a reload must not inherit it.
	tree.paused = false
	tree.reload_current_scene()
