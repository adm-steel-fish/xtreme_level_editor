extends XtremeEnemyBase
class_name XtremePatrolEnemy
## Walks between waypoints, turns at each end.  Contact damage only.

@export_group("Patrol")
## Local-space waypoints.  The enemy walks between these in order, looping.
@export var waypoints: Array[Vector3] = [Vector3(-3, 0, 0), Vector3(3, 0, 0)]
## Seconds to pause at each waypoint before turning around.
@export var wait_time: float = 0.5
## Rotation speed in degrees per second when turning.
@export var turn_speed: float = 360.0

var _waypoint_index: int = 0
var _wait_timer: float = 0.0
var _origin: Vector3 = Vector3.ZERO


func _ready() -> void:
	enemy_class = EnemyClass.PATROL
	_origin = global_position
	super._ready()
	_change_state(EnemyState.PATROL)


func _execute_patrol(delta: float) -> void:
	if waypoints.is_empty():
		return

	# Waiting at a waypoint
	if _wait_timer > 0.0:
		_wait_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		return

	# Move toward current waypoint (world-space = origin + local waypoint)
	var target := _origin + waypoints[_waypoint_index]
	var to_target := target - global_position
	to_target.y = 0.0

	if to_target.length() < 0.3:
		# Arrived — advance to next waypoint
		_waypoint_index = (_waypoint_index + 1) % waypoints.size()
		_wait_timer = wait_time
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var direction := to_target.normalized()
	velocity.x = direction.x * patrol_speed
	velocity.z = direction.z * patrol_speed

	# Rotate to face movement
	_face_direction(direction, delta)


func _execute_alert(_delta: float) -> void:
	# Stop moving and face the player during telegraph
	velocity.x = 0.0
	velocity.z = 0.0
	var dir := _get_flat_direction_to_player()
	if dir.length() > 0.001:
		_face_direction(dir, _delta)


func _execute_attack(_delta: float) -> void:
	# Patrol enemies just lunge forward briefly then recover
	var dir := _get_flat_direction_to_player()
	if dir.length() > 0.001:
		velocity.x = dir.x * patrol_speed * 2.0
		velocity.z = dir.z * patrol_speed * 2.0
	_finish_attack()


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.001:
		return
	var target_angle := atan2(direction.x, direction.z)
	var current_angle := rotation.y
	rotation.y = rotate_toward(current_angle, target_angle, deg_to_rad(turn_speed) * delta)
