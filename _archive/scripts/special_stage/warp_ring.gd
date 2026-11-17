extends Area3D
class_name XtremeWarpRing
## Giant warp ring hidden in main levels that teleports the player to a special stage.
## 3x normal ring size, swirling particle effect, distinct audio cue.
## On player jump-through: transitions to the special stage scene.

@export_group("Special Stage")
## Which crystal (1-8) this warp ring leads to.
@export var crystal_id: int = 1
## Scene to load for the special stage.
@export var special_stage_scene: PackedScene

@export_group("Appearance")
## Ring radius (3x normal ring = roughly 1.5 units).
@export var ring_radius: float = 1.5
## Rotation speed in radians/sec.
@export var spin_speed: float = 3.0
## Vertical bob amplitude.
@export var bob_amplitude: float = 0.3
## Vertical bob speed.
@export var bob_speed: float = 1.5
## Particle color for the swirling energy effect.
@export var particle_color: Color = Color(0.5, 0.3, 1.0, 0.8)

@export_group("Audio")
## Sound effect when nearby (proximity hum).
@export var proximity_sfx: AudioStream
## Sound when entering the warp ring.
@export var warp_sfx: AudioStream
## Distance at which the proximity hum starts.
@export var proximity_range: float = 15.0

@export_group("Requirements")
## Minimum rings to enter (0 = no requirement, classic Sonic uses 50).
@export var required_rings: int = 50
## Whether the warp ring disappears after the crystal is collected.
@export var one_time_only: bool = true

var _spawn_position: Vector3
var _time: float = 0.0
var _triggered: bool = false
var _collected: bool = false
var _proximity_player: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("warp_rings")
	monitoring = true
	monitorable = false
	_spawn_position = global_position

	body_entered.connect(_on_body_entered)

	# Check if this crystal was already collected
	if one_time_only and _is_crystal_collected():
		_collected = true
		visible = false
		set_process(false)
		monitoring = false
		return

	# Create collision shape if none exists
	if get_child_count() == 0 or not _has_collision_shape():
		_create_default_collision()

	# Set up proximity audio
	if proximity_sfx:
		_proximity_player = AudioStreamPlayer3D.new()
		_proximity_player.stream = proximity_sfx
		_proximity_player.max_distance = proximity_range
		_proximity_player.autoplay = true
		_proximity_player.bus = &"SFX"
		add_child(_proximity_player)


func _process(delta: float) -> void:
	if _collected:
		return

	_time += delta

	# Spin
	rotate_y(spin_speed * delta)

	# Bob
	global_position.y = _spawn_position.y + sin(_time * bob_speed) * bob_amplitude


func _on_body_entered(body: Node3D) -> void:
	if _triggered or _collected:
		return
	if not (body is PlayerController):
		return

	var player := body as PlayerController

	# Check ring requirement
	if required_rings > 0 and player.current_rings < required_rings:
		# Not enough rings — visual/audio feedback could go here
		return

	_triggered = true
	_execute_warp(player)


func _execute_warp(player: PlayerController) -> void:
	# Play warp sound
	if warp_sfx:
		var audio_mgr := _find_audio_manager()
		if audio_mgr and audio_mgr.has_method("play_sfx_3d"):
			audio_mgr.play_sfx_3d(warp_sfx, global_position)

	# Consume rings if required
	if required_rings > 0:
		player.current_rings -= required_rings
		player.rings_changed.emit(player.current_rings)

	# Use transition manager for visual warp effect
	var transition_mgr := _find_transition_manager()
	if transition_mgr:
		transition_mgr.transition_to(
			func() -> void: _load_special_stage(player),
			0,  # IRIS_CLOSE
			0.5
		)
		if transition_mgr.has_signal("transition_finished"):
			await transition_mgr.transition_finished
		_triggered = false
	else:
		_load_special_stage(player)
		_triggered = false


func _load_special_stage(_player: PlayerController) -> void:
	if not special_stage_scene:
		push_warning("XtremeWarpRing: No special_stage_scene assigned for crystal %d" % crystal_id)
		_triggered = false
		return

	var tree := get_tree()
	if not tree:
		return

	# Store return info in game manager
	var gm := tree.get_first_node_in_group("xtreme_game_manager")
	if gm and gm.has_method("set_custom_data"):
		gm.set_custom_data("warp_ring_return_scene", tree.current_scene.scene_file_path)

	# Change to special stage scene
	tree.change_scene_to_packed(special_stage_scene)


func _is_crystal_collected() -> bool:
	var tree := get_tree()
	if not tree:
		return false
	var gm := tree.get_first_node_in_group("xtreme_game_manager")
	if not gm or not (gm is XtremeGameManager):
		return false
	var progress: XtremeWorldProgress = (gm as XtremeGameManager).get_progress()
	if not progress:
		return false
	# Store crystals in custom_data under "crystals" key as an array of IDs
	var crystals: Array = progress.custom_data.get("crystals", [])
	return crystal_id in crystals


func _has_collision_shape() -> bool:
	for child in get_children():
		if child is CollisionShape3D or child is CollisionPolygon3D:
			return true
	return false


func _create_default_collision() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = ring_radius
	shape.shape = sphere
	add_child(shape)


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


func _find_audio_manager() -> Node:
	var tree := get_tree()
	if not tree:
		return null
	return tree.get_first_node_in_group("audio_manager")
