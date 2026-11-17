extends Node3D
class_name XtremeFlyingBoss
## Boss encounter for flying stages.
## Supports ON-RAILS (boss in front of camera) and ALL-RANGE (free arena) modes.

enum BossMode { ON_RAILS, ALL_RANGE }
enum BossPhase { PHASE_1, PHASE_2, PHASE_3 }
enum BossState { INTRO, IDLE, TELEGRAPH, ATTACK, RECOVERY, PHASE_TRANSITION, DEFEATED }

#region Configuration
@export_group("Boss")
@export var boss_name: String = "Flying Boss"
@export var boss_mode: BossMode = BossMode.ON_RAILS
@export var phase_health: Array[int] = [10, 10, 10]

@export_group("Timing")
@export var intro_duration: float = 3.0
@export var telegraph_duration: float = 1.0
@export var attack_duration: float = 2.0
@export var recovery_duration: float = 2.0
@export var phase_transition_duration: float = 3.0

@export_group("Movement")
## For ON_RAILS: how far in front of the camera the boss stays.
@export var rail_distance: float = 20.0
## Screen-space movement bounds.
@export var move_bounds: Vector2 = Vector2(8, 6)
@export var move_speed: float = 5.0

@export_group("Weak Points")
## Number of hits needed per weak point.
@export var weak_point_hits: int = 3
## Weak points only vulnerable during recovery.
@export var weak_points_recovery_only: bool = true

@export_group("All-Range")
## Arena bounds for ALL_RANGE mode.
@export var arena_size: Vector3 = Vector3(40, 30, 40)

@export_group("Audio")
@export var boss_music: AudioStream
@export var hit_sfx: AudioStream
@export var phase_sfx: AudioStream
@export var defeat_sfx: AudioStream
#endregion

#region State
var current_phase: BossPhase = BossPhase.PHASE_1
var current_state: BossState = BossState.INTRO
var current_health: int = 10
var total_health: int = 30
var is_invincible: bool = true
var _target: Node3D
var _state_timer: float = 0.0
var _attack_pattern: int = 0
var _move_target: Vector3 = Vector3.ZERO
var _time: float = 0.0
#endregion

#region Signals
signal phase_changed(phase: BossPhase)
signal state_changed(state: BossState)
signal boss_damaged(health: int, max_health: int)
signal boss_defeated()
signal attack_started(pattern: int)
signal attack_ended()
#endregion


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	current_health = phase_health[0] if not phase_health.is_empty() else 10
	total_health = 0
	for hp in phase_health:
		total_health += hp
	_state_timer = intro_duration


func _process(delta: float) -> void:
	_time += delta
	_find_target()

	match current_state:
		BossState.INTRO:
			_process_intro(delta)
		BossState.IDLE:
			_process_idle(delta)
		BossState.TELEGRAPH:
			_process_telegraph(delta)
		BossState.ATTACK:
			_process_attack(delta)
		BossState.RECOVERY:
			_process_recovery(delta)
		BossState.PHASE_TRANSITION:
			_process_phase_transition(delta)
		BossState.DEFEATED:
			pass

	_process_movement(delta)


#region State Machine
func _process_intro(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		# Play boss music
		_play_boss_music()
		_change_state(BossState.IDLE)


func _process_idle(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_choose_attack()
		_change_state(BossState.TELEGRAPH)


func _process_telegraph(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_change_state(BossState.ATTACK)
		attack_started.emit(_attack_pattern)


func _process_attack(delta: float) -> void:
	_execute_attack(delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		attack_ended.emit()
		_change_state(BossState.RECOVERY)


func _process_recovery(delta: float) -> void:
	# Vulnerable during recovery
	is_invincible = false
	_state_timer -= delta
	if _state_timer <= 0.0:
		is_invincible = true
		_change_state(BossState.IDLE)


func _process_phase_transition(delta: float) -> void:
	is_invincible = true
	_state_timer -= delta
	if _state_timer <= 0.0:
		_advance_phase()
		_change_state(BossState.IDLE)


func _change_state(new_state: BossState) -> void:
	current_state = new_state
	state_changed.emit(new_state)

	match new_state:
		BossState.IDLE:
			is_invincible = true
			_state_timer = 1.5 + randf() * 1.0
		BossState.TELEGRAPH:
			is_invincible = true
			_state_timer = telegraph_duration
		BossState.ATTACK:
			is_invincible = true
			_state_timer = attack_duration
		BossState.RECOVERY:
			is_invincible = false
			_state_timer = recovery_duration
		BossState.PHASE_TRANSITION:
			is_invincible = true
			_state_timer = phase_transition_duration
		BossState.DEFEATED:
			is_invincible = true
#endregion


#region Movement
func _process_movement(delta: float) -> void:
	if current_state == BossState.DEFEATED:
		return

	match boss_mode:
		BossMode.ON_RAILS:
			_move_on_rails(delta)
		BossMode.ALL_RANGE:
			_move_all_range(delta)


func _move_on_rails(delta: float) -> void:
	# Stay in front of the camera/player, move within screen bounds
	if not _target:
		return

	# Choose new move target periodically
	if _time - floorf(_time / 2.0) * 2.0 < delta:
		_move_target = Vector3(
			randf_range(-move_bounds.x, move_bounds.x),
			randf_range(-move_bounds.y, move_bounds.y),
			0
		)

	var target_pos := _target.global_position + Vector3(0, 0, -rail_distance)
	target_pos += _move_target

	global_position = global_position.lerp(target_pos, move_speed * delta)


func _move_all_range(delta: float) -> void:
	if not _target:
		return

	# Circle around the arena, occasionally moving toward/away from player
	var orbit_pos := Vector3(
		cos(_time * 0.5) * arena_size.x * 0.4,
		sin(_time * 0.3) * arena_size.y * 0.3,
		sin(_time * 0.5) * arena_size.z * 0.4
	)

	global_position = global_position.lerp(orbit_pos, move_speed * delta)

	# Face the player
	if _target:
		look_at(_target.global_position)
#endregion


#region Combat
func _choose_attack() -> void:
	var phase_idx := int(current_phase)
	var num_patterns := 2 + phase_idx  # More patterns in later phases
	_attack_pattern = randi() % num_patterns


func _execute_attack(_delta: float) -> void:
	# Override in subclasses for specific attack behaviors.
	# Base implementation fires projectiles based on pattern.
	match _attack_pattern:
		0:
			_attack_spread_shot()
		1:
			_attack_aimed_shot()
		2:
			_attack_sweep()
		3:
			_attack_barrage()


func _attack_spread_shot() -> void:
	if not _target:
		return
	# Fire 3-5 projectiles in a spread
	var count := 3 + int(current_phase)
	var base_dir := (_target.global_position - global_position).normalized()
	for i in range(count):
		var angle := deg_to_rad(float(i - count / 2) * 15.0)
		var dir := base_dir.rotated(Vector3.UP, angle)
		_fire_projectile(dir)


func _attack_aimed_shot() -> void:
	if not _target:
		return
	var dir := (_target.global_position - global_position).normalized()
	_fire_projectile(dir)
	# Fire again slightly delayed via tween
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void:
		if _target and is_instance_valid(_target):
			var d := (_target.global_position - global_position).normalized()
			_fire_projectile(d)
	)


func _attack_sweep() -> void:
	if not _target:
		return
	# Sweep of projectiles across the screen
	var count := 5 + int(current_phase) * 2
	for i in range(count):
		var tween := create_tween()
		tween.tween_interval(float(i) * 0.15)
		var angle := deg_to_rad(float(i - count / 2) * 10.0)
		var base_dir := (_target.global_position - global_position).normalized()
		var dir := base_dir.rotated(Vector3.UP, angle)
		tween.tween_callback(func() -> void: _fire_projectile(dir))


func _attack_barrage() -> void:
	# Rapid fire burst
	var count := 8 + int(current_phase) * 3
	for i in range(count):
		var tween := create_tween()
		tween.tween_interval(float(i) * 0.1)
		tween.tween_callback(func() -> void:
			if _target and is_instance_valid(_target):
				var dir := (_target.global_position - global_position).normalized()
				var spread := Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), 0)
				_fire_projectile((dir + spread).normalized())
		)


func _fire_projectile(dir: Vector3) -> void:
	var proj := Area3D.new()
	proj.name = "BossShot"
	proj.monitoring = true
	proj.monitorable = false

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	proj.add_child(shape)

	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position

	var speed := 25.0
	var lifetime := 5.0

	proj.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("flying_player") or body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage()
		proj.queue_free()
	)

	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position", global_position + dir * speed * lifetime, lifetime)
	tween.tween_callback(proj.queue_free)
#endregion


#region Damage
func take_damage(amount: int, _source: Node = null) -> void:
	if is_invincible or current_state == BossState.DEFEATED:
		return

	current_health -= amount
	boss_damaged.emit(current_health, phase_health[int(current_phase)])

	# Update HUD
	_update_hud()

	if current_health <= 0:
		if _is_final_phase():
			_on_defeated()
		else:
			_change_state(BossState.PHASE_TRANSITION)


func _advance_phase() -> void:
	match current_phase:
		BossPhase.PHASE_1:
			current_phase = BossPhase.PHASE_2
		BossPhase.PHASE_2:
			current_phase = BossPhase.PHASE_3

	var phase_idx := int(current_phase)
	current_health = phase_health[phase_idx] if phase_idx < phase_health.size() else 10
	phase_changed.emit(current_phase)
	_update_hud()


func _is_final_phase() -> bool:
	return int(current_phase) >= phase_health.size() - 1


func _on_defeated() -> void:
	_change_state(BossState.DEFEATED)
	boss_defeated.emit()

	# Hide HUD boss bar
	var tree := get_tree()
	if tree:
		for hud in tree.get_nodes_in_group("gameplay_hud"):
			if hud.has_method("hide_boss_health"):
				hud.hide_boss_health()

	# Death animation
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)
#endregion


#region Utility
func _update_hud() -> void:
	var tree := get_tree()
	if not tree:
		return
	var phase_idx := int(current_phase)
	var max_hp := phase_health[phase_idx] if phase_idx < phase_health.size() else 10
	var ratio := float(current_health) / float(max_hp)
	for hud in tree.get_nodes_in_group("gameplay_hud"):
		if hud.has_method("show_boss_health"):
			hud.show_boss_health(boss_name, ratio)


func _play_boss_music() -> void:
	if not boss_music:
		return
	var tree := get_tree()
	if not tree:
		return
	var audio := tree.get_first_node_in_group("audio_manager")
	if audio and audio.has_method("push_music"):
		audio.push_music(boss_music)


func _find_target() -> void:
	if _target and is_instance_valid(_target):
		return
	var tree := get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("flying_player"):
		_target = node
		return
	for node in tree.get_nodes_in_group("player"):
		_target = node
		return
#endregion
