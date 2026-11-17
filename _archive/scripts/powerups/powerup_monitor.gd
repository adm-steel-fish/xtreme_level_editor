extends StaticBody3D
class_name XtremePowerUpMonitor
## Breakable item monitor/capsule.  Destroyed by player attack to release a
## power-up pickup.

@export var contents: XtremePowerUp.PowerUpType = XtremePowerUp.PowerUpType.FLAME_SHIELD
## Duration for timed power-ups released by this monitor.
@export var powerup_duration: float = 15.0
## Optional packed scene for the power-up.  If null, a default is spawned.
@export var powerup_scene: PackedScene

var _destroyed: bool = false


func _ready() -> void:
	add_to_group("targetable")
	# Detect player attacks via an Area3D child
	var area := get_node_or_null("HitArea") as Area3D
	if not area:
		area = Area3D.new()
		area.name = "HitArea"
		area.monitoring = true
		area.monitorable = true
		for child in get_children():
			if child is CollisionShape3D:
				var dup := child.duplicate()
				area.add_child(dup)
				break
		add_child(area)

	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _destroyed:
		return
	if not (body is PlayerController):
		return

	var player := body as PlayerController

	# Only break if the player is attacking
	if player.current_state in [
		PlayerController.State.HOMING_ATTACK,
		PlayerController.State.BUTT_BOUNCE_DESCENDING,
		PlayerController.State.ROLLING,
		PlayerController.State.SPIN_DASH_CHARGE,
	]:
		_break(player)


func _break(player: PlayerController) -> void:
	_destroyed = true

	# Bounce the player if they were homing or bouncing
	if player.current_state == PlayerController.State.BUTT_BOUNCE_DESCENDING:
		player.on_enemy_bounce_hit(self)

	_spawn_powerup()

	# Destroy animation
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.001, 0.15)
	tween.tween_callback(queue_free)


func _spawn_powerup() -> void:
	var pickup: XtremePowerUp
	if powerup_scene:
		var instance := powerup_scene.instantiate()
		if instance is XtremePowerUp:
			pickup = instance
		else:
			instance.queue_free()

	if not pickup:
		pickup = _create_default_pickup()

	pickup.powerup_type = contents
	pickup.duration = powerup_duration
	pickup.global_position = global_position + Vector3.UP * 1.5

	var tree := get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(pickup)
	else:
		pickup.queue_free()


func _create_default_pickup() -> XtremePowerUp:
	var pickup := XtremePowerUp.new()
	pickup.name = "PowerUp"

	# Visual: colored sphere
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	mesh_instance.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _get_color_for_type(contents)
	mat.emission_enabled = true
	mat.emission = _get_color_for_type(contents)
	mat.emission_energy_multiplier = 0.4
	mesh_instance.set_surface_override_material(0, mat)
	pickup.add_child(mesh_instance)

	# Collision
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.6
	shape.shape = sphere_shape
	pickup.add_child(shape)

	return pickup


func _get_color_for_type(type: XtremePowerUp.PowerUpType) -> Color:
	match type:
		XtremePowerUp.PowerUpType.FLAME_SHIELD:
			return Color(1.0, 0.3, 0.1)
		XtremePowerUp.PowerUpType.ELECTRIC_SHIELD:
			return Color(0.3, 0.6, 1.0)
		XtremePowerUp.PowerUpType.AQUA_SHIELD:
			return Color(0.2, 0.8, 0.6)
		XtremePowerUp.PowerUpType.SPEED_SHOES:
			return Color(1.0, 0.8, 0.0)
		XtremePowerUp.PowerUpType.INVINCIBILITY:
			return Color(1.0, 1.0, 1.0)
		_:
			return Color.WHITE
