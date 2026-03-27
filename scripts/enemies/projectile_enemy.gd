extends XtremeEnemyBase
class_name XtremeProjectileEnemy
## Stationary or slow-moving enemy that fires projectiles at the player.

@export_group("Projectile")
## Packed scene for the projectile (must have XtremeEnemyProjectile script).
## If null, a default sphere projectile is created at runtime.
@export var projectile_scene: PackedScene
## Seconds between shots while in attack state.
@export var fire_interval: float = 2.5
## Projectile speed override (0 = use projectile default).
@export var projectile_speed: float = 12.0
## Offset from center where projectiles spawn.
@export var muzzle_offset: Vector3 = Vector3(0, 1.0, -0.8)

var _fire_timer: float = 0.0
var _attack_active: bool = false


func _ready() -> void:
	enemy_class = EnemyClass.PROJECTILE
	telegraph_duration = 0.8
	recovery_duration = fire_interval * 0.4
	super._ready()
	_change_state(EnemyState.IDLE)


func _execute_patrol(_delta: float) -> void:
	# Projectile enemies stay mostly stationary; just face a default direction
	velocity.x = 0.0
	velocity.z = 0.0


func _execute_alert(_delta: float) -> void:
	# Face the player during telegraph
	velocity.x = 0.0
	velocity.z = 0.0
	var dir := _get_flat_direction_to_player()
	if dir.length() > 0.001:
		var target_angle := atan2(dir.x, dir.z)
		rotation.y = target_angle


func _on_attack_start() -> void:
	_attack_active = true
	_fire_timer = 0.0


func _execute_attack(delta: float) -> void:
	_fire_timer += delta
	if _fire_timer >= fire_interval:
		_fire_projectile()
		_fire_timer = 0.0
		_finish_attack()


func _on_attack_end() -> void:
	_attack_active = false


func _fire_projectile() -> void:
	var spawn_pos := global_position + global_transform.basis * muzzle_offset
	var aim_dir := _get_direction_to_player()
	if aim_dir.length() < 0.001:
		aim_dir = -global_transform.basis.z

	var projectile: XtremeEnemyProjectile
	if projectile_scene:
		var instance := projectile_scene.instantiate()
		if instance is XtremeEnemyProjectile:
			projectile = instance
		else:
			instance.queue_free()

	if not projectile:
		projectile = _create_default_projectile()

	projectile.direction = aim_dir.normalized()
	if projectile_speed > 0.0:
		projectile.speed = projectile_speed
	projectile.global_position = spawn_pos

	var tree := get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(projectile)
	else:
		projectile.queue_free()


func _create_default_projectile() -> XtremeEnemyProjectile:
	var proj := XtremeEnemyProjectile.new()
	proj.name = "EnemyProjectile"

	# Visual: small sphere
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh_instance.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1)
	mat.emission_energy_multiplier = 0.5
	mesh_instance.set_surface_override_material(0, mat)
	proj.add_child(mesh_instance)

	# Collision
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.2
	shape.shape = sphere_shape
	proj.add_child(shape)

	return proj
