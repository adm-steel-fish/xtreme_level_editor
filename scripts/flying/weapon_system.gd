extends Node
class_name XtremeWeaponSystem
## Weapon system for flying stages.
## Handles standard shots, charge shots, and bombs.

#region Configuration
@export_group("Standard Shot")
@export var shot_scene: PackedScene
@export var shot_speed: float = 40.0
@export var shot_damage: int = 1
@export var fire_rate: float = 0.2
@export var auto_fire: bool = false

@export_group("Charge Shot")
@export var charge_shot_scene: PackedScene
@export var charge_time: float = 1.5
@export var charge_damage: int = 5
@export var charge_speed: float = 30.0
@export var lock_on_range: float = 50.0
@export var lock_on_angle: float = 30.0

@export_group("Bomb")
@export var bomb_scene: PackedScene
@export var bomb_damage: int = 10
@export var bomb_radius: float = 8.0

@export_group("Weapon Levels")
## Level 1: single shot, Level 2: double, Level 3: triple spread.
@export var level_2_spread: float = 5.0
@export var level_3_spread: float = 10.0
#endregion

#region State
var _controller: XtremeFlyingController
var _fire_timer: float = 0.0
var _charge_timer: float = 0.0
var _is_charging: bool = false
var _lock_target: Node3D
#endregion

#region Signals
signal shot_fired(position: Vector3, direction: Vector3)
signal charge_started()
signal charge_ready()
signal charge_released(target: Node3D)
signal bomb_launched(position: Vector3)
signal lock_on_acquired(target: Node3D)
signal lock_on_lost()
#endregion


func _ready() -> void:
	add_to_group("weapon_system")


## Attach to a flying controller.
func attach(controller: XtremeFlyingController) -> void:
	_controller = controller


func _process(delta: float) -> void:
	if not _controller:
		return

	_fire_timer -= delta

	_process_shooting(delta)
	_process_charge(delta)
	_process_bomb()
	_update_lock_on()


#region Standard Shot
func _process_shooting(delta: float) -> void:
	var should_fire := false
	if auto_fire:
		should_fire = Input.is_action_pressed("shoot")
	else:
		should_fire = Input.is_action_just_pressed("shoot")

	# Don't fire standard shots while charging
	if _is_charging:
		return

	if should_fire and _fire_timer <= 0.0:
		_fire_standard()
		_fire_timer = fire_rate


func _fire_standard() -> void:
	var pos := _controller.get_ship_position()
	var dir := -_controller.global_transform.basis.z  # Forward

	match _controller.weapon_level:
		1:
			_spawn_shot(pos, dir)
		2:
			var right := _controller.global_transform.basis.x
			_spawn_shot(pos + right * 0.3, dir)
			_spawn_shot(pos - right * 0.3, dir)
		3:
			var right := _controller.global_transform.basis.x
			_spawn_shot(pos, dir)
			var spread_rad := deg_to_rad(level_3_spread)
			_spawn_shot(pos + right * 0.3, dir.rotated(Vector3.UP, spread_rad))
			_spawn_shot(pos - right * 0.3, dir.rotated(Vector3.UP, -spread_rad))

	shot_fired.emit(pos, dir)


func _spawn_shot(pos: Vector3, dir: Vector3) -> void:
	if not shot_scene:
		_spawn_default_shot(pos, dir)
		return

	var shot := shot_scene.instantiate() as Node3D
	if not shot:
		return
	_controller.get_tree().current_scene.add_child(shot)
	shot.global_position = pos
	if shot.has_method("launch"):
		shot.launch(dir, shot_speed, shot_damage)


func _spawn_default_shot(pos: Vector3, dir: Vector3) -> void:
	# Create a simple projectile Area3D
	var shot := Area3D.new()
	shot.name = "PlayerShot"
	shot.monitoring = true
	shot.monitorable = false

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	shape.shape = sphere
	shot.add_child(shape)

	# Simple mesh for visibility
	var mesh_inst := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.3
	mesh_inst.mesh = sphere_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.3)
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	shot.add_child(mesh_inst)

	_controller.get_tree().current_scene.add_child(shot)
	shot.global_position = pos

	# Attach movement script behavior via process
	var velocity := dir.normalized() * shot_speed
	var damage := shot_damage
	var lifetime := 3.0

	shot.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(damage, shot)
		shot.queue_free()
	)

	# Movement via tween (simple approach)
	var tween := shot.create_tween()
	tween.tween_property(shot, "global_position", pos + velocity * lifetime, lifetime)
	tween.tween_callback(shot.queue_free)
#endregion


#region Charge Shot
func _process_charge(delta: float) -> void:
	if Input.is_action_pressed("charge_shoot"):
		if not _is_charging:
			_is_charging = true
			_charge_timer = 0.0
			charge_started.emit()

		_charge_timer += delta
		if _charge_timer >= charge_time:
			charge_ready.emit()
	elif _is_charging:
		_release_charge()
		_is_charging = false


func _release_charge() -> void:
	if _charge_timer < charge_time * 0.5:
		# Not charged enough — fire normal shot instead
		_fire_standard()
		return

	var pos := _controller.get_ship_position()
	var dir := -_controller.global_transform.basis.z

	if _lock_target and is_instance_valid(_lock_target):
		dir = (_lock_target.global_position - pos).normalized()

	charge_released.emit(_lock_target)

	if charge_shot_scene:
		var shot := charge_shot_scene.instantiate() as Node3D
		if shot:
			_controller.get_tree().current_scene.add_child(shot)
			shot.global_position = pos
			if shot.has_method("launch"):
				shot.launch(dir, charge_speed, charge_damage)
	else:
		_spawn_default_charge(pos, dir)


func _spawn_default_charge(pos: Vector3, dir: Vector3) -> void:
	var shot := Area3D.new()
	shot.name = "ChargeShot"
	shot.monitoring = true
	shot.monitorable = false

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	shape.shape = sphere
	shot.add_child(shape)

	var mesh_inst := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.4
	sphere_mesh.height = 0.8
	mesh_inst.mesh = sphere_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.8, 1.0)
	mat.emission_energy_multiplier = 3.0
	mesh_inst.material_override = mat
	shot.add_child(mesh_inst)

	_controller.get_tree().current_scene.add_child(shot)
	shot.global_position = pos

	var velocity := dir.normalized() * charge_speed
	var damage := charge_damage
	var lifetime := 4.0

	# Charge shot passes through weak enemies
	shot.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(damage, shot)
			# Don't queue_free — passes through
	)

	var tween := shot.create_tween()
	tween.tween_property(shot, "global_position", pos + velocity * lifetime, lifetime)
	tween.tween_callback(shot.queue_free)
#endregion


#region Bomb
func _process_bomb() -> void:
	if Input.is_action_just_pressed("bomb"):
		fire_bomb()


func fire_bomb() -> void:
	if not _controller or not _controller.use_bomb():
		return

	var pos := _controller.get_ship_position()
	bomb_launched.emit(pos)

	# Damage all enemies in radius
	var tree := _controller.get_tree()
	if not tree:
		return

	for enemy in tree.get_nodes_in_group("enemies"):
		if not (enemy is Node3D):
			continue
		var dist := (enemy as Node3D).global_position.distance_to(pos)
		if dist <= bomb_radius and enemy.has_method("take_damage"):
			enemy.take_damage(bomb_damage, _controller)
#endregion


#region Lock-On
func _update_lock_on() -> void:
	if not _is_charging:
		if _lock_target:
			_lock_target = null
			lock_on_lost.emit()
		return

	var best_target: Node3D = null
	var best_dot := -1.0
	var pos := _controller.get_ship_position()
	var forward := -_controller.global_transform.basis.z

	var tree := _controller.get_tree()
	if not tree:
		return

	for enemy in tree.get_nodes_in_group("enemies"):
		if not (enemy is Node3D):
			continue
		var enemy_pos := (enemy as Node3D).global_position
		var to_enemy := (enemy_pos - pos)
		var dist := to_enemy.length()
		if dist > lock_on_range:
			continue
		var dot := forward.dot(to_enemy.normalized())
		if dot < cos(deg_to_rad(lock_on_angle)):
			continue
		if dot > best_dot:
			best_dot = dot
			best_target = enemy as Node3D

	if best_target != _lock_target:
		_lock_target = best_target
		if _lock_target:
			lock_on_acquired.emit(_lock_target)
		else:
			lock_on_lost.emit()
#endregion
