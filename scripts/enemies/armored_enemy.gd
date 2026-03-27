extends XtremeEnemyBase
class_name XtremeArmoredEnemy
## Enemy with directional armor.  Can only be damaged when hit from the weak
## point direction (default: from above).  Patrols slowly and charges at the
## player when alerted.

@export_group("Armor")
## Local-space direction of the weak point.  Hits must come roughly opposite
## to this direction.  Default Vector3.UP means the top is vulnerable (hit by
## butt bounce or homing attack from above).
@export var weak_point_direction: Vector3 = Vector3.UP
## Cosine threshold for the dot product check.  Lower = more lenient.
## 0.3 ≈ roughly 72° acceptance cone.
@export var vulnerability_threshold: float = 0.3

@export_group("Charge Attack")
## Speed when charging toward the player.
@export var charge_speed: float = 10.0
## Maximum charge distance before giving up.
@export var charge_max_distance: float = 15.0

var _charge_origin: Vector3 = Vector3.ZERO
var _waypoints: Array[Vector3] = []
var _waypoint_index: int = 0
var _origin: Vector3 = Vector3.ZERO
var _wait_timer: float = 0.0


func _ready() -> void:
	enemy_class = EnemyClass.ARMORED
	health = 2
	point_value = 300
	telegraph_duration = 0.6
	recovery_duration = 2.0
	_origin = global_position
	if _waypoints.is_empty():
		_waypoints = [Vector3(-2, 0, 0), Vector3(2, 0, 0)]
	super._ready()
	_change_state(EnemyState.PATROL)


func _is_vulnerable_from(hit_direction: Vector3) -> bool:
	# The hit_direction points from attacker → enemy.  The weak point faces
	# outward in weak_point_direction.  A valid hit comes from the opposite
	# side, so we check the dot between the hit direction and the negative
	# of the world-space weak point.
	var world_weak := global_transform.basis * weak_point_direction.normalized()
	var dot := hit_direction.normalized().dot(-world_weak)
	return dot >= vulnerability_threshold


func _execute_patrol(delta: float) -> void:
	if _waypoints.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		return

	if _wait_timer > 0.0:
		_wait_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var target := _origin + _waypoints[_waypoint_index]
	var to_target := target - global_position
	to_target.y = 0.0

	if to_target.length() < 0.3:
		_waypoint_index = (_waypoint_index + 1) % _waypoints.size()
		_wait_timer = 0.8
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var direction := to_target.normalized()
	velocity.x = direction.x * patrol_speed
	velocity.z = direction.z * patrol_speed

	var target_angle := atan2(direction.x, direction.z)
	rotation.y = target_angle


func _execute_alert(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var dir := _get_flat_direction_to_player()
	if dir.length() > 0.001:
		rotation.y = atan2(dir.x, dir.z)


func _on_attack_start() -> void:
	_charge_origin = global_position


func _execute_attack(_delta: float) -> void:
	var dir := _get_flat_direction_to_player()
	if dir.length() < 0.001:
		_finish_attack()
		return

	velocity.x = dir.x * charge_speed
	velocity.z = dir.z * charge_speed
	rotation.y = atan2(dir.x, dir.z)

	# Stop charging if we've gone too far from where we started
	if global_position.distance_to(_charge_origin) >= charge_max_distance:
		_finish_attack()

	# Stop charging if very close to player (we already deal contact damage)
	if _get_distance_to_player() < 1.5:
		_finish_attack()
