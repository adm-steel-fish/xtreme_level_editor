extends Node3D
class_name XtremeFlyingController
## On-rails flying controller for shoot-em-up stages.
## Camera follows a Path3D automatically; player controls ship position
## within screen bounds. Supports shooting, charge shots, bombs, and barrel rolls.

#region Configuration
@export_group("Path")
## The on-rails camera path.
@export var camera_path: Path3D
## Speed along the rail path (units/sec).
@export var path_speed: float = 20.0

@export_group("Movement")
## Bounds the ship can move within (screen space).
@export var move_bounds: Vector2 = Vector2(10, 8)
## Ship movement speed.
@export var move_speed: float = 15.0
## Movement smoothing.
@export var move_lerp: float = 8.0

@export_group("Barrel Roll")
## Brief invincibility during barrel roll.
@export var barrel_roll_duration: float = 0.4
## Cooldown between barrel rolls.
@export var barrel_roll_cooldown: float = 0.8

@export_group("Health")
@export var starting_rings: int = 5
@export var max_rings: int = 999

@export_group("Audio")
@export var shoot_sfx: AudioStream
@export var charge_sfx: AudioStream
@export var bomb_sfx: AudioStream
@export var barrel_roll_sfx: AudioStream
@export var hit_sfx: AudioStream
#endregion

#region State
var current_rings: int = 5
var is_invincible: bool = false
var weapon_level: int = 1
var bombs: int = 3
var _path_progress: float = 0.0
var _ship_offset: Vector2 = Vector2.ZERO
var _target_offset: Vector2 = Vector2.ZERO
var _barrel_roll_timer: float = 0.0
var _barrel_roll_cd: float = 0.0
var _is_barrel_rolling: bool = false
var _path_follow: PathFollow3D
var _ship_node: Node3D
var _active: bool = false
#endregion

#region Signals
signal rings_changed(current: int)
signal bombs_changed(current: int)
signal weapon_level_changed(level: int)
signal ship_hit()
signal ship_destroyed()
signal barrel_rolled()
signal path_completed()
#endregion


func _ready() -> void:
	add_to_group("player")
	add_to_group("flying_player")
	current_rings = starting_rings

	if camera_path:
		_setup_path_follow()


func _process(delta: float) -> void:
	if not _active:
		return

	_advance_path(delta)
	_process_movement(delta)
	_process_barrel_roll(delta)
	_process_input()


## Start the flying stage.
func begin_flight() -> void:
	_active = true
	_path_progress = 0.0
	if _path_follow:
		_path_follow.progress_ratio = 0.0


## Stop flight (end of stage or death).
func end_flight() -> void:
	_active = false
#endregion


#region Path Following
func _setup_path_follow() -> void:
	_path_follow = PathFollow3D.new()
	_path_follow.name = "FlightPathFollow"
	_path_follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	_path_follow.loop = false
	camera_path.add_child(_path_follow)

	# Ship visual is a child offset from the path
	_ship_node = Node3D.new()
	_ship_node.name = "ShipPivot"
	_path_follow.add_child(_ship_node)


func _advance_path(delta: float) -> void:
	if not _path_follow or not camera_path:
		return

	_path_progress += path_speed * delta
	var curve := camera_path.curve
	if not curve or curve.get_baked_length() <= 0.0:
		return

	_path_follow.progress = _path_progress

	# Check if we've reached the end
	if _path_follow.progress_ratio >= 1.0:
		_active = false
		path_completed.emit()
#endregion


#region Movement
func _process_movement(delta: float) -> void:
	_target_offset.x = Input.get_axis("move_left", "move_right") * move_bounds.x
	_target_offset.y = Input.get_axis("move_down", "move_up") * move_bounds.y

	_ship_offset = _ship_offset.lerp(_target_offset, move_lerp * delta)

	# Clamp to bounds
	_ship_offset.x = clampf(_ship_offset.x, -move_bounds.x, move_bounds.x)
	_ship_offset.y = clampf(_ship_offset.y, -move_bounds.y, move_bounds.y)

	# Apply offset to ship
	if _ship_node:
		_ship_node.position = Vector3(_ship_offset.x, _ship_offset.y, 0)

	# Tilt ship based on movement
	if _ship_node:
		var tilt_x := -_ship_offset.y / move_bounds.y * 0.3
		var tilt_z := -_ship_offset.x / move_bounds.x * 0.5
		_ship_node.rotation = Vector3(tilt_x, 0, tilt_z)
#endregion


#region Barrel Roll
func _process_barrel_roll(delta: float) -> void:
	if _barrel_roll_cd > 0.0:
		_barrel_roll_cd -= delta

	if _is_barrel_rolling:
		_barrel_roll_timer -= delta
		if _barrel_roll_timer <= 0.0:
			_is_barrel_rolling = false
			is_invincible = false


func do_barrel_roll() -> void:
	if _barrel_roll_cd > 0.0 or _is_barrel_rolling:
		return
	_is_barrel_rolling = true
	is_invincible = true
	_barrel_roll_timer = barrel_roll_duration
	_barrel_roll_cd = barrel_roll_cooldown
	barrel_rolled.emit()

	# Spin animation
	if _ship_node:
		var tween := create_tween()
		tween.tween_property(_ship_node, "rotation:z", TAU, barrel_roll_duration)
		tween.tween_callback(func() -> void:
			if _ship_node:
				_ship_node.rotation.z = 0.0
		)
#endregion


#region Combat
func take_damage() -> void:
	if is_invincible:
		return

	ship_hit.emit()

	if current_rings > 0:
		current_rings = maxi(current_rings - 1, 0)
		rings_changed.emit(current_rings)
		# Brief invincibility
		is_invincible = true
		get_tree().create_timer(1.0).timeout.connect(func() -> void: is_invincible = false)
	else:
		_on_destroyed()


func _on_destroyed() -> void:
	_active = false
	ship_destroyed.emit()


func add_rings(amount: int) -> void:
	current_rings = mini(current_rings + amount, max_rings)
	rings_changed.emit(current_rings)


func upgrade_weapon() -> void:
	weapon_level = mini(weapon_level + 1, 3)
	weapon_level_changed.emit(weapon_level)


func add_bomb() -> void:
	bombs = mini(bombs + 1, 9)
	bombs_changed.emit(bombs)


func use_bomb() -> bool:
	if bombs <= 0:
		return false
	bombs -= 1
	bombs_changed.emit(bombs)
	return true
#endregion


#region Input
func _process_input() -> void:
	# Barrel roll
	if Input.is_action_just_pressed("dodge"):
		do_barrel_roll()
#endregion


## Get the ship's world position for targeting.
func get_ship_position() -> Vector3:
	if _ship_node:
		return _ship_node.global_position
	if _path_follow:
		return _path_follow.global_position
	return global_position
