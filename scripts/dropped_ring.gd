extends Area3D
class_name XtremeDroppedRing

@export var value: int = 1
@export var lifetime: float = 3.0
@export var blink_start: float = 2.0
@export var rotation_speed: float = 240.0
@export var fall_gravity: float = 36.0
@export var horizontal_drag: float = 1.8

var initial_velocity: Vector3 = Vector3.ZERO

var _age: float = 0.0
var _velocity: Vector3 = Vector3.ZERO
var _collected: bool = false
var _mesh_instance: MeshInstance3D = null


func _ready() -> void:
	add_to_group("currency")
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	_ensure_visuals()
	_velocity = initial_velocity


func _process(delta: float) -> void:
	if _collected:
		return

	rotate_y(deg_to_rad(rotation_speed * delta))
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	if _mesh_instance and _age >= blink_start:
		var blink_tick := int(floor((_age - blink_start) * 20.0))
		_mesh_instance.visible = (blink_tick % 2) == 0


func _physics_process(delta: float) -> void:
	if _collected:
		return

	_velocity.y -= fall_gravity * delta
	_velocity.x = move_toward(_velocity.x, 0.0, horizontal_drag * delta)
	_velocity.z = move_toward(_velocity.z, 0.0, horizontal_drag * delta)
	global_position += _velocity * delta


func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not (body is PlayerController):
		return

	var player := body as PlayerController
	if player.has_method("add_rings"):
		player.add_rings(maxi(value, 1))
	_collected = true
	queue_free()


func _ensure_visuals() -> void:
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision:
		collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		add_child(collision)
	var shape := collision.shape as SphereShape3D
	if not shape:
		shape = SphereShape3D.new()
		collision.shape = shape
	shape.radius = 0.28

	_mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not _mesh_instance:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "MeshInstance3D"
		add_child(_mesh_instance)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.12
	torus.outer_radius = 0.28
	_mesh_instance.mesh = torus
	_mesh_instance.rotation_degrees.x = 90.0

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.85, 0.08, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.85, 0.08, 1.0)
	material.emission_energy_multiplier = 0.35
	_mesh_instance.material_override = material
