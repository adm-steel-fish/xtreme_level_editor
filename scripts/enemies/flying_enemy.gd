extends XtremeEnemyBase
class_name XtremeFlyingEnemy
## Airborne enemy that patrols in a pattern and dive-attacks when the player
## is below and in range.

@export_group("Flying")
## Amplitude of the hover bob in units.
@export var bob_amplitude: float = 1.5
## Bob speed in cycles per second.
@export var bob_speed: float = 0.8
## Horizontal patrol radius around the spawn point.
@export var patrol_radius: float = 5.0
## Orbit speed in radians per second.
@export var orbit_speed: float = 1.0
## Speed during dive attack.
@export var dive_speed: float = 20.0
## How close to the target before pulling back up.
@export var dive_end_distance: float = 1.5
## Height to return to after a dive.
@export var return_height: float = 6.0

var _origin: Vector3 = Vector3.ZERO
var _orbit_angle: float = 0.0
var _dive_target: Vector3 = Vector3.ZERO
var _returning: bool = false


func _ready() -> void:
	enemy_class = EnemyClass.FLYING
	health = 1
	telegraph_duration = 0.4
	recovery_duration = 1.0
	_origin = global_position
	super._ready()
	_change_state(EnemyState.PATROL)


func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return

	_find_player_if_needed()

	match current_state:
		EnemyState.IDLE:
			_process_idle(delta)
		EnemyState.PATROL:
			_process_patrol(delta)
		EnemyState.ALERT:
			_process_alert(delta)
		EnemyState.ATTACK:
			_process_attack(delta)
		EnemyState.STUNNED:
			_process_stunned(delta)
		EnemyState.DEFEATED:
			pass

	# Flying enemies don't use CharacterBody3D gravity or move_and_slide
	# We directly set global_position instead
	global_position += velocity * delta
	velocity = Vector3.ZERO  # Reset; each state sets it fresh


func _execute_patrol(delta: float) -> void:
	# Orbit around origin with vertical bob
	_orbit_angle += orbit_speed * delta
	var target_x := _origin.x + cos(_orbit_angle) * patrol_radius
	var target_z := _origin.z + sin(_orbit_angle) * patrol_radius
	var target_y := _origin.y + sin(Time.get_ticks_msec() * 0.001 * bob_speed * TAU) * bob_amplitude

	var target_pos := Vector3(target_x, target_y, target_z)
	var direction := (target_pos - global_position)
	velocity = direction.normalized() * patrol_speed if direction.length() > 0.1 else Vector3.ZERO

	# Face movement direction
	if direction.length() > 0.1:
		var flat_dir := Vector3(direction.x, 0, direction.z)
		if flat_dir.length() > 0.001:
			rotation.y = atan2(flat_dir.x, flat_dir.z)


func _execute_alert(_delta: float) -> void:
	# Hover in place, face the player
	var hover_y := _origin.y + sin(Time.get_ticks_msec() * 0.001 * bob_speed * TAU) * bob_amplitude * 0.5
	velocity.y = (hover_y - global_position.y) * 2.0

	var dir := _get_flat_direction_to_player()
	if dir.length() > 0.001:
		rotation.y = atan2(dir.x, dir.z)


func _on_attack_start() -> void:
	_returning = false
	if _player and is_instance_valid(_player):
		_dive_target = _player.global_position
	else:
		_dive_target = global_position + Vector3.DOWN * 5.0


func _execute_attack(_delta: float) -> void:
	if not _returning:
		# Dive toward the player's last position
		var to_target := _dive_target - global_position
		if to_target.length() < dive_end_distance:
			_returning = true
		else:
			velocity = to_target.normalized() * dive_speed
			# Face dive direction
			var flat := Vector3(to_target.x, 0, to_target.z)
			if flat.length() > 0.001:
				rotation.y = atan2(flat.x, flat.z)
	else:
		# Return to origin height
		var return_pos := Vector3(global_position.x, _origin.y + return_height, global_position.z)
		var to_return := return_pos - global_position
		if to_return.length() < 1.0:
			_finish_attack()
		else:
			velocity = to_return.normalized() * patrol_speed * 2.0
