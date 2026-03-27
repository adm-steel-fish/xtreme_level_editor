extends CharacterBody3D
class_name XtremeBossBase
## Base class for all boss encounters.  Provides a 3-phase state machine with
## telegraph/attack/recovery windows, camera integration, and health tracking.
##
## Subclasses override the _phase_*() methods to define per-boss behaviour.

#region Enums
enum BossPhase { PHASE_1, PHASE_2, PHASE_3 }
enum BossState { INTRO, IDLE, TELEGRAPH, ATTACK, RECOVERY, PHASE_TRANSITION, DEFEATED }
#endregion

#region Exports
@export_group("Identity")
@export var boss_name: String = "Boss"

@export_group("Health")
## Hit points for each phase.
@export var phase_health: Array[int] = [8, 8, 8]

@export_group("Timing")
## Seconds of telegraph before each attack.
@export var telegraph_duration: float = 1.0
## Seconds of vulnerability after each attack.
@export var recovery_duration: float = 1.5
## Seconds for the intro animation.
@export var intro_duration: float = 2.0
## Seconds for the phase transition animation.
@export var phase_transition_duration: float = 1.5

@export_group("Arena")
## Radius of the boss arena (used for boundary enforcement).
@export var arena_radius: float = 15.0
## Center of the arena in world space (set by BossArena on activation).
@export var arena_center: Vector3 = Vector3.ZERO

@export_group("Physics")
@export var gravity: float = 30.0
#endregion

#region Runtime
var current_phase: BossPhase = BossPhase.PHASE_1
var current_state: BossState = BossState.INTRO
var phase_hp: int = 0
var total_hp: int = 0
var _player: PlayerController
var _camera_system: Node3D  # XtremeCameraSystem
var _hud: Node  # XtremeGameplayHUD

var _state_timer: float = 0.0
var _is_defeated: bool = false
var _is_invincible: bool = false
#endregion

#region Signals
signal phase_changed(new_phase: BossPhase)
signal boss_defeated(boss: XtremeBossBase)
signal attack_started()
signal attack_ended()
signal boss_damaged(remaining_hp: int, phase: BossPhase)
#endregion


func _ready() -> void:
	add_to_group("bosses")
	add_to_group("targetable")
	_calculate_total_hp()
	_start_intro()


func _physics_process(delta: float) -> void:
	if _is_defeated:
		return

	_find_player_if_needed()

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

	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
#endregion


#region State Machine
func _change_state(new_state: BossState) -> void:
	current_state = new_state
	_state_timer = 0.0

	match new_state:
		BossState.INTRO:
			_is_invincible = true
		BossState.IDLE:
			_is_invincible = false
		BossState.TELEGRAPH:
			_is_invincible = true
			attack_started.emit()
		BossState.ATTACK:
			_is_invincible = true
		BossState.RECOVERY:
			_is_invincible = false
			attack_ended.emit()
		BossState.PHASE_TRANSITION:
			_is_invincible = true
		BossState.DEFEATED:
			_is_invincible = true


func _process_intro(delta: float) -> void:
	_state_timer += delta
	_execute_intro(delta)
	if _state_timer >= intro_duration:
		_init_phase(BossPhase.PHASE_1)
		_change_state(BossState.IDLE)


func _process_idle(delta: float) -> void:
	_state_timer += delta
	_execute_idle(delta)
	# Subclass should call begin_attack() when ready
	if _state_timer >= 1.0:
		begin_attack()


func _process_telegraph(delta: float) -> void:
	_state_timer += delta
	_execute_telegraph(delta)
	if _state_timer >= telegraph_duration:
		_change_state(BossState.ATTACK)


func _process_attack(delta: float) -> void:
	_state_timer += delta
	_execute_attack(delta)
	# Subclass calls finish_attack() when the attack action is done


func _process_recovery(delta: float) -> void:
	_state_timer += delta
	_execute_recovery(delta)
	if _state_timer >= recovery_duration:
		_change_state(BossState.IDLE)


func _process_phase_transition(delta: float) -> void:
	_state_timer += delta
	_execute_phase_transition(delta)
	if _state_timer >= phase_transition_duration:
		_change_state(BossState.IDLE)
#endregion


#region Phase Management
func _calculate_total_hp() -> void:
	total_hp = 0
	for hp in phase_health:
		total_hp += hp


func _init_phase(phase: BossPhase) -> void:
	current_phase = phase
	var phase_index := int(phase)
	phase_hp = phase_health[phase_index] if phase_index < phase_health.size() else 8
	phase_changed.emit(phase)
	_update_hud_health()


func _advance_phase() -> void:
	match current_phase:
		BossPhase.PHASE_1:
			_init_phase(BossPhase.PHASE_2)
		BossPhase.PHASE_2:
			_init_phase(BossPhase.PHASE_3)
		BossPhase.PHASE_3:
			_defeat()
			return
	_change_state(BossState.PHASE_TRANSITION)
#endregion


#region Damage
func take_damage(amount: int = 1, _attacker: Node3D = null) -> void:
	if _is_invincible or _is_defeated:
		return
	if current_state != BossState.RECOVERY:
		return  # Can only be hurt during recovery window

	phase_hp -= amount
	boss_damaged.emit(phase_hp, current_phase)
	_flash()
	_update_hud_health()

	if phase_hp <= 0:
		_advance_phase()


func _defeat() -> void:
	_is_defeated = true
	_change_state(BossState.DEFEATED)
	boss_defeated.emit(self)

	# Restore camera
	if _camera_system and _camera_system.has_method("switch_mode"):
		_camera_system.switch_mode(0)  # CURVED_WORLD_FOLLOW

	# Hide boss HUD
	if _hud and _hud.has_method("hide_boss_health"):
		_hud.hide_boss_health()

	# Reward player
	if _player and is_instance_valid(_player):
		_player.add_score(5000)

	# Death animation
	_execute_defeat()
#endregion


#region Attack API (called by subclasses)
## Call to begin the telegraph → attack sequence.
func begin_attack() -> void:
	if current_state == BossState.IDLE:
		_change_state(BossState.TELEGRAPH)


## Call from _execute_attack() when the attack action is complete.
func finish_attack() -> void:
	if current_state == BossState.ATTACK:
		_change_state(BossState.RECOVERY)


## Request a camera pullback for big attacks.
func request_camera_pullback(duration: float = 1.0) -> void:
	if _camera_system and _camera_system.has_method("trigger_boss_pullback"):
		_camera_system.trigger_boss_pullback(duration)
#endregion


#region Subclass Overrides
func _execute_intro(_delta: float) -> void:
	pass

func _execute_idle(_delta: float) -> void:
	pass

func _execute_telegraph(_delta: float) -> void:
	pass

func _execute_attack(_delta: float) -> void:
	finish_attack()

func _execute_recovery(_delta: float) -> void:
	pass

func _execute_phase_transition(_delta: float) -> void:
	pass

func _execute_defeat() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.001, 0.5)
	tween.tween_callback(queue_free)
#endregion


#region Camera & HUD Integration
func _start_intro() -> void:
	_find_camera_system()
	_find_hud()
	_change_state(BossState.INTRO)

	# Switch to boss camera
	if _camera_system and _camera_system.has_method("set_boss_target"):
		_camera_system.set_boss_target(self)
	if _camera_system and _camera_system.has_method("switch_mode"):
		_camera_system.switch_mode(1)  # DYNAMIC_BOSS

	# Show boss health bar
	if _hud and _hud.has_method("show_boss_health"):
		_hud.show_boss_health(boss_name, 1.0)


func _update_hud_health() -> void:
	if not _hud or not _hud.has_method("update_boss_health"):
		return

	# Calculate overall health ratio across all phases
	var remaining := float(phase_hp)
	var phase_index := int(current_phase)
	for i in range(phase_index + 1, phase_health.size()):
		remaining += phase_health[i]
	var ratio := remaining / float(maxi(total_hp, 1))
	_hud.update_boss_health(ratio)


func _find_camera_system() -> void:
	var tree := get_tree()
	if not tree:
		return
	# Look for XtremeCameraSystem
	for node in tree.get_nodes_in_group("camera_system"):
		_camera_system = node
		return
	# Fallback: search the scene
	var root := tree.current_scene
	if root:
		_camera_system = _find_node_by_class(root, "XtremeCameraSystem")


func _find_hud() -> void:
	var tree := get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("gameplay_hud"):
		_hud = node
		return
	var root := tree.current_scene
	if root:
		_hud = _find_node_by_class(root, "XtremeGameplayHUD")


func _find_node_by_class(root: Node, class_string: String) -> Node:
	if root.get_class() == class_string or (root.get_script() and root.get_script().get_global_name() == class_string):
		return root
	for child in root.get_children():
		var found := _find_node_by_class(child, class_string)
		if found:
			return found
	return null
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


func _get_direction_to_player() -> Vector3:
	if not _player or not is_instance_valid(_player):
		return Vector3.ZERO
	return (_player.global_position - global_position).normalized()


func _get_flat_direction_to_player() -> Vector3:
	if not _player or not is_instance_valid(_player):
		return Vector3.ZERO
	var dir := _player.global_position - global_position
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.001 else Vector3.ZERO


func _get_distance_to_player() -> float:
	if not _player or not is_instance_valid(_player):
		return INF
	return global_position.distance_to(_player.global_position)
#endregion


#region Contact Damage & Collision
func _on_body_entered(body: Node3D) -> void:
	if _is_defeated:
		return
	if not (body is PlayerController):
		return
	var player := body as PlayerController
	if player.current_state in [PlayerController.State.HOMING_ATTACK, PlayerController.State.BUTT_BOUNCE_DESCENDING]:
		take_damage(1, player)
		if player.current_state == PlayerController.State.BUTT_BOUNCE_DESCENDING:
			player.on_enemy_bounce_hit(self)
	else:
		player.take_damage(self)
#endregion


#region Visual Effects
func _flash() -> void:
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh:
		return
	var mat := mesh.get_surface_override_material(0)
	if not mat:
		mat = mesh.mesh.surface_get_material(0) if mesh.mesh else null
	if mat is StandardMaterial3D:
		var std := mat as StandardMaterial3D
		var original := std.albedo_color
		std.albedo_color = Color.WHITE
		var tree := get_tree()
		if tree:
			await tree.create_timer(0.1).timeout
		if is_instance_valid(self) and std:
			std.albedo_color = original
#endregion
