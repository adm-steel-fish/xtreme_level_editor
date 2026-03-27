extends CharacterBody3D
class_name XtremeSnowboardPursuer
## AI-controlled boarder/skier that chases the player during snowboarding stages.
## Attempts to ram the player on contact.

enum PursuerType { BOARDER, SKIER, DRONE }
enum PursuerState { APPROACHING, PURSUING, ATTACKING, STUNNED, DEFEATED }

#region Configuration
@export_group("Identity")
@export var pursuer_type: PursuerType = PursuerType.BOARDER
@export var health: int = 1
@export var point_value: int = 150

@export_group("Movement")
## Base speed (should roughly match player).
@export var base_speed: float = 22.0
## Max speed (SKIER is faster for cut-off attacks).
@export var max_speed: float = 30.0
## How fast the pursuer steers toward the player.
@export var chase_steer_speed: float = 6.0
@export var gravity: float = 30.0

@export_group("Combat")
## Rings lost on contact.
@export var contact_ring_damage: int = 10
## Stun duration after being rammed by the player.
@export var stun_duration: float = 1.5
## Distance at which the pursuer starts attacking.
@export var attack_range: float = 5.0
## Attack lunge speed boost.
@export var attack_lunge_speed: float = 8.0

@export_group("Spawning")
## How far behind the player this pursuer spawns.
@export var spawn_offset_z: float = 30.0
## Lateral spawn offset range.
@export var spawn_offset_x_range: float = 8.0

@export_group("Drone")
## Only for DRONE type: projectile scene.
@export var projectile_scene: PackedScene
## Drone fire interval.
@export var fire_interval: float = 2.0
## Drone hover height above ground.
@export var hover_height: float = 4.0
#endregion

#region State
var current_state: PursuerState = PursuerState.APPROACHING
var _target: Node3D
var _stun_timer: float = 0.0
var _fire_timer: float = 0.0
var _current_speed: float = 22.0
#endregion

signal defeated(pursuer: XtremeSnowboardPursuer)


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("pursuers")
	_current_speed = base_speed

	# Set up contact detection
	var area := Area3D.new()
	area.name = "ContactArea"
	area.monitoring = true
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	area.add_child(shape)
	area.body_entered.connect(_on_contact)
	add_child(area)


func _physics_process(delta: float) -> void:
	if not _target:
		_find_target()
		if not _target:
			return

	match current_state:
		PursuerState.APPROACHING:
			_process_approach(delta)
		PursuerState.PURSUING:
			_process_pursue(delta)
		PursuerState.ATTACKING:
			_process_attack(delta)
		PursuerState.STUNNED:
			_process_stunned(delta)
		PursuerState.DEFEATED:
			return

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Drone hovers
	if pursuer_type == PursuerType.DRONE:
		velocity.y = ((_target.global_position.y + hover_height) - global_position.y) * 3.0

	move_and_slide()


func _process_approach(delta: float) -> void:
	var dir_to_target := (_target.global_position - global_position).normalized()
	_current_speed = lerpf(_current_speed, base_speed, 2.0 * delta)

	velocity.x = lerpf(velocity.x, dir_to_target.x * chase_steer_speed, 3.0 * delta)
	velocity.z = -_current_speed

	var dist := global_position.distance_to(_target.global_position)
	if dist < attack_range * 2.0:
		current_state = PursuerState.PURSUING


func _process_pursue(delta: float) -> void:
	var dir_to_target := (_target.global_position - global_position).normalized()
	_current_speed = lerpf(_current_speed, max_speed, 2.0 * delta)

	velocity.x = lerpf(velocity.x, dir_to_target.x * chase_steer_speed * 1.5, 4.0 * delta)
	velocity.z = lerpf(velocity.z, dir_to_target.z * _current_speed, 3.0 * delta)

	# Drone fires projectiles
	if pursuer_type == PursuerType.DRONE:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_projectile()
			_fire_timer = fire_interval

	var dist := global_position.distance_to(_target.global_position)
	if dist < attack_range:
		current_state = PursuerState.ATTACKING


func _process_attack(delta: float) -> void:
	var dir_to_target := (_target.global_position - global_position).normalized()

	# Lunge toward player
	velocity.x = dir_to_target.x * attack_lunge_speed
	velocity.z = dir_to_target.z * (_current_speed + attack_lunge_speed)

	var dist := global_position.distance_to(_target.global_position)
	if dist > attack_range * 3.0:
		current_state = PursuerState.PURSUING


func _process_stunned(delta: float) -> void:
	velocity = velocity.lerp(Vector3.ZERO, 5.0 * delta)
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		current_state = PursuerState.PURSUING


func _on_contact(body: Node3D) -> void:
	if current_state == PursuerState.STUNNED or current_state == PursuerState.DEFEATED:
		return

	if body is XtremeSnowboardController:
		var player := body as XtremeSnowboardController
		# If player is ramming, take damage
		if player.can_ram():
			take_damage(1, player)
			return
		# Otherwise, damage the player
		player.take_damage(self)


func take_damage(amount: int, source: Node3D = null) -> void:
	health -= amount
	if health <= 0:
		defeat()
		return

	# Stun
	current_state = PursuerState.STUNNED
	_stun_timer = stun_duration

	# Knockback from source
	if source:
		var knockback_dir := (global_position - source.global_position).normalized()
		velocity = knockback_dir * 10.0


func defeat() -> void:
	current_state = PursuerState.DEFEATED
	defeated.emit(self)

	# Award score to player
	if _target and _target.has_method("add_stoke"):
		_target.add_stoke(10.0)

	# Simple scale-down death animation
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)


func _fire_projectile() -> void:
	if not projectile_scene or not _target:
		return
	var proj := projectile_scene.instantiate() as Node3D
	if not proj:
		return
	get_parent().add_child(proj)
	proj.global_position = global_position
	if proj.has_method("launch"):
		var dir := (_target.global_position - global_position).normalized()
		proj.launch(dir)


func _find_target() -> void:
	var tree := get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("snowboard"):
		_target = node
		return
	for node in tree.get_nodes_in_group("player"):
		_target = node
		return
