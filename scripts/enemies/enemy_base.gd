extends CharacterBody3D
class_name XtremeEnemyBase
## Base class for all enemies.  Provides an AI state machine, player detection,
## damage handling, and score/boost reward on defeat.
##
## Subclasses override _execute_patrol(), _execute_alert(), and _execute_attack()
## to define per-type behaviour.  The base class drives state transitions,
## telegraph timing, and recovery windows automatically.

#region Enums
enum EnemyState { IDLE, PATROL, ALERT, ATTACK, STUNNED, DEFEATED }
enum EnemyClass { PATROL, PROJECTILE, FLYING, ARMORED, ELITE }
#endregion

#region Exports
@export_group("Identity")
@export var enemy_class: EnemyClass = EnemyClass.PATROL
@export var enemy_name: String = "Enemy"

@export_group("Stats")
@export var health: int = 1
@export var point_value: int = 100
@export var contact_damage: int = 1

@export_group("Detection")
## Maximum distance at which the enemy can see the player.
@export var sight_range: float = 15.0
## Field of view half-angle in degrees (90 = 180° total cone).
@export var sight_angle: float = 90.0
## Seconds between first sight and entering ALERT state.
@export var detection_delay: float = 0.2

@export_group("Combat")
## Seconds the enemy telegraphs before attacking.
@export var telegraph_duration: float = 0.5
## Seconds the enemy is vulnerable after an attack.
@export var recovery_duration: float = 1.5
## Seconds stunned when hit but not killed.
@export var stun_duration: float = 0.4

@export_group("Physics")
@export var gravity: float = 30.0
@export var patrol_speed: float = 4.0
#endregion

#region Runtime State
var current_state: EnemyState = EnemyState.IDLE
var _player: PlayerController
var _detection_timer: float = 0.0
var _telegraph_timer: float = 0.0
var _recovery_timer: float = 0.0
var _stun_timer: float = 0.0
var _is_destroyed: bool = false

## Material reference for flash effects.
var _material: Material
var _is_shader_material: bool = false
#endregion

#region Signals
signal state_changed(new_state: EnemyState)
signal damaged(remaining_health: int)
signal defeated(enemy: XtremeEnemyBase)
#endregion


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("targetable")
	_setup_material()
	_setup_collision()
	_change_state(EnemyState.IDLE)


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

	# Apply gravity for grounded enemies (flying enemies override this)
	if not is_on_floor() and enemy_class != EnemyClass.FLYING:
		velocity.y -= gravity * delta

	move_and_slide()


#region State Machine
func _change_state(new_state: EnemyState) -> void:
	if new_state == current_state:
		return
	_exit_current_state()
	current_state = new_state
	_enter_state(new_state)
	state_changed.emit(new_state)


func _enter_state(new_state: EnemyState) -> void:
	match new_state:
		EnemyState.IDLE:
			velocity = Vector3.ZERO
		EnemyState.PATROL:
			pass
		EnemyState.ALERT:
			_telegraph_timer = telegraph_duration
		EnemyState.ATTACK:
			_on_attack_start()
		EnemyState.STUNNED:
			_stun_timer = stun_duration
			velocity = Vector3.ZERO
		EnemyState.DEFEATED:
			pass


func _exit_current_state() -> void:
	match current_state:
		EnemyState.ATTACK:
			_on_attack_end()
		_:
			pass
#endregion


#region State Processing
func _process_idle(delta: float) -> void:
	if _can_see_player():
		_detection_timer += delta
		if _detection_timer >= detection_delay:
			_detection_timer = 0.0
			_change_state(EnemyState.ALERT)
	else:
		_detection_timer = 0.0
		_change_state(EnemyState.PATROL)


func _process_patrol(delta: float) -> void:
	_execute_patrol(delta)
	if _can_see_player():
		_detection_timer += delta
		if _detection_timer >= detection_delay:
			_detection_timer = 0.0
			_change_state(EnemyState.ALERT)
	else:
		_detection_timer = 0.0


func _process_alert(delta: float) -> void:
	_telegraph_timer -= delta
	_execute_alert(delta)
	if _telegraph_timer <= 0.0:
		_change_state(EnemyState.ATTACK)


func _process_attack(delta: float) -> void:
	_execute_attack(delta)


func _process_stunned(delta: float) -> void:
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_change_state(EnemyState.IDLE)
#endregion


#region Subclass Overrides
## Override to define patrol movement (waypoints, paths, etc.)
func _execute_patrol(_delta: float) -> void:
	pass


## Override to define alert/telegraph behaviour (flash, wind-up anim, etc.)
func _execute_alert(_delta: float) -> void:
	pass


## Override to define the actual attack.
## Call _finish_attack() when the attack is done to enter recovery.
func _execute_attack(_delta: float) -> void:
	_finish_attack()


## Called when entering ATTACK state.
func _on_attack_start() -> void:
	pass


## Called when leaving ATTACK state.
func _on_attack_end() -> void:
	pass


## Override to restrict which directions can deal damage (armored enemies).
## Returns true if the hit from the given direction is valid.
func _is_vulnerable_from(hit_direction: Vector3) -> bool:
	return true
#endregion


#region Attack Completion
## Call from _execute_attack() when the attack action is done.
## Enters a recovery window then returns to patrol.
func _finish_attack() -> void:
	_recovery_timer = recovery_duration
	_change_state(EnemyState.IDLE)


func _return_from_recovery() -> void:
	_change_state(EnemyState.PATROL)
#endregion


#region Damage
func take_damage(amount: int, attacker: Node3D = null) -> void:
	if _is_destroyed:
		return

	# Directional vulnerability check
	if attacker:
		var hit_dir := (global_position - attacker.global_position).normalized()
		if not _is_vulnerable_from(hit_dir):
			_on_hit_blocked(attacker)
			return

	health -= amount
	damaged.emit(health)
	_flash()

	if health <= 0:
		_defeat()
	else:
		_change_state(EnemyState.STUNNED)


func _defeat() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	_change_state(EnemyState.DEFEATED)
	defeated.emit(self)
	_reward_player()

	# Death animation
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.001, 0.2)
	tween.tween_callback(queue_free)


func _on_hit_blocked(_attacker: Node3D) -> void:
	# Subclasses can play a "clang" effect here
	pass
#endregion


#region Player Detection
func _find_player_if_needed() -> void:
	if _player and is_instance_valid(_player):
		return
	var tree := get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("player"):
		if node is PlayerController:
			_player = node
			return


func _can_see_player() -> bool:
	if not _player or not is_instance_valid(_player):
		return false

	var to_player := _player.global_position - global_position
	var distance := to_player.length()
	if distance > sight_range:
		return false

	# Angle check (cone of vision)
	var forward := -global_transform.basis.z
	forward.y = 0.0
	to_player.y = 0.0
	if forward.length() < 0.001 or to_player.length() < 0.001:
		return distance <= sight_range

	var angle := rad_to_deg(forward.angle_to(to_player))
	return angle <= sight_angle


func _get_direction_to_player() -> Vector3:
	if not _player or not is_instance_valid(_player):
		return Vector3.ZERO
	return (_player.global_position - global_position).normalized()


func _get_distance_to_player() -> float:
	if not _player or not is_instance_valid(_player):
		return INF
	return global_position.distance_to(_player.global_position)


func _get_flat_direction_to_player() -> Vector3:
	if not _player or not is_instance_valid(_player):
		return Vector3.ZERO
	var dir := _player.global_position - global_position
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.001 else Vector3.ZERO
#endregion


#region Contact Damage
func _setup_collision() -> void:
	# Create an Area3D child for contact damage if one doesn't already exist
	var area := get_node_or_null("ContactArea") as Area3D
	if not area:
		area = Area3D.new()
		area.name = "ContactArea"
		area.monitoring = true
		area.monitorable = true
		# Try to clone the collision shape from the CharacterBody3D
		for child in get_children():
			if child is CollisionShape3D:
				var dup := child.duplicate()
				area.add_child(dup)
				break
		add_child(area)

	if not area.body_entered.is_connected(_on_contact_body_entered):
		area.body_entered.connect(_on_contact_body_entered)


func _on_contact_body_entered(body: Node3D) -> void:
	if _is_destroyed:
		return
	if not (body is PlayerController):
		return

	var player := body as PlayerController

	# If the player is attacking, we take damage instead
	if _is_player_attacking(player):
		take_damage(1, player)
		if player.current_state == PlayerController.State.BUTT_BOUNCE_DESCENDING:
			player.on_enemy_bounce_hit(self)
		return

	# Otherwise deal contact damage to the player
	if player.has_method("take_damage"):
		player.take_damage(self, contact_damage)


func _is_player_attacking(player: PlayerController) -> bool:
	return player.current_state in [
		PlayerController.State.HOMING_ATTACK,
		PlayerController.State.BUTT_BOUNCE_DESCENDING,
		PlayerController.State.ROLLING,
		PlayerController.State.SPIN_DASH_CHARGE,
	]
#endregion


#region Score & Boost Reward
func _reward_player() -> void:
	if not _player or not is_instance_valid(_player):
		return
	_player.add_score(point_value)
	_player.add_boost(_player.boost_enemy_gain)
#endregion


#region Visual Effects
func _setup_material() -> void:
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh:
		return

	var original_mat: Material = mesh.get_surface_override_material(0)
	if not original_mat and mesh.mesh:
		original_mat = mesh.mesh.surface_get_material(0)

	if original_mat and original_mat is ShaderMaterial:
		_material = original_mat.duplicate()
		_is_shader_material = true
		mesh.set_surface_override_material(0, _material)
	elif original_mat and original_mat is StandardMaterial3D:
		_material = original_mat.duplicate()
		_is_shader_material = false
		mesh.set_surface_override_material(0, _material)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.2, 0.2)
		_material = mat
		_is_shader_material = false
		mesh.set_surface_override_material(0, _material)


func _flash() -> void:
	if not _material:
		return

	if _is_shader_material:
		var shader_mat := _material as ShaderMaterial
		shader_mat.set_shader_parameter("damage_flash_enabled", true)
		shader_mat.set_shader_parameter("damage_flash_intensity", 0.8)
		var tween := create_tween()
		tween.tween_method(
			func(val: float) -> void: shader_mat.set_shader_parameter("damage_flash_intensity", val),
			0.8, 0.0, 0.15
		)
		tween.tween_callback(func() -> void: shader_mat.set_shader_parameter("damage_flash_enabled", false))
	else:
		var std_mat := _material as StandardMaterial3D
		if not std_mat:
			return
		var original := std_mat.albedo_color
		std_mat.albedo_color = Color.WHITE
		var tree := get_tree()
		if tree:
			await tree.create_timer(0.1).timeout
		if is_instance_valid(self) and std_mat:
			std_mat.albedo_color = original
#endregion
