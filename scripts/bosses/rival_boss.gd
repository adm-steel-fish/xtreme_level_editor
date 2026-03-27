extends XtremeBossBase
class_name XtremeRivalBoss
## First rival boss.  Player-scale, 30x30 arena.
## Phase 1: Dash attacks with wide telegraph.
## Phase 2: Adds projectile volleys between dashes.
## Phase 3: Homing dash that tracks the player, shorter recovery.

@export_group("Dash Attack")
@export var dash_speed: float = 18.0
@export var dash_duration: float = 0.6

@export_group("Projectile Volley")
## Packed scene for boss projectile (XtremeEnemyProjectile compatible).
@export var projectile_scene: PackedScene
@export var volley_count: int = 3
@export var volley_spread: float = 25.0  # Degrees between shots

var _dash_direction: Vector3 = Vector3.ZERO
var _dash_timer: float = 0.0
var _attack_type: int = 0  # 0 = dash, 1 = volley, 2 = homing dash
var _homing_dash_active: bool = false


func _ready() -> void:
	boss_name = "Rival"
	phase_health = [8, 8, 8]
	telegraph_duration = 0.8
	recovery_duration = 1.5
	arena_radius = 15.0
	super._ready()


#region Phase Behaviour
func _execute_idle(delta: float) -> void:
	# Face the player
	var dir := _get_flat_direction_to_player()
	if dir.length() > 0.001:
		var target_angle := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 5.0 * delta)

	velocity.x = 0.0
	velocity.z = 0.0

	# Choose attack after a brief idle
	if _state_timer >= 1.2:
		_choose_attack()
		begin_attack()


func _choose_attack() -> void:
	match current_phase:
		BossPhase.PHASE_1:
			_attack_type = 0  # Always dash
		BossPhase.PHASE_2:
			# Alternate dash and volley
			_attack_type = 1 if _attack_type == 0 else 0
		BossPhase.PHASE_3:
			# Cycle: homing dash → volley → dash → repeat
			_attack_type = (_attack_type + 1) % 3


func _execute_telegraph(delta: float) -> void:
	# Face the player and prepare
	var dir := _get_flat_direction_to_player()
	if dir.length() > 0.001:
		var target_angle := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)
	_dash_direction = dir
	velocity.x = 0.0
	velocity.z = 0.0

	# Visual telegraph: pull back slightly
	if _dash_direction.length() > 0.001:
		velocity.x = -_dash_direction.x * 2.0
		velocity.z = -_dash_direction.z * 2.0

	# Camera pullback for phase 3 homing dash
	if _attack_type == 2 and _state_timer < 0.1:
		request_camera_pullback(1.5)


func _execute_attack(delta: float) -> void:
	match _attack_type:
		0:
			_execute_dash(delta)
		1:
			_execute_volley(delta)
		2:
			_execute_homing_dash(delta)


func _execute_dash(delta: float) -> void:
	_dash_timer += delta
	if _dash_timer >= dash_duration:
		_dash_timer = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		finish_attack()
		return

	velocity.x = _dash_direction.x * dash_speed
	velocity.z = _dash_direction.z * dash_speed


func _execute_volley(_delta: float) -> void:
	# Fire a spread of projectiles then finish immediately
	_fire_volley()
	finish_attack()


func _execute_homing_dash(delta: float) -> void:
	_dash_timer += delta
	var max_duration := dash_duration * 1.8

	if _dash_timer >= max_duration or _get_distance_to_player() < 1.5:
		_dash_timer = 0.0
		_homing_dash_active = false
		velocity.x = 0.0
		velocity.z = 0.0
		finish_attack()
		return

	# Continuously track the player
	var dir := _get_flat_direction_to_player()
	if dir.length() > 0.001:
		_dash_direction = _dash_direction.lerp(dir, 4.0 * delta).normalized()
	velocity.x = _dash_direction.x * dash_speed * 1.2
	velocity.z = _dash_direction.z * dash_speed * 1.2


func _execute_recovery(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	# Phase 3 has shorter recovery
	if current_phase == BossPhase.PHASE_3 and _state_timer >= recovery_duration * 0.6:
		_change_state(BossState.IDLE)


func _execute_phase_transition(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	# Boss is invincible during transition; could play animation here
#endregion


#region Projectile Volley
func _fire_volley() -> void:
	var base_dir := _get_flat_direction_to_player()
	if base_dir.length() < 0.001:
		base_dir = -global_transform.basis.z
		base_dir.y = 0.0
		base_dir = base_dir.normalized()

	var half_spread := deg_to_rad(volley_spread * (volley_count - 1) * 0.5)
	var step := deg_to_rad(volley_spread) if volley_count > 1 else 0.0

	for i in range(volley_count):
		var angle_offset := -half_spread + step * i
		var rotated := base_dir.rotated(Vector3.UP, angle_offset)
		_spawn_projectile(rotated)


func _spawn_projectile(direction: Vector3) -> void:
	var spawn_pos := global_position + Vector3.UP * 1.0 + direction * 1.2

	var proj: Node3D
	if projectile_scene:
		proj = projectile_scene.instantiate()
	else:
		proj = _create_default_projectile()

	if proj is XtremeEnemyProjectile:
		(proj as XtremeEnemyProjectile).direction = direction.normalized()
	proj.global_position = spawn_pos

	var tree := get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(proj)
	else:
		proj.queue_free()


func _create_default_projectile() -> XtremeEnemyProjectile:
	var proj := XtremeEnemyProjectile.new()
	proj.name = "BossProjectile"
	proj.speed = 14.0

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	mesh_instance.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.4)
	mat.emission_energy_multiplier = 0.6
	mesh_instance.set_surface_override_material(0, mat)
	proj.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.25
	shape.shape = sphere_shape
	proj.add_child(shape)

	return proj
#endregion
