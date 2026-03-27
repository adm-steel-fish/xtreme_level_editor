extends Area3D
class_name XtremeFlyingStageEnemy
## Base class for enemies in flying stages.
## Area3D-based since flying enemies don't need CharacterBody physics.

enum FlyingEnemyType { DRONE_SWARM, FIGHTER, BOMBER, TURRET, ELITE }
enum FormationPattern { NONE, V_SHAPE, LINE, CIRCLE, SPIRAL }

#region Configuration
@export_group("Identity")
@export var enemy_type: FlyingEnemyType = FlyingEnemyType.DRONE_SWARM
@export var health: int = 1
@export var point_value: int = 100
@export var contact_damage: int = 1

@export_group("Movement")
@export var move_speed: float = 10.0
@export var move_pattern: FormationPattern = FormationPattern.NONE
## For pattern movement: amplitude of oscillation.
@export var pattern_amplitude: float = 3.0
## For pattern movement: frequency of oscillation.
@export var pattern_frequency: float = 1.0

@export_group("Combat")
@export var projectile_scene: PackedScene
@export var fire_rate: float = 2.0
@export var projectile_speed: float = 20.0
@export var projectile_damage: int = 1

@export_group("Bomber")
## Only for BOMBER: bomb drop interval.
@export var bomb_interval: float = 3.0
@export var bomb_damage: int = 2

@export_group("Elite")
## Only for ELITE: pursuit speed.
@export var pursuit_speed: float = 15.0
## Elite tracking strength (0-1).
@export var tracking: float = 0.5
#endregion

#region State
var _target: Node3D
var _spawn_position: Vector3
var _time: float = 0.0
var _fire_timer: float = 0.0
var _bomb_timer: float = 0.0
var _alive: bool = true
#endregion

signal defeated(enemy: XtremeFlyingStageEnemy)


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("targetable")
	monitoring = true
	monitorable = true
	_spawn_position = global_position
	_fire_timer = randf() * fire_rate  # Stagger fire timing

	body_entered.connect(_on_body_entered)

	if not _has_collision_shape():
		_create_default_collision()


func _process(delta: float) -> void:
	if not _alive:
		return

	_time += delta
	_find_target()

	match enemy_type:
		FlyingEnemyType.DRONE_SWARM:
			_process_drone(delta)
		FlyingEnemyType.FIGHTER:
			_process_fighter(delta)
		FlyingEnemyType.BOMBER:
			_process_bomber(delta)
		FlyingEnemyType.TURRET:
			_process_turret(delta)
		FlyingEnemyType.ELITE:
			_process_elite(delta)


#region Movement Patterns
func _process_drone(delta: float) -> void:
	# Move forward, oscillate based on pattern
	var movement := Vector3(0, 0, move_speed * delta)
	movement += _get_pattern_offset(delta)
	global_position += movement


func _process_fighter(delta: float) -> void:
	var movement := Vector3(0, 0, move_speed * delta)
	movement += _get_pattern_offset(delta)
	global_position += movement

	# Fire at player
	_fire_timer -= delta
	if _fire_timer <= 0.0 and _target:
		_fire_at_target()
		_fire_timer = fire_rate


func _process_bomber(delta: float) -> void:
	var movement := Vector3(0, 0, move_speed * delta)
	global_position += movement

	# Drop bombs
	_bomb_timer -= delta
	if _bomb_timer <= 0.0:
		_drop_bomb()
		_bomb_timer = bomb_interval


func _process_turret(_delta: float) -> void:
	# Stationary, just fires
	_fire_timer -= _delta
	if _fire_timer <= 0.0 and _target:
		_fire_at_target()
		_fire_timer = fire_rate

	# Slowly rotate toward target
	if _target:
		var dir := (_target.global_position - global_position).normalized()
		var target_basis := Basis.looking_at(dir)
		global_transform.basis = global_transform.basis.slerp(target_basis, 2.0 * _delta)


func _process_elite(delta: float) -> void:
	if not _target:
		global_position += Vector3(0, 0, move_speed * delta)
		return

	# Pursue player
	var dir := (_target.global_position - global_position).normalized()
	var current_dir := -global_transform.basis.z
	var blend_dir := current_dir.lerp(dir, tracking * delta * 3.0).normalized()
	global_position += blend_dir * pursuit_speed * delta

	# Fire
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_at_target()
		_fire_timer = fire_rate


func _get_pattern_offset(delta: float) -> Vector3:
	match move_pattern:
		FormationPattern.V_SHAPE, FormationPattern.LINE:
			return Vector3(sin(_time * pattern_frequency) * pattern_amplitude * delta, 0, 0)
		FormationPattern.CIRCLE:
			return Vector3(
				cos(_time * pattern_frequency) * pattern_amplitude * delta,
				sin(_time * pattern_frequency) * pattern_amplitude * delta,
				0
			)
		FormationPattern.SPIRAL:
			var t := _time * pattern_frequency
			return Vector3(
				cos(t) * pattern_amplitude * delta,
				sin(t) * pattern_amplitude * delta * 0.5,
				0
			)
		_:
			return Vector3.ZERO
#endregion


#region Combat
func _fire_at_target() -> void:
	if not _target:
		return
	var dir := (_target.global_position - global_position).normalized()

	if projectile_scene:
		var proj := projectile_scene.instantiate() as Node3D
		if proj:
			get_tree().current_scene.add_child(proj)
			proj.global_position = global_position
			if proj.has_method("launch"):
				proj.launch(dir, projectile_speed, projectile_damage)
	else:
		_spawn_default_projectile(dir)


func _spawn_default_projectile(dir: Vector3) -> void:
	var proj := Area3D.new()
	proj.name = "EnemyShot"
	proj.monitoring = true
	proj.monitorable = false

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.15
	shape.shape = sphere
	proj.add_child(shape)

	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position

	var vel := dir.normalized() * projectile_speed
	var dmg := projectile_damage
	var lifetime := 5.0

	proj.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("flying_player") or body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage()
		proj.queue_free()
	)

	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position", global_position + vel * lifetime, lifetime)
	tween.tween_callback(proj.queue_free)


func _drop_bomb() -> void:
	var proj := Area3D.new()
	proj.name = "EnemyBomb"
	proj.monitoring = true
	proj.monitorable = false

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	proj.add_child(shape)

	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position

	proj.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("flying_player") or body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage()
		proj.queue_free()
	)

	# Bombs fall downward
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position", global_position + Vector3(0, -20, 0), 3.0)
	tween.tween_callback(proj.queue_free)
#endregion


#region Damage
func take_damage(amount: int, _source: Node = null) -> void:
	if not _alive:
		return
	health -= amount
	if health <= 0:
		defeat()
	else:
		# Flash effect
		_flash_hit()


func defeat() -> void:
	if not _alive:
		return
	_alive = false
	defeated.emit(self)

	# Award score if player exists
	if _target and _target.has_method("add_rings"):
		pass  # Score handled by flying stage manager

	# Death effect: scale down
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(queue_free)


func _flash_hit() -> void:
	# Brief visibility toggle for visual feedback (Area3D has no modulate)
	visible = false
	var tween := create_tween()
	tween.tween_interval(0.05)
	tween.tween_callback(func() -> void: visible = true)
	tween.tween_interval(0.05)
	tween.tween_callback(func() -> void: visible = false)
	tween.tween_interval(0.05)
	tween.tween_callback(func() -> void: visible = true)
#endregion


#region Utility
func _on_body_entered(body: Node3D) -> void:
	if not _alive:
		return
	if body.is_in_group("flying_player") or body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage()


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


func _has_collision_shape() -> bool:
	for child in get_children():
		if child is CollisionShape3D:
			return true
	return false


func _create_default_collision() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	shape.shape = sphere
	add_child(shape)
#endregion
